import 'dart:io';

import 'package:archive/archive.dart';
import 'package:cognitodraw/data/local_records_repository.dart';
import 'package:cognitodraw/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalRecordsRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cognitodraw_db_test_');
    repository = LocalRecordsRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${tempDir.path}/test.sqlite',
      gifDirectory: Directory('${tempDir.path}/gifs'),
      exportDirectory: Directory('${tempDir.path}/exports'),
    );
  });

  tearDown(() async {
    await repository.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saves a drawing attempt as sqlite row and gif file', () async {
    const snapshot = DrawingAttemptSnapshot(
      metadata: ParticipantMetadata(
        fullName: 'Иван Иванов',
        age: 72,
        sex: 'male',
        complaint: 'нет',
      ),
      taskType: 'clock',
      sessionId: 's_1',
      attemptId: 'a_1',
      fileName: 'Ivan_clock_s_1_a_1.gif',
      timeToComplete: 20,
      repeatTaps: 1,
      createdAt: '2026-05-18T12:00:00.000Z',
    );

    final record = await repository.saveAttempt([1, 2, 3], snapshot);
    final records = await repository.listRecords();

    expect(record.id, isNotNull);
    expect(records, hasLength(1));
    expect(records.single.fullName, 'Иван Иванов');
    expect(records.single.taskType, 'clock');
    expect(await File(records.single.gifPath).exists(), isTrue);
  });

  test('updates editable record fields', () async {
    const snapshot = DrawingAttemptSnapshot(
      metadata: ParticipantMetadata(
        fullName: 'Иван',
        age: 70,
        sex: 'male',
        complaint: '',
      ),
      taskType: 'cube',
      sessionId: 's_2',
      attemptId: 'a_2',
      fileName: 'Ivan_cube_s_2_a_2.gif',
      timeToComplete: 15,
      repeatTaps: 0,
      createdAt: '2026-05-18T12:00:00.000Z',
    );

    final record = await repository.saveAttempt([1], snapshot);
    await repository.updateRecord(
      record.copyWith(fullName: 'Пётр', timeToComplete: 18, comment: 'ok'),
    );

    final records = await repository.listRecords();
    expect(records.single.fullName, 'Пётр');
    expect(records.single.timeToComplete, 18);
    expect(records.single.comment, 'ok');
  });

  test('exports csv with escaped values', () async {
    const snapshot = DrawingAttemptSnapshot(
      metadata: ParticipantMetadata(
        fullName: 'Иван, "Тест"',
        age: 72,
        sex: 'male',
        complaint: 'line\nbreak',
      ),
      taskType: 'clock',
      sessionId: 's_3',
      attemptId: 'a_3',
      fileName: 'Ivan_clock_s_3_a_3.gif',
      timeToComplete: 10,
      repeatTaps: 0,
      createdAt: '2026-05-18T12:00:00.000Z',
    );

    await repository.saveAttempt([1], snapshot);
    final file = await repository.exportCsv();
    final csv = await file.readAsString();

    expect(csv, contains('"Иван, ""Тест"""'));
    expect(csv, contains('"line\nbreak"'));
    expect(csv, contains('gifPath'));
  });

  test('exports gif zip with unique entry names', () async {
    const first = DrawingAttemptSnapshot(
      metadata: ParticipantMetadata(
        fullName: 'Иван',
        age: 72,
        sex: 'male',
        complaint: '',
      ),
      taskType: 'clock',
      sessionId: 's_4',
      attemptId: 'a_4',
      fileName: 'same.gif',
      timeToComplete: 10,
      repeatTaps: 0,
      createdAt: '2026-05-18T12:00:00.000Z',
    );
    const second = DrawingAttemptSnapshot(
      metadata: ParticipantMetadata(
        fullName: 'Пётр',
        age: 73,
        sex: 'male',
        complaint: '',
      ),
      taskType: 'cube',
      sessionId: 's_5',
      attemptId: 'a_5',
      fileName: 'same.gif',
      timeToComplete: 12,
      repeatTaps: 1,
      createdAt: '2026-05-18T12:05:00.000Z',
    );

    await repository.saveAttempt([1, 2, 3], first);
    await repository.saveAttempt([4, 5, 6], second);
    final zip = await repository.exportGifZip();

    expect(zip, isNotNull);
    final archive = ZipDecoder().decodeBytes(await zip!.readAsBytes());
    final names = archive.files.map((file) => file.name).toList();

    expect(names, hasLength(2));
    expect(names.toSet(), hasLength(2));
    expect(names.first, 'same.gif');
  });
}
