package com.bcnai.cognitodraw

import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeNotNull
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs

class MobileComponentsTest {
    @Test
    fun allReferencePixelsAndClassifierHeadsMatchPython() {
        val location = System.getProperty("mobile.references")
        // Оригинальные рисунки подключаются только локально и не входят в исходники приложения.
        assumeNotNull(location)
        val references = File(requireNotNull(location))
        val bundle = File(requireNotNull(System.getProperty("mobile.bundle")))
        val preprocessor = PillowPreprocessor(JSONObject(File(bundle, "manifest.json").readText()))
        val heads = JSONObject(File(bundle, "heads.json").readText())
        val rows = JSONObject(File(references, "report.json").readText()).getJSONArray("results")
        for (index in 0 until rows.length()) {
            val row = rows.getJSONObject(index)
            val id = row.getInt("index")
            val task = row.getString("task")
            assertArrayEquals("Reference $id pixels", File(references, "$id.preprocessed.rgb").readBytes(),
                preprocessor.preprocess(File(references, "$id.rgb").readBytes(), task))
            val buffer = ByteBuffer.wrap(File(references, "$id.embedding.f32").readBytes()).order(ByteOrder.LITTLE_ENDIAN).asFloatBuffer()
            val features = FloatArray(buffer.remaining())
            buffer.get(features)
            val metadata = row.getJSONObject("metadata")
            val sex = metadata.getString("sex")
            val result = ClassifierHead(heads.getJSONObject(task)).classify(features, doubleArrayOf(
                metadata.getDouble("age"), metadata.getDouble("timeToComplete"), metadata.getDouble("repeatTaps"),
                if (sex == "female") 1.0 else 0.0, if (sex == "male") 1.0 else 0.0,
            ))
            assertEquals("Reference $id label", row.getInt("label"), result.label)
            val expected = row.getDouble("python_score")
            // Стандартный допуск torch.testing.assert_close для float32.
            assertTrue("Reference $id score", abs(result.score - expected) <= 1e-5 + 1.3e-6 * abs(expected))
        }
    }

    @Test(expected = IllegalArgumentException::class)
    fun unsupportedFrameDimensionsAreRejected() {
        val bundle = File(requireNotNull(System.getProperty("mobile.bundle")))
        val preprocessor = PillowPreprocessor(JSONObject(File(bundle, "manifest.json").readText()))
        preprocessor.preprocess(byteArrayOf(), "clock")
    }

    @Test
    fun decisionBoundaryAndExtremeScoresMatchLogisticRegression() {
        val head = ClassifierHead(JSONObject("""{"weights":[1.0],"intercept":0.0,"classes":[0,1]}"""))
        val boundary = head.classify(floatArrayOf(0f), doubleArrayOf())
        assertEquals(0, boundary.label)
        assertEquals(0.5, boundary.score, 0.0)
        assertEquals(1.0, head.classify(floatArrayOf(Float.MAX_VALUE), doubleArrayOf()).score, 0.0)
        assertEquals(0.0, head.classify(floatArrayOf(-Float.MAX_VALUE), doubleArrayOf()).score, 0.0)
    }
}
