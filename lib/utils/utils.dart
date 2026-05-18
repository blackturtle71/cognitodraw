import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translit/translit.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:io';

class StorageKeys {
  static const fullName = 'fullName';
  static const age = 'age';
  static const sex = 'sex';
  static const complaint = 'complaint';
  static const legacyComplaint = 'comlpaint';
  static const repeatTaps = 'repeatTaps';
  static const timeToComplete = 'timeToComplete';

  static const sessionKeys = [
    fullName,
    age,
    sex,
    complaint,
    legacyComplaint,
    repeatTaps,
    timeToComplete,
  ];
}

class SupabaseConfig {
  static const metadataTable = 'user_meta';
  static const gifBucket = 'gif_storage';
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

  Map<String, Object?> toSupabasePayload({
    required String fileName,
    required int? timeToComplete,
    required int? repeatTaps,
  }) {
    return {
      'fullName': fullName,
      'age': age,
      'sex': sex,
      'filename': fileName,
      'timeToComplete': timeToComplete,
      'repeatTaps': repeatTaps,
      'complaint': complaint,
      'comment': '',
    };
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

class StorageUtils {
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

  static String buildGifFileName({
    required ParticipantMetadata metadata,
    required String taskType,
    DateTime? timestamp,
  }) {
    final time = timestamp ?? DateTime.now();
    return '${metadata.fileSafeName}_${taskType}_${time.microsecondsSinceEpoch}.gif';
  }

  static Future<bool> uploadGif(List<int> gifBytes, String fileName) async {
    final supabase = Supabase.instance.client;
    Uint8List uint8Gif = Uint8List.fromList(gifBytes);

    final metadata = await ParticipantMetadata.load();
    final repeatTaps = await loadInt(StorageKeys.repeatTaps);
    final timeToComplete = await loadInt(StorageKeys.timeToComplete);

    if (!metadata.isComplete) {
      if (kDebugMode) {
        debugPrint('Upload blocked: participant metadata is incomplete.');
      }
      return false;
    }

    try {
      await supabase
          .from(SupabaseConfig.metadataTable)
          .upsert(
            metadata.toSupabasePayload(
              fileName: fileName,
              timeToComplete: timeToComplete,
              repeatTaps: repeatTaps,
            ),
          );

      await supabase.storage
          .from(SupabaseConfig.gifBucket)
          .uploadBinary(fileName, uint8Gif);

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Upload failed: $e');
      }
      return false;
    }
  }

  static Future<List<String>> checkDownloadsDir() async {
    final downloadsDir = await _safeDownloadsDirectory();

    if (downloadsDir == null) {
      return [];
    }

    final dir = Directory(downloadsDir.path);

    if (!await dir.exists()) {
      return [];
    }

    final files = dir.listSync();

    if (files.isEmpty) {
      return [];
    } else {
      final List<String> paths =
          files
              .whereType<File>()
              .map((f) => f.path)
              .where((path) => path.toLowerCase().endsWith('.gif'))
              .toList();
      return paths;
    }
  }

  static Future<bool> canUsePendingGifStorage() async {
    return await _safeDownloadsDirectory() != null;
  }

  static Future<bool> savePendingGif(
    List<int> gifBytes,
    String fileName,
  ) async {
    final directory = await _safeDownloadsDirectory();
    if (directory == null) {
      return false;
    }

    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(gifBytes);
    return true;
  }

  static Future<void> deletePendingFiles(List<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<Directory?> _safeDownloadsDirectory() async {
    try {
      return await getDownloadsDirectory();
    } on Object {
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
