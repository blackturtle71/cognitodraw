import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/utils.dart';

class DrawingRecord {
  final int? id;
  final String fullName;
  final int? age;
  final String? sex;
  final String complaint;
  final String taskType;
  final String sessionId;
  final String attemptId;
  final String fileName;
  final String gifPath;
  final int? timeToComplete;
  final int? repeatTaps;
  final String comment;
  final String createdAt;
  final String updatedAt;

  const DrawingRecord({
    this.id,
    required this.fullName,
    required this.age,
    required this.sex,
    required this.complaint,
    required this.taskType,
    required this.sessionId,
    required this.attemptId,
    required this.fileName,
    required this.gifPath,
    required this.timeToComplete,
    required this.repeatTaps,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  DrawingRecord copyWith({
    int? id,
    String? fullName,
    int? age,
    String? sex,
    String? complaint,
    String? taskType,
    String? sessionId,
    String? attemptId,
    String? fileName,
    String? gifPath,
    int? timeToComplete,
    int? repeatTaps,
    String? comment,
    String? createdAt,
    String? updatedAt,
  }) {
    return DrawingRecord(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      complaint: complaint ?? this.complaint,
      taskType: taskType ?? this.taskType,
      sessionId: sessionId ?? this.sessionId,
      attemptId: attemptId ?? this.attemptId,
      fileName: fileName ?? this.fileName,
      gifPath: gifPath ?? this.gifPath,
      timeToComplete: timeToComplete ?? this.timeToComplete,
      repeatTaps: repeatTaps ?? this.repeatTaps,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'age': age,
      'sex': sex,
      'complaint': complaint,
      'taskType': taskType,
      'sessionId': sessionId,
      'attemptId': attemptId,
      'fileName': fileName,
      'gifPath': gifPath,
      'timeToComplete': timeToComplete,
      'repeatTaps': repeatTaps,
      'comment': comment,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static DrawingRecord fromMap(Map<String, Object?> map) {
    return DrawingRecord(
      id: map['id'] as int?,
      fullName: map['fullName'] as String? ?? '',
      age: map['age'] as int?,
      sex: map['sex'] as String?,
      complaint: map['complaint'] as String? ?? '',
      taskType: map['taskType'] as String? ?? '',
      sessionId: map['sessionId'] as String? ?? '',
      attemptId: map['attemptId'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      gifPath: map['gifPath'] as String? ?? '',
      timeToComplete: map['timeToComplete'] as int?,
      repeatTaps: map['repeatTaps'] as int?,
      comment: map['comment'] as String? ?? '',
      createdAt: map['createdAt'] as String? ?? '',
      updatedAt: map['updatedAt'] as String? ?? '',
    );
  }
}

class LocalRecordsRepository {
  LocalRecordsRepository({
    DatabaseFactory? databaseFactory,
    String? databasePath,
    Directory? gifDirectory,
    Directory? exportDirectory,
  }) : _databaseFactory = databaseFactory,
       _databasePath = databasePath,
       _gifDirectory = gifDirectory,
       _exportDirectory = exportDirectory;

  final DatabaseFactory? _databaseFactory;
  final String? _databasePath;
  final Directory? _gifDirectory;
  final Directory? _exportDirectory;
  Database? _database;

  static const tableName = 'drawing_attempts';

  Future<Database> get _db async {
    if (_database != null) {
      return _database!;
    }

    final path = _databasePath ?? await _defaultDatabasePath();
    final factory = _databaseFactory ?? databaseFactory;
    _database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            create table $tableName (
              id integer primary key autoincrement,
              fullName text not null,
              age integer,
              sex text,
              complaint text not null default '',
              taskType text not null,
              sessionId text not null,
              attemptId text not null,
              fileName text not null,
              gifPath text not null,
              timeToComplete integer,
              repeatTaps integer,
              comment text not null default '',
              createdAt text not null,
              updatedAt text not null
            )
          ''');
          await db.execute(
            'create unique index ${tableName}_attempt_idx '
            'on $tableName(sessionId, attemptId)',
          );
          await db.execute(
            'create index ${tableName}_created_idx on $tableName(createdAt)',
          );
        },
      ),
    );
    return _database!;
  }

  Future<List<DrawingRecord>> listRecords() async {
    final db = await _db;
    final rows = await db.query(tableName, orderBy: 'createdAt desc, id desc');
    return rows.map(DrawingRecord.fromMap).toList();
  }

  Future<int> recordCount() async {
    final db = await _db;
    final result = await db.rawQuery(
      'select count(*) as count from $tableName',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<DrawingRecord> saveAttempt(
    List<int> gifBytes,
    DrawingAttemptSnapshot snapshot,
  ) async {
    final directory = await _ensureGifDirectory();
    final file = File(p.join(directory.path, snapshot.fileName));
    await file.writeAsBytes(gifBytes, flush: true);

    final now = DateTime.now().toUtc().toIso8601String();
    final record = DrawingRecord(
      fullName: snapshot.metadata.fullName,
      age: snapshot.metadata.age,
      sex: snapshot.metadata.sex,
      complaint: snapshot.metadata.complaint,
      taskType: snapshot.taskType,
      sessionId: snapshot.sessionId,
      attemptId: snapshot.attemptId,
      fileName: snapshot.fileName,
      gifPath: file.path,
      timeToComplete: snapshot.timeToComplete,
      repeatTaps: snapshot.repeatTaps,
      comment: '',
      createdAt: snapshot.createdAt.isEmpty ? now : snapshot.createdAt,
      updatedAt: now,
    );

    final db = await _db;
    final id = await db.insert(
      tableName,
      record.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return record.copyWith(id: id);
  }

  Future<void> updateRecord(DrawingRecord record) async {
    final id = record.id;
    if (id == null) {
      return;
    }

    final updated = record.copyWith(
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    final db = await _db;
    await db.update(
      tableName,
      updated.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRecord(DrawingRecord record) async {
    final id = record.id;
    if (id == null) {
      return;
    }

    final db = await _db;
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<File> exportCsv() async {
    final directory = await _ensureExportDirectory();
    final file = File(p.join(directory.path, '${_timestampedName('csv')}.csv'));
    await file.writeAsBytes(await exportCsvBytes(), flush: true);
    return file;
  }

  Future<List<int>> exportCsvBytes() async {
    final records = await listRecords();
    return utf8.encode(_recordsToCsv(records));
  }

  Future<File?> exportGifZip() async {
    final records = await listRecords();
    final archive = Archive();
    final usedNames = <String>{};

    for (var index = 0; index < records.length; index += 1) {
      final record = records[index];
      final file = File(record.gifPath);
      if (!await file.exists()) {
        continue;
      }

      final bytes = await file.readAsBytes();
      final entryName = _uniqueArchiveName(
        usedNames: usedNames,
        preferredName: record.fileName,
        fallbackIndex: index,
        recordId: record.id,
      );
      archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
    }

    if (archive.files.isEmpty) {
      return null;
    }

    final encoded = ZipEncoder().encode(archive);

    final directory = await _ensureExportDirectory();
    final file = File(
      p.join(directory.path, '${_timestampedName('gifs')}.zip'),
    );
    await file.writeAsBytes(encoded, flush: true);
    return file;
  }

  Future<List<File>> gifFiles() async {
    final records = await listRecords();
    return records
        .map((record) => File(record.gifPath))
        .where((file) => file.existsSync())
        .toList();
  }

  Future<String> _defaultDatabasePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, 'cognitodraw.sqlite');
  }

  Future<Directory> _ensureGifDirectory() async {
    final directory =
        _gifDirectory ??
        Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'gifs'),
        );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> _ensureExportDirectory() async {
    final directory =
        _exportDirectory ??
        Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'exports'),
        );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _recordsToCsv(List<DrawingRecord> records) {
    const headers = [
      'id',
      'fullName',
      'age',
      'sex',
      'complaint',
      'taskType',
      'sessionId',
      'attemptId',
      'fileName',
      'gifPath',
      'timeToComplete',
      'repeatTaps',
      'comment',
      'createdAt',
      'updatedAt',
    ];
    final rows = <List<Object?>>[
      headers,
      ...records.map(
        (record) => [
          record.id,
          record.fullName,
          record.age,
          record.sex,
          record.complaint,
          record.taskType,
          record.sessionId,
          record.attemptId,
          record.fileName,
          record.gifPath,
          record.timeToComplete,
          record.repeatTaps,
          record.comment,
          record.createdAt,
          record.updatedAt,
        ],
      ),
    ];
    return rows.map((row) => row.map(_csvCell).join(',')).join('\n');
  }

  String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    final escaped = text.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _timestampedName(String suffix) {
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    return 'cognitodraw_${suffix}_$stamp';
  }

  String _uniqueArchiveName({
    required Set<String> usedNames,
    required String preferredName,
    required int fallbackIndex,
    required int? recordId,
  }) {
    final baseName =
        preferredName.trim().isEmpty
            ? 'record_${recordId ?? fallbackIndex}.gif'
            : preferredName.trim();
    if (usedNames.add(baseName)) {
      return baseName;
    }

    final extension = p.extension(baseName);
    final stem = p.basenameWithoutExtension(baseName);
    var counter = 2;
    while (true) {
      final candidate =
          '${stem}_${recordId ?? fallbackIndex}_$counter$extension';
      if (usedNames.add(candidate)) {
        return candidate;
      }
      counter += 1;
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
