package com.bcnai.cognitodraw

import android.os.Debug
import android.os.SystemClock
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.math.abs

@RunWith(AndroidJUnit4::class)
class MobileParityTest {
    @Test
    fun allReferenceDrawingsMatchPython() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val assets = instrumentation.context.assets
        val flutterAssets = "flutter_assets/assets/models/dinov2/"
        val manifest = JSONObject(context.assets.open(flutterAssets + "manifest.json").bufferedReader().use { it.readText() })
        val preprocessor = PillowPreprocessor(manifest)
        val report = JSONObject(assets.open("report.json").bufferedReader().use { it.readText() })
        val references = report.getJSONArray("results")
        val durations = mutableListOf<Double>()
        var largestError = 0.0
        var maximumObservedPssKb = 0L
        MobileInference(context).use { model ->
            for (index in 0 until references.length()) {
                val reference = references.getJSONObject(index)
                val id = reference.getInt("index")
                val task = reference.getString("task")
                val rgb = assets.open("$id.rgb").use { it.readBytes() }
                val expectedPixels = assets.open("$id.preprocessed.rgb").use { it.readBytes() }
                assertArrayEquals("Reference $id pixels", expectedPixels, preprocessor.preprocess(rgb, task))
                val rgba = ByteArray(preprocessor.width * preprocessor.height * 4)
                for (pixel in 0 until preprocessor.width * preprocessor.height) {
                    for (channel in 0 until 3) rgba[pixel * 4 + channel] = rgb[pixel * 3 + channel]
                    rgba[pixel * 4 + 3] = 255.toByte()
                }
                val metadata = reference.getJSONObject("metadata")
                val started = SystemClock.elapsedRealtimeNanos()
                val actual = model.assess(mapOf(
                    "frame" to rgba, "width" to preprocessor.width, "height" to preprocessor.height,
                    "task" to task, "metadata" to mapOf(
                        "age" to metadata.getInt("age"), "sex" to metadata.getString("sex"),
                        "timeToComplete" to metadata.getInt("timeToComplete"),
                        "repeatTaps" to metadata.getInt("repeatTaps"),
                    ),
                ))
                durations.add((SystemClock.elapsedRealtimeNanos() - started) / 1_000_000.0)
                assertEquals("Reference $id label", reference.getInt("label"), actual["label"])
                val expected = reference.getDouble("python_score")
                val error = abs((actual["score"] as Double) - expected)
                largestError = maxOf(largestError, error)
                // Допуск соответствует torch.testing.assert_close для float32 в закреплённом PyTorch.
                assertTrue("Reference $id score error $error", error <= 1e-5 + 1.3e-6 * abs(expected))
                maximumObservedPssKb = maxOf(maximumObservedPssKb, Debug.getPss())
            }
        }
        Log.i("MobileParity", JSONObject(mapOf(
            "references" to references.length(), "maximumScoreError" to largestError,
            "firstAssessmentMs" to durations.first(),
            "meanWarmAssessmentMs" to durations.drop(1).average(),
            "maximumObservedPssKb" to maximumObservedPssKb,
        )).toString())
    }
}
