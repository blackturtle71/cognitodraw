import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:cognitodraw/data/local_records_repository.dart';
import 'package:cognitodraw/features/records.dart';
import 'package:cognitodraw/inference/assessment.dart';
import 'package:cognitodraw/inference/mobile_inference.dart';
import 'package:cognitodraw/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const assessment = DrawingAssessment(
  label: 1,
  score: 0.75,
  modelVersion: 'test-model',
  preprocessingVersion: 'test-preprocessing',
  inputFingerprint: 'test-input',
  assessedAt: '2026-10-27T12:00:00Z',
);

const snapshot = DrawingAttemptSnapshot(
  metadata: ParticipantMetadata(
    fullName: 'Участник',
    age: 70,
    sex: 'male',
    complaint: '',
  ),
  taskType: 'clock',
  sessionId: 'session',
  attemptId: 'attempt',
  fileName: 'drawing.gif',
  timeToComplete: 20,
  repeatTaps: 0,
  createdAt: '2026-10-27T11:00:00Z',
);

class ControlledInference implements DrawingInference {
  final completion = Completer<DrawingAssessment>();
  @override
  Future<String> modelVersion() async => 'test-model';
  @override
  Future<DrawingAssessment> assess(DrawingRecord record) => completion.future;
}

class MemoryRecords extends LocalRecordsRepository {
  MemoryRecords(this.record);
  DrawingRecord record;
  @override
  Future<List<DrawingRecord>> listRecords() async => [record];
  @override
  Future<void> saveAssessment(
    DrawingRecord input,
    DrawingAssessment assessment,
  ) async {
    record = record.copyWith(assessment: assessment);
  }
}

DrawingRecord widgetRecord() => DrawingRecord.fromMap({
  ...snapshot.toJson(),
  'id': 1,
  'gifPath': 'drawing.gif',
  'comment': '',
  'updatedAt': '',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temporary;
  late LocalRecordsRepository repository;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp(
      'cognitodraw_mobile_test_',
    );
    repository = LocalRecordsRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${temporary.path}/records.sqlite',
      gifDirectory: Directory('${temporary.path}/drawings'),
      exportDirectory: Directory('${temporary.path}/exports'),
    );
  });

  tearDown(() async {
    await repository.close();
    await temporary.delete(recursive: true);
  });

  test(
    'оценка сохраняется отдельно и сбрасывается только при изменении входов',
    () async {
      final record = await repository.saveAttempt([1], snapshot);
      await repository.saveAssessment(record, assessment);

      await repository.updateRecord(
        record.copyWith(comment: 'Новый комментарий', fullName: 'Другое имя'),
      );
      expect(
        (await repository.listRecords()).single.assessment?.score,
        assessment.score,
      );
      await repository.updateRecord(record.copyWith(timeToComplete: 21));
      expect((await repository.listRecords()).single.assessment, isNull);
    },
  );

  test(
    'изменение входов во время оценки отклоняет устаревший результат',
    () async {
      final record = await repository.saveAttempt([1], snapshot);
      await repository.updateRecord(record.copyWith(age: 71));

      await expectLater(
        repository.saveAssessment(record, assessment),
        throwsStateError,
      );
      expect((await repository.listRecords()).single.assessment, isNull);
    },
  );

  test(
    'CSV и ZIP сохраняют оценку и канонический кадр без подмены метки обучения',
    () async {
      final record = await repository.saveAttempt(
        [1],
        snapshot,
        finalImage: [2],
        captureVersion: 'canonical-v1',
      );
      await repository.saveAssessment(record, assessment);

      final csv = String.fromCharCodes(
        await repository.exportCsvBytes(modelVersion: 'test-model'),
      );
      final headers = csv.split('\n').first.split(',');
      expect(
        headers,
        containsAll([
          'modelLabel',
          'modelScore',
          'modelVersion',
          'finalImageFileName',
        ]),
      );
      expect(headers, isNot(contains('label')));
      expect(csv.split('\n').last, endsWith('current'));
      final outdated = String.fromCharCodes(
        await repository.exportCsvBytes(modelVersion: 'new-model'),
      );
      expect(outdated.split('\n').last, endsWith('outdated'));
      final zip = await repository.exportGifZip();
      final archive = ZipDecoder().decodeBytes(await zip!.readAsBytes());
      expect(
        archive.files.map((file) => file.name),
        containsAll(['drawing.gif', 'drawing.png']),
      );
      await repository.deleteRecord(record);
      expect(await File(record.finalImagePath!).exists(), isFalse);
      expect(await repository.listRecords(), isEmpty);
    },
  );

  test('миграция версии 1 сохраняет исходные записи', () async {
    final oldPath = '${temporary.path}/old.sqlite';
    final old = await databaseFactoryFfi.openDatabase(
      oldPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''create table drawing_attempts (
          id integer primary key, fullName text, age integer, sex text, complaint text,
          taskType text, sessionId text, attemptId text, fileName text, gifPath text,
          timeToComplete integer, repeatTaps integer, comment text, createdAt text, updatedAt text
        )''');
          await db.insert('drawing_attempts', {
            ...DrawingRecord(
                id: 1,
                fullName: 'Старая запись',
                age: 70,
                sex: 'male',
                complaint: '',
                taskType: 'cube',
                sessionId: 's',
                attemptId: 'a',
                fileName: 'old.gif',
                gifPath: 'old.gif',
                timeToComplete: 10,
                repeatTaps: 0,
                comment: 'Исходная оценка',
                createdAt: '',
                updatedAt: '',
              ).toMap()
              ..remove('finalImagePath')
              ..remove('captureVersion'),
          });
        },
      ),
    );
    await old.close();
    final upgraded = LocalRecordsRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: oldPath,
    );
    try {
      final records = await upgraded.listRecords();
      expect(records.single.comment, 'Исходная оценка');
      expect(records.single.finalImagePath, isNull);
      expect(records.single.assessment, isNull);
    } finally {
      await upgraded.close();
    }
  });

  testWidgets('ручная оценка показывает прогресс и сохраняет результат', (
    tester,
  ) async {
    final record = widgetRecord();
    final memory = MemoryRecords(record);
    final inference = ControlledInference();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordsPage(
            repository: memory,
            initialRecords: [record],
            inference: inference,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Оценить рисунок'));
    await tester.pump();
    expect(find.text('Идёт оценка…'), findsOneWidget);
    inference.completion.complete(assessment);
    await tester.pumpAndSettle();

    expect(find.text('Оценка модели: 0.750'), findsOneWidget);
    expect(memory.record.assessment?.label, 1);
  });

  testWidgets('ошибка оценки не создаёт фиктивную метку', (tester) async {
    final record = widgetRecord();
    final memory = MemoryRecords(record);
    final inference = ControlledInference();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordsPage(
            repository: memory,
            initialRecords: [record],
            inference: inference,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Оценить рисунок'));
    await tester.pump();
    inference.completion.completeError(StateError('Файл рисунка не найден'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Файл рисунка не найден'), findsOneWidget);
    expect(memory.record.assessment, isNull);
  });

  testWidgets('устаревшая оценка видна на узком экране без переполнения', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(343, 548);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final old = DrawingAssessment.fromMap({
      ...assessment.toMap(),
      'modelVersion': 'old-model',
    });
    final record = widgetRecord().copyWith(assessment: old);
    final memory = MemoryRecords(record);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordsPage(
            repository: memory,
            initialRecords: [record],
            inference: ControlledInference(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Результат устарел. Повторите оценку.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
