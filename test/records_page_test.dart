import 'package:cognitodraw/data/local_records_repository.dart';
import 'package:cognitodraw/features/records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('records page exposes zip and csv share/save actions', (
    tester,
  ) async {
    final repository = _FakeRecordsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordsPage(repository: repository, initialRecords: const []),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Рисунки (GIF и PNG)'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
    expect(find.text('Отправить ZIP'), findsOneWidget);
    expect(find.text('Сохранить ZIP'), findsOneWidget);
    expect(find.text('Отправить CSV'), findsOneWidget);
    expect(find.text('Сохранить CSV'), findsOneWidget);
    expect(find.text('Локальная база данных пуста'), findsOneWidget);
  });

  testWidgets('records page confirms and deletes a record with its gif', (
    tester,
  ) async {
    const record = DrawingRecord(
      id: 1,
      fullName: 'Иван Иванов',
      age: 72,
      sex: 'male',
      complaint: '',
      taskType: 'clock',
      sessionId: 's_delete',
      attemptId: 'a_delete',
      fileName: 'Ivan_clock_s_delete_a_delete.gif',
      gifPath: '/tmp/Ivan_clock_s_delete_a_delete.gif',
      timeToComplete: 20,
      repeatTaps: 1,
      comment: '',
      createdAt: '2026-05-18T12:00:00.000Z',
      updatedAt: '2026-05-18T12:00:00.000Z',
    );
    final repository = _FakeRecordsRepository([record]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordsPage(repository: repository, initialRecords: [record]),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Иван Иванов'), findsOneWidget);
    expect(find.byTooltip('Редактировать'), findsOneWidget);
    expect(find.byTooltip('Удалить'), findsOneWidget);

    await tester.tap(find.byTooltip('Удалить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Удалить запись?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Иван Иванов'), findsOneWidget);
    expect(await repository.recordCount(), 1);

    await tester.tap(find.byTooltip('Удалить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Локальная база данных пуста'), findsOneWidget);
    expect(await repository.recordCount(), 0);
    expect(repository.deletedRecords, [record]);
  });
}

class _FakeRecordsRepository extends LocalRecordsRepository {
  _FakeRecordsRepository([List<DrawingRecord> records = const []])
    : _records = [...records];

  final List<DrawingRecord> _records;
  final List<DrawingRecord> deletedRecords = [];

  @override
  Future<List<DrawingRecord>> listRecords() async => [..._records];

  @override
  Future<int> recordCount() async => _records.length;

  @override
  Future<void> deleteRecord(DrawingRecord record) async {
    deletedRecords.add(record);
    _records.removeWhere((candidate) => candidate.id == record.id);
  }
}
