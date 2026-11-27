import 'dart:convert';
import 'dart:io';

import 'package:cognitodraw/data/local_records_repository.dart';
import 'package:cognitodraw/inference/mobile_inference.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = Platform.environment['COGNITODRAW_REFERENCE_DIR'];
  const channel = MethodChannel('cognitodraw/inference');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'последние кадры всех исходных GIF совпадают с Pillow',
    () async {
      final root = Directory(directory!);
      final report =
          jsonDecode(await File('${root.path}/report.json').readAsString())
              as Map<String, dynamic>;
      final rows = report['results'] as List<dynamic>;
      var checked = 0;
      for (final value in rows) {
        final row = value as Map<String, dynamic>;
        final index = row['index'] as int;
        final expected = await File('${root.path}/$index.rgb').readAsBytes();
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'assess');
          final arguments = call.arguments as Map<dynamic, dynamic>;
          expect(arguments['width'], 343);
          expect(arguments['height'], 548);
          final rgba = arguments['frame'] as Uint8List;
          final rgb = Uint8List(343 * 548 * 3);
          const background = [255, 253, 231];
          for (var pixel = 0; pixel < 343 * 548; pixel++) {
            final alpha = rgba[pixel * 4 + 3];
            for (var component = 0; component < 3; component++) {
              rgb[pixel * 3 + component] =
                  (rgba[pixel * 4 + component] * alpha +
                      background[component] * (255 - alpha) +
                      127) ~/
                  255;
            }
          }
          expect(rgb, orderedEquals(expected), reason: 'GIF reference $index');
          checked += 1;
          return {
            'label': row['label'],
            'score': row['score'],
            'modelVersion': 'decode-test',
            'preprocessingVersion': 'decode-test',
            'inputFingerprint': 'decode-test',
          };
        });
        final metadata = row['metadata'] as Map<String, dynamic>;
        final record = DrawingRecord.fromMap({
          ...metadata,
          'taskType': row['task'],
          'gifPath': '${root.path}/$index.gif',
        });
        await MobileDrawingInference().assess(record);
      }
      expect(checked, rows.length);
    },
    skip:
        directory == null
            ? 'Нужны локальные приватные эталоны COGNITODRAW_REFERENCE_DIR'
            : false,
  );

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });
}
