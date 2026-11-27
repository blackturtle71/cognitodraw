import 'dart:ui' as ui;

import 'package:cognitodraw/features/draw.dart';
import 'package:cognitodraw/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final task in ['clock', 'cube']) {
    testWidgets(
      'канонический кадр $task сохраняет координаты при изменении экрана',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        List<int>? reference;
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = Size(343 * scale, 548 * scale);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: DrawingArea(key: UniqueKey(), taskType: task),
              ),
            ),
          );
          final painting = find.byWidgetPredicate(
            (widget) => widget is CustomPaint && widget.painter is Sketcher,
          );
          final rect = tester.getRect(painting);
          final gesture = await tester.startGesture(
            rect.topLeft + Offset(rect.width / 4, rect.height / 4),
          );
          await gesture.moveTo(
            rect.topLeft + Offset(rect.width * 3 / 4, rect.height * 3 / 4),
          );
          await gesture.up();
          await tester.pump();
          final dynamic state = tester.state(find.byType(DrawingArea));
          final pixels = await tester.runAsync(() async {
            final bytes = await state.captureFinalImage(task);
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            try {
              expect(frame.image.width, 343);
              expect(frame.image.height, 548);
              final rgba = await frame.image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              return rgba!.buffer.asUint8List().toList();
            } finally {
              frame.image.dispose();
              codec.dispose();
            }
          });
          expect(pixels, contains(0));
          if (reference == null) {
            reference = pixels;
          } else {
            expect(pixels, orderedEquals(reference));
          }
        }
      },
    );
  }
}
