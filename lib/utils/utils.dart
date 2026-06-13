import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translit/translit.dart';

import 'dart:math';

class StorageKeys {
  static const fullName = 'fullName';
  static const age = 'age';
  static const sex = 'sex';
  static const complaint = 'complaint';
  static const legacyComplaint = 'comlpaint';
  static const repeatTaps = 'repeatTaps';
  static const timeToComplete = 'timeToComplete';
  static const sessionId = 'sessionId';
  static const clockTaskStatus = 'clockTaskStatus';
  static const cubeTaskStatus = 'cubeTaskStatus';

  static const sessionKeys = [
    fullName,
    age,
    sex,
    complaint,
    legacyComplaint,
    repeatTaps,
    timeToComplete,
    sessionId,
    clockTaskStatus,
    cubeTaskStatus,
  ];
}

class ParticipantMetadata {
  final String fullName;
  final int? age;
  final String? sex;
  final String complaint;

  const ParticipantMetadata({
    required this.fullName,
    required this.age,
    required this.sex,
    required this.complaint,
  });

  bool get isComplete =>
      fullName.trim().isNotEmpty &&
      age != null &&
      age! > 0 &&
      sex != null &&
      sex!.isNotEmpty;

  String get fileSafeName {
    final normalized = fullName.trim().replaceAll(RegExp(r'\s+'), '_');
    final transliterated = Translit().toTranslit(source: normalized);
    final safe = transliterated.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return safe.isEmpty ? 'NO_NAME' : safe;
  }

  static Future<ParticipantMetadata> load() async {
    final fullName = await StorageUtils.loadString(StorageKeys.fullName) ?? '';
    final age = await StorageUtils.loadInt(StorageKeys.age);
    final sex = await StorageUtils.loadString(StorageKeys.sex);
    var complaint = await StorageUtils.loadString(StorageKeys.complaint);
    final legacyComplaint = await StorageUtils.loadString(
      StorageKeys.legacyComplaint,
    );

    if ((complaint == null || complaint.isEmpty) &&
        legacyComplaint != null &&
        legacyComplaint.isNotEmpty) {
      complaint = legacyComplaint;
      await StorageUtils.saveString(StorageKeys.complaint, legacyComplaint);
      await StorageUtils.remove(StorageKeys.legacyComplaint);
    }

    return ParticipantMetadata(
      fullName: fullName,
      age: age,
      sex: sex,
      complaint: complaint ?? '',
    );
  }

  Future<void> save() async {
    await StorageUtils.saveString(StorageKeys.fullName, fullName.trim());
    await StorageUtils.saveInt(StorageKeys.age, age!);
    await StorageUtils.saveString(StorageKeys.sex, sex!);
    await StorageUtils.saveString(StorageKeys.complaint, complaint.trim());
    await StorageUtils.remove(StorageKeys.legacyComplaint);
  }
}

class DrawingAttemptSnapshot {
  final ParticipantMetadata metadata;
  final String taskType;
  final String sessionId;
  final String attemptId;
  final String fileName;
  final int? timeToComplete;
  final int? repeatTaps;
  final String createdAt;

  const DrawingAttemptSnapshot({
    required this.metadata,
    required this.taskType,
    required this.sessionId,
    required this.attemptId,
    required this.fileName,
    required this.timeToComplete,
    required this.repeatTaps,
    required this.createdAt,
  });

  Map<String, Object?> toJson() {
    return {
      'fullName': metadata.fullName,
      'age': metadata.age,
      'sex': metadata.sex,
      'complaint': metadata.complaint,
      'taskType': taskType,
      'sessionId': sessionId,
      'attemptId': attemptId,
      'fileName': fileName,
      'timeToComplete': timeToComplete,
      'repeatTaps': repeatTaps,
      'createdAt': createdAt,
    };
  }

