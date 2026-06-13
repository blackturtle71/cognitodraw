import 'dart:io';

import 'package:cognitodraw/data/local_records_repository.dart';
import 'package:cognitodraw/features/records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalRecordsRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cognitodraw_records_ui_');
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

  testWidgets('records page exposes zip and csv share/save actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecordsPage(repository: repository, initialRecords: const []),
      ),
    );
    await tester.pump();

    expect(find.text('GIF'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
    expect(find.text('Отправить ZIP'), findsOneWidget);
    expect(find.text('Сохранить ZIP'), findsOneWidget);
    expect(find.text('Отправить CSV'), findsOneWidget);
    expect(find.text('Сохранить CSV'), findsOneWidget);
    expect(find.text('Локальная база данных пуста'), findsOneWidget);
  });
}
