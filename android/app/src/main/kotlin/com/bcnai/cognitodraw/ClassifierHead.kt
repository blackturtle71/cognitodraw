package com.bcnai.cognitodraw

import org.json.JSONObject
import kotlin.math.exp

data class Classification(val label: Int, val score: Double)

class ClassifierHead(parameters: JSONObject) {
    private val weights = parameters.getJSONArray("weights").let { values ->
        DoubleArray(values.length()) { values.getDouble(it) }
    }
    private val intercept = parameters.getDouble("intercept")

    init {
        val classes = parameters.getJSONArray("classes")
        require(classes.length() == 2 && classes.getInt(0) == 0 && classes.getInt(1) == 1) { "Неверные классы модели" }
        require(weights.all { it.isFinite() } && intercept.isFinite()) { "Некорректные параметры модели" }
    }

    fun classify(features: FloatArray, metadata: DoubleArray): Classification {
        require(weights.size == features.size + metadata.size) { "Неверная размерность классификатора" }
        var logit = intercept
        for (index in features.indices) logit += features[index].toDouble() * weights[index]
        for (index in metadata.indices) logit += metadata[index] * weights[features.size + index]
        require(logit.isFinite()) { "Модель вернула некорректную оценку" }
        val score = if (logit >= 0) 1.0 / (1.0 + exp(-logit)) else exp(logit) / (1.0 + exp(logit))
        return Classification(if (logit > 0) 1 else 0, score)
    }
}
