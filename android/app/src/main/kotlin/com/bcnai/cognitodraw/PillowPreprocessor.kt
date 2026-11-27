package com.bcnai.cognitodraw

import org.json.JSONObject

class PillowPreprocessor(private val specification: JSONObject) {
    private val preprocessing = specification.getJSONObject("preprocessing")
    val width = preprocessing.getJSONArray("frame_size").getInt(0)
    val height = preprocessing.getJSONArray("frame_size").getInt(1)
    private val background = preprocessing.getJSONArray("background")

    fun composite(rgba: ByteArray): ByteArray {
        require(rgba.size == width * height * 4) { "Ожидается кадр 343×548 RGBA" }
        val rgb = ByteArray(width * height * 3)
        for (pixel in 0 until width * height) {
            val alpha = rgba[pixel * 4 + 3].toInt() and 255
            for (channel in 0 until 3) {
                val source = rgba[pixel * 4 + channel].toInt() and 255
                val value = (source * alpha + background.getInt(channel) * (255 - alpha) + 127) / 255
                rgb[pixel * 3 + channel] = value.toByte()
            }
        }
        return rgb
    }

    fun preprocess(rgb: ByteArray, task: String): ByteArray {
        require(rgb.size == width * height * 3) { "Некорректный размер RGB-кадра" }
        val boxes = preprocessing.getJSONObject("canvas_boxes")
        require(boxes.has(task)) { "Неизвестное задание" }
        val pixels = rgb.copyOf()
        val masks = preprocessing.getJSONArray("button_boxes")
        for (index in 0 until masks.length()) {
            val box = masks.getJSONArray(index)
            for (y in box.getInt(1) until box.getInt(3)) {
                for (x in box.getInt(0) until box.getInt(2)) {
                    for (channel in 0 until 3) pixels[(y * width + x) * 3 + channel] = background.getInt(channel).toByte()
                }
            }
        }
        val box = boxes.getJSONArray(task)
        val canvasWidth = box.getInt(2) - box.getInt(0)
        val canvasHeight = box.getInt(3) - box.getInt(1)
        val side = maxOf(canvasWidth, canvasHeight)
        val square = ByteArray(side * side * 3) { background.getInt(it % 3).toByte() }
        val offsetX = (side - canvasWidth) / 2
        val offsetY = (side - canvasHeight) / 2
        for (y in 0 until canvasHeight) {
            for (x in 0 until canvasWidth) {
                val from = ((y + box.getInt(1)) * width + x + box.getInt(0)) * 3
                val to = ((y + offsetY) * side + x + offsetX) * 3
                for (channel in 0 until 3) square[to + channel] = pixels[from + channel]
            }
        }
        val table = specification.getJSONObject("resampling").getJSONObject(task)
        require(side == table.getInt("source_size")) { "Размер таблицы интерполяции не совпадает" }
        val target = preprocessing.getInt("input_size")
        val horizontal = resize(square, side, side, target, table, horizontal = true)
        return resize(horizontal, target, side, target, table, horizontal = false)
    }

    private fun resize(
        input: ByteArray, inputWidth: Int, inputHeight: Int,
        target: Int, table: JSONObject, horizontal: Boolean,
    ): ByteArray {
        val outputWidth = if (horizontal) target else inputWidth
        val outputHeight = if (horizontal) inputHeight else target
        val output = ByteArray(outputWidth * outputHeight * 3)
        val starts = table.getJSONArray("starts")
        val coefficients = table.getJSONArray("weights")
        val bits = table.getInt("bits")
        // Округление каждого прохода повторяет Pillow 12.2.0, libImaging/Resample.c.
        val rounding = 1L shl (bits - 1)
        for (y in 0 until outputHeight) {
            for (x in 0 until outputWidth) {
                val coordinate = if (horizontal) x else y
                val start = starts.getInt(coordinate)
                val weights = coefficients.getJSONArray(coordinate)
                for (channel in 0 until 3) {
                    var sum = rounding
                    for (offset in 0 until weights.length()) {
                        val inputX = if (horizontal) start + offset else x
                        val inputY = if (horizontal) y else start + offset
                        val pixel = input[(inputY * inputWidth + inputX) * 3 + channel].toInt() and 255
                        sum += pixel.toLong() * weights.getLong(offset)
                    }
                    output[(y * outputWidth + x) * 3 + channel] = (sum shr bits).coerceIn(0, 255).toByte()
                }
            }
        }
        return output
    }
}
