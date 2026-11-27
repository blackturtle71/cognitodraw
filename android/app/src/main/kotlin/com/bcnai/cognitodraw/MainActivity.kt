package com.bcnai.cognitodraw

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val inference by lazy { MobileInference(applicationContext) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cognitodraw/inference").setMethodCallHandler { call, result ->
            if (call.method !in listOf("info", "assess")) {
                result.notImplemented()
            } else {
                worker.execute {
                    try {
                        val value = if (call.method == "info") inference.info()
                            else inference.assess(call.arguments as? Map<*, *> ?: error("Нет входных данных"))
                        main.post { result.success(value) }
                    } catch (error: Exception) {
                        main.post { result.error("assessment_failed", error.message ?: "Не удалось оценить рисунок", null) }
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        worker.execute { inference.close() }
        worker.shutdown()
        super.onDestroy()
    }
}
