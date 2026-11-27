package com.bcnai.cognitodraw

import android.content.Context
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import io.flutter.FlutterInjector
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.FloatBuffer
import java.security.MessageDigest

class MobileInference(private val context: Context) : AutoCloseable {
    private val assetRoot = "assets/models/dinov2/"
    private fun asset(name: String) = context.assets.open(
        FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetRoot + name)
    )
    private val manifestBytes by lazy { asset("manifest.json").use { it.readBytes() } }
    private val manifest by lazy { JSONObject(String(manifestBytes, Charsets.UTF_8)) }
    private val version by lazy { hash(manifestBytes) }
    private val preprocessor by lazy { PillowPreprocessor(manifest) }
    private val heads by lazy {
        val bytes = asset("heads.json").use { it.readBytes() }
        require(hash(bytes) == manifest.getJSONObject("sha256").getString("heads.json")) {
            "Повреждены параметры классификаторов"
        }
        JSONObject(String(bytes, Charsets.UTF_8))
    }
    private var session: OrtSession? = null
    private val environment by lazy { OrtEnvironment.getEnvironment().apply { setTelemetry(false) } }

    fun info(): Map<String, Any> {
        require(manifest.getInt("schema_version") == 1 && manifest.getString("experiment") == "dinov2-tuned") {
            "Неподдерживаемый комплект моделей"
        }
        return mapOf("modelVersion" to version, "preprocessingVersion" to manifest.getString("preprocessing_version"))
    }

    private fun encoder(): OrtSession {
        session?.let { return it }
        info()
        val directory = File(context.filesDir, "models/$version").apply { mkdirs() }
        val checkpoint = File(directory, "encoder.onnx")
        val expected = manifest.getJSONObject("sha256").getString("encoder.onnx")
        if (!checkpoint.isFile || hashFile(checkpoint) != expected) {
            val temporary = File(directory, "encoder.tmp")
            asset("encoder.onnx").use { input -> temporary.outputStream().use { input.copyTo(it) } }
            require(hashFile(temporary) == expected) { "Повреждён файл модели" }
            check(temporary.renameTo(checkpoint)) { "Не удалось подготовить модель" }
        }
        OrtSession.SessionOptions().use { options ->
            session = environment.createSession(checkpoint.absolutePath, options)
        }
        return session!!
    }

    fun assess(arguments: Map<*, *>): Map<String, Any> {
        info()
        val task = arguments["task"] as? String ?: error("Не указано задание")
        require(task == "clock" || task == "cube") { "Неизвестное задание" }
        require(arguments["width"] == preprocessor.width && arguments["height"] == preprocessor.height) {
            "Этот размер или формат рисунка не поддерживается; нужна каноническая запись"
        }
        val metadata = arguments["metadata"] as? Map<*, *> ?: error("Нет метаданных")
        val age = integer(metadata["age"], "возраст")
        val elapsed = integer(metadata["timeToComplete"], "время выполнения")
        val repeats = integer(metadata["repeatTaps"], "число повторов")
        val sex = metadata["sex"] as? String
        require(age > 0 && elapsed >= 0 && repeats >= 0 && sex in listOf("female", "male")) { "Некорректные метаданные" }
        val values = doubleArrayOf(age, elapsed, repeats, if (sex == "female") 1.0 else 0.0, if (sex == "male") 1.0 else 0.0)
        val rgba = arguments["frame"] as? ByteArray ?: error("Нет изображения")
        val rgb = preprocessor.composite(rgba)
        val pixels = preprocessor.preprocess(rgb, task)
        val size = manifest.getJSONObject("preprocessing").getInt("input_size")
        val mean = manifest.getJSONObject("encoder").getJSONArray("mean")
        val standardDeviation = manifest.getJSONObject("encoder").getJSONArray("std")
        val normalized = FloatArray(3 * size * size)
        for (channel in 0 until 3) {
            for (pixel in 0 until size * size) {
                val value = (pixels[pixel * 3 + channel].toInt() and 255) / 255f
                normalized[channel * size * size + pixel] = (value - mean.getDouble(channel).toFloat()) / standardDeviation.getDouble(channel).toFloat()
            }
        }
        val runtime = encoder()
        val features = OnnxTensor.createTensor(
            environment, FloatBuffer.wrap(normalized), longArrayOf(1, 3, size.toLong(), size.toLong())
        ).use { tensor ->
            runtime.run(mapOf("image" to tensor)).use { result ->
                @Suppress("UNCHECKED_CAST")
                (result[0].value as Array<FloatArray>)[0].copyOf()
            }
        }
        val classification = ClassifierHead(heads.getJSONObject(task)).classify(features, values)
        val fingerprint = MessageDigest.getInstance("SHA-256")
        fingerprint.update(rgb)
        fingerprint.update(task.toByteArray(Charsets.UTF_8))
        fingerprint.update(JSONArray(values.toList()).toString().toByteArray(Charsets.UTF_8))
        fingerprint.update(manifest.getString("preprocessing_version").toByteArray(Charsets.UTF_8))
        return info() + mapOf(
            "label" to classification.label,
            "score" to classification.score, "inputFingerprint" to hex(fingerprint.digest()),
        )
    }

    private fun integer(value: Any?, field: String): Double {
        require(value is Number && value.toDouble().isFinite() && value.toDouble() == value.toLong().toDouble()) {
            "Некорректное поле: $field"
        }
        return value.toDouble()
    }

    override fun close() { session?.close(); session = null }

    private fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it) }
    private fun hash(bytes: ByteArray) = hex(MessageDigest.getInstance("SHA-256").digest(bytes))
    private fun hashFile(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return hex(digest.digest())
    }
}
