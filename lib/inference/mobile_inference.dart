import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../data/local_records_repository.dart';
import 'assessment.dart';

abstract class DrawingInference {
  Future<String> modelVersion();
  Future<DrawingAssessment> assess(DrawingRecord record);
}

class MobileDrawingInference implements DrawingInference {
  static const _channel = MethodChannel('cognitodraw/inference');

  @override
  Future<String> modelVersion() async {
    final info = await _channel.invokeMapMethod<String, Object?>('info');
    if (info == null) throw StateError('Комплект моделей недоступен');
    return info['modelVersion'] as String;
  }

  @override
  Future<DrawingAssessment> assess(DrawingRecord record) async {
    if (record.finalImagePath != null &&
        record.captureVersion != 'canonical-v1') {
      throw StateError('Версия сохранённого рисунка не поддерживается');
    }
    if (record.age == null ||
        record.age! <= 0 ||
        !['female', 'male'].contains(record.sex) ||
        record.timeToComplete == null ||
        record.timeToComplete! < 0 ||
        record.repeatTaps == null ||
        record.repeatTaps! < 0) {
      throw StateError(
        'Заполните возраст, пол, время выполнения и число повторов',
      );
    }
    final file = File(record.finalImagePath ?? record.gifPath);
    if (!await file.exists()) throw StateError('Файл рисунка не найден');
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    ui.Image? image;
    try {
      for (var index = 0; index < codec.frameCount; index++) {
        final frame = await codec.getNextFrame();
        image?.dispose();
        image = frame.image;
      }
      final frame = image!;
      if (frame.width != 343 || frame.height != 548) {
        throw StateError(
          'Формат старой записи не поддерживается. Создайте новый рисунок.',
        );
      }
      final pixels = await frame.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (pixels == null) throw StateError('Не удалось прочитать рисунок');
      final result = await _channel.invokeMapMethod<String, Object?>('assess', {
        'task': record.taskType,
        'width': frame.width,
        'height': frame.height,
        'frame': pixels.buffer.asUint8List(
          pixels.offsetInBytes,
          pixels.lengthInBytes,
        ),
        'metadata': {
          'age': record.age,
          'sex': record.sex,
          'timeToComplete': record.timeToComplete,
          'repeatTaps': record.repeatTaps,
        },
      });
      if (result == null) throw StateError('Модель не вернула результат');
      return DrawingAssessment.fromMap({
        ...result,
        'assessedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } finally {
      image?.dispose();
      codec.dispose();
    }
  }
}
