import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:io';

Future<void> clearSharedPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
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

  static Future<bool> uploadGif(List<int> gifBytes, String fileName) async {
    final supabase = Supabase.instance.client;
    Uint8List uint8Gif = Uint8List.fromList(gifBytes);

    final fullName = await loadString('fullName');
    final age = await loadInt('age');
    final sex = await loadString('sex');
    final repeatTaps = await loadInt('repeatTaps');
    final timeToComplete = await loadInt('timeToComplete');
    final complaint = await loadString('comlpaint');

    try {
      // upload meta to table
      await supabase.from('user_meta').upsert({
        'fullName': fullName,
        'age': age,
        'sex': sex,
        'filename': fileName,
        'timeToComplete': timeToComplete,
        'repeatTaps': repeatTaps,
        'complaint': complaint,
        'comment': '',
      });

      // upload gif to bucket
      await supabase.storage
          .from('gif_storage') // Supabase bucket name
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
    final downloadsDir = await getDownloadsDirectory();

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
      final List<String> paths = files.map((f) => f.path).toList();
      return paths;
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
        if (line.points[i] != null && line.points[i + 1] != null) {
          canvas.drawLine(line.points[i], line.points[i + 1], paint);
        }
      }
    }

    // Draw current line in progress
    for (int i = 0; i < currentLine.length - 1; i++) {
      if (currentLine[i] != null && currentLine[i + 1] != null) {
        canvas.drawLine(currentLine[i], currentLine[i + 1], paint);
      }
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