  static DrawingAttemptSnapshot fromJson(Map<String, Object?> json) {
    return DrawingAttemptSnapshot(
      metadata: ParticipantMetadata(
        fullName: json['fullName'] as String? ?? '',
        age: json['age'] as int?,
        sex: json['sex'] as String?,
        complaint: json['complaint'] as String? ?? '',
      ),
      taskType: json['taskType'] as String? ?? 'legacy',
      sessionId: json['sessionId'] as String? ?? '',
      attemptId: json['attemptId'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      timeToComplete: json['timeToComplete'] as int?,
      repeatTaps: json['repeatTaps'] as int?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class StorageUtils {
  static final Random _idRandom = Random.secure();

  static Future<void> saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> loadString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  static Future<int?> loadInt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  }

  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> clearParticipantSession() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in StorageKeys.sessionKeys) {
      await prefs.remove(key);
    }
  }

  static Future<String> startParticipantSession() async {
    await clearParticipantSession();
    final sessionId = _buildId('s');
    await saveString(StorageKeys.sessionId, sessionId);
    return sessionId;
  }

  static Future<String> ensureSessionId() async {
    final existing = await loadString(StorageKeys.sessionId);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final sessionId = _buildId('s');
    await saveString(StorageKeys.sessionId, sessionId);
    return sessionId;
  }

  static String buildAttemptId() {
    return _buildId('a');
  }

  static Future<void> saveTaskStatus(String taskType, String status) async {
    final key = _taskStatusKey(taskType);
    if (key == null) {
      return;
    }

    await saveString(key, status);
  }

  static Future<String> loadTaskStatus(String taskType) async {
    final key = _taskStatusKey(taskType);
    if (key == null) {
      return 'notStarted';
    }

    return await loadString(key) ?? 'notStarted';
  }

  static Future<Map<String, String>> loadTaskStatuses() async {
    return {
      'clock': await loadTaskStatus('clock'),
      'cube': await loadTaskStatus('cube'),
    };
  }

  static String buildGifFileName({
    required ParticipantMetadata metadata,
    required String taskType,
    required String sessionId,
    required String attemptId,
  }) {
    return '${metadata.fileSafeName}_${taskType}_${sessionId}_$attemptId.gif';
  }

  static Future<DrawingAttemptSnapshot> buildAttemptSnapshot({
    required String taskType,
    required int? timeToComplete,
    required int? repeatTaps,
  }) async {
    final metadata = await ParticipantMetadata.load();
    final sessionId = await ensureSessionId();
    final attemptId = buildAttemptId();
    final fileName = buildGifFileName(
      metadata: metadata,
      taskType: taskType,
      sessionId: sessionId,
      attemptId: attemptId,
    );

    return DrawingAttemptSnapshot(
      metadata: metadata,
      taskType: taskType,
      sessionId: sessionId,
      attemptId: attemptId,
      fileName: fileName,
      timeToComplete: timeToComplete,
      repeatTaps: repeatTaps,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  static String _buildId(String prefix) {
    final time = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(
      36,
    );
    final entropy = _idRandom
        .nextInt(0xFFFFFF)
        .toRadixString(36)
        .padLeft(5, '0');
    return '${prefix}_${time}_$entropy';
  }

  static String? _taskStatusKey(String taskType) {
    switch (taskType) {
      case 'clock':
        return StorageKeys.clockTaskStatus;
      case 'cube':
        return StorageKeys.cubeTaskStatus;
      default:
        return null;
    }
  }
}

class PageCards {
  final String title;
  final String description;
  final String? onTapDestination;

  PageCards({
    required this.title,
    required this.description,
    this.onTapDestination,
  });
}

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final List<Duration> timestamps; // Time since start for each point

  DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.timestamps,
  });
}

class Sketcher extends CustomPainter {
  final List<DrawingStroke> lines;
  final List<Offset> currentLine;
  final Color color;
  final double strokeWidth;

  Sketcher({
    required this.lines,
    required this.currentLine,
    this.color = Colors.black,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth;

    // Draw all completed lines
    for (var line in lines) {
      for (int i = 0; i < line.points.length - 1; i++) {
        canvas.drawLine(line.points[i], line.points[i + 1], paint);
      }
    }

    // Draw current line in progress
    for (int i = 0; i < currentLine.length - 1; i++) {
      canvas.drawLine(currentLine[i], currentLine[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(Sketcher oldDelegate) => true;
}

class InfoDialog extends StatelessWidget {
  final String title;
  final String content;
  const InfoDialog({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(child: Text(title)),
      content: Text(content),
      actions: [
        Center(
          child: TextButton(
            child: Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }
}

class AudioPlayerButton extends StatefulWidget {
  final String taskType;
  const AudioPlayerButton({super.key, required this.taskType});
  @override
  State<AudioPlayerButton> createState() => _AudioPlayerButtonState();
}

class _AudioPlayerButtonState extends State<AudioPlayerButton> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  IconData _icon = Icons.play_arrow;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _icon = Icons.play_arrow;
      });
    } else {
      await _audioPlayer.play(AssetSource('audio/${widget.taskType}_task.mp3'));
      setState(() {
        _isPlaying = true;
        _icon = Icons.stop;
      });
      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() {
          _isPlaying = false;
          _icon = Icons.play_arrow;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(_icon),
      label: Text(
        _isPlaying ? 'Выключить аудио описание' : 'Включить аудио описание',
      ),
      onPressed: _toggleAudio,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}
