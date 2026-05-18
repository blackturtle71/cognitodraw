import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_recorder/screen_recorder.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../utils/utils.dart';
import '../constants/text_constants.dart';

import 'package:translit/translit.dart';

class DrawMenu extends StatelessWidget {
  const DrawMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final titleStyle = TextStyle(
      fontSize: 24,
      color: theme.colorScheme.onSurface,
      height: 1.5,
    );
    final descriptionStyle = TextStyle(
      fontSize: 16,
      color: theme.colorScheme.onSurface,
      height: 1.5,
    );
    return ListView.builder(
      padding: EdgeInsets.all(16.0),
      itemCount: drawPageCards.length,
      itemBuilder: (context, index) {
        final card = drawPageCards[index];
        return Column(
          children: [
            Card(
              margin: EdgeInsets.all(8),
              child: ListTile(
                title: Text(
                  card.title,
                  style: titleStyle,
                  textAlign: TextAlign.center,
                ),
                subtitle: Text(
                  card.description,
                  style: descriptionStyle,
                  textAlign: TextAlign.justify,
                ),
                onTap: () {
                  Navigator.pushNamed(context, card.onTapDestination!);
                },
              ),
            ),
            SizedBox(height: 10),
          ],
        );
      },
    );
  }
}

class DrawPage extends StatefulWidget {
  final String taskType;
  const DrawPage({super.key, required this.taskType});

  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  bool _recording = false;
  bool _exporting = false;
  ScreenRecorderController controller = ScreenRecorderController();
  bool get canExport => controller.exporter.hasFrames;
  bool _uploaded = false;

  final GlobalKey<_DrawingAreaState> _drawingAreaKey = GlobalKey();

  void _clearCanvas() {
    // Access the state method through the key
    _drawingAreaKey.currentState?.clearCanvas();
  }

  void _showUploadStatus() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(
          child: Text(
            _uploaded
                ? 'Файл успешно сохранён'
                : 'Ошибка соединения с сервером',
          ),
        ),
        backgroundColor: _uploaded ? Colors.green : Colors.red,
      ),
    );
  }

  void _showThanks() {
    showDialog(
      context: context,
      builder:
          (context) => InfoDialog(
            title: "Тест завершен, спасибо!",
            content:
                "Можете попробовать пройти тест заново или перейти на домашнюю страницу.",
          ),
    );
  }

  bool isDrawing = false;

  String fullName = 'NO_NAME';
  final String _storageKeyName = "fullName";
  final String _storageKeyTaps = "repeatTaps";
  int repeatTaps = 0;

  final String _storageKeyTime = "timeToComplete";
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      // Lock portrait on screen open
      DeviceOrientation.portraitUp,
    ]);
    StorageUtils.loadString(_storageKeyName).then((value) {
      if (value != null) {
        setState(() {
          fullName = value.replaceAll(' ', '_');
        });
      }
    });
    _resetTaps();
  }

  Future<void> _resetTaps() async {
    await StorageUtils.saveInt(_storageKeyTaps, repeatTaps);
  }

  void _startTimer() {
    _stopwatch.reset();
    _stopwatch.start();
  }

  void _stopTimer() async {
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed.inSeconds;
    await StorageUtils.saveInt(_storageKeyTime, elapsed);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      // Unlock on screen close
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    final ThemeData theme = Theme.of(context);
    final titleStyle = TextStyle(
      fontSize: 24,
      color: theme.colorScheme.onSurface,
      height: 1.5,
    );
    final descriptionStyle = TextStyle(
      fontSize: 16,
      color: theme.colorScheme.onSurface,
      height: 1.5,
    );
    final instuctionStyle = TextStyle(
      fontSize: 14,
      color: theme.colorScheme.onSurface,
      height: 1.5,
    );
    String taskTitle;
    String taskDescription;
    switch (widget.taskType) {
      case 'clock':
        taskTitle = 'Нарисуйте часы';

        taskDescription = clockTaskInstructions;
        break;
      case 'cube':
        taskTitle = 'Нарисуйте куб';
        taskDescription = cubeTaskInstructions;
        break;
      default:
        throw UnimplementedError('no task for ${widget.taskType} task type');
    }

    return ScreenRecorder(
      height: screenHeight,
      width: screenWidth,
      controller: controller,
      child: Scaffold(
        appBar: AppBar(
          elevation: 4,
          shadowColor: Colors.black,
          actions: <Widget>[
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => InfoDialog(
                        title: taskTitle,
                        content: taskDescription,
                      ),
                );
              },
              child: Row(
                children: [
                  Text('Инструкция', style: descriptionStyle),
                  SizedBox(width: 8),
                  Icon(Icons.info_outline, size: 24, color: Colors.black),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton:
            _exporting
                ? null
                : Stack(
                  children: <Widget>[
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: FloatingActionButton.extended(
                        heroTag: null,
                        onPressed: () {
                          if (isDrawing) {
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: Text(
                                      'Вы готовы закончить рисовать?',
                                    ),
                                    actions: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          TextButton(
                                            onPressed: () async {
                                              setState(() {
                                                isDrawing = false;
                                              });
                                              _stopTimer();
                                              Navigator.pop(context);
                                              _clearCanvas();
                                              controller.stop();
                                              setState(() {
                                                _recording = false;
                                              });
                                              if (canExport && !_exporting) {
                                                setState(() {
                                                  _exporting = true;
                                                });
                                                var gif =
                                                    await controller.exporter
                                                        .exportGif();
                                                if (gif == null) {
                                                  throw Exception();
                                                }
                                                // transliterate the name, bloody hell, this is stupid
                                                fullName = Translit()
                                                    .toTranslit(
                                                      source: fullName,
                                                    );
                                                final fileName =
                                                    '${fullName}_${widget.taskType}_${DateTime.now().microsecondsSinceEpoch}.gif';

                                                StorageUtils.uploadGif(
                                                  gif,
                                                  fileName,
                                                ).then((success) async {
                                                  if (success) {
                                                    setState(() {
                                                      _uploaded = true;
                                                    });
                                                  } else {
                                                    _uploaded = false;
                                                    final directory =
                                                        await getDownloadsDirectory();
                                                    final filePath =
                                                        '${directory?.path}/$fileName';
                                                    final file = File(filePath);
                                                    await file.writeAsBytes(
                                                      gif,
                                                    );
                                                  }
                                                  setState(() {
                                                    _exporting = false;
                                                  });
                                                  _showUploadStatus();
                                                  _showThanks();
                                                });
                                              }
                                            },
                                            child: Text('ДА'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: Text('НЕТ'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                            );
                          } else {
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: Text(
                                      'Вы готовы начать рисовать?',
                                      style: titleStyle,
                                      textAlign: TextAlign.center,
                                    ),
                                    actions: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              setState(() {
                                                isDrawing = true;
                                              });
                                              _clearCanvas();
                                              controller.start();
                                              setState(() {
                                                _recording = true;
                                              });
                                              _startTimer();
                                            },
                                            child: Text('ДА'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: Text('НЕТ'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                            );
                          }
                        },
                        label: isDrawing ? Text('Завершить') : Text('Начать'),
                      ),
                    ),
                    if (isDrawing)
                      Positioned(
                        left: 40,
                        bottom: 10,
                        child: FloatingActionButton.extended(
                          heroTag: null,
                          onPressed: () async {
                            _clearCanvas();
                            repeatTaps += 1;
                            await StorageUtils.saveInt(
                              _storageKeyTaps,
                              repeatTaps,
                            );
                          },
                          label: Text('Начать заново'),
                        ),
                      ),
                  ],
                ),
        body: Column(
          // for the cube task there should be a picture of a cube as well
          children: [
            if (_exporting)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: Colors.yellow[50]),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Идёт процесс сохранения. Не закрывайте приложение и не покидайте страницу!',
                          style: titleStyle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 25),
                      CircularProgressIndicator(),
                    ],
                  ),
                ),
              )
            else ...[
              if (widget.taskType == 'cube')
                Container(
                  decoration: BoxDecoration(color: Colors.white),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/cube.png', height: 150),
                    ],
                  ),
                ),
              Expanded(child: DrawingArea(key: _drawingAreaKey)),
            ],
          ],
        ),
      ),
    );
  }
}

// have no fucking clue how this works, revisit later

class DrawingArea extends StatefulWidget {
  final Function(List<DrawingStroke>)? onDrawingComplete;

  const DrawingArea({super.key, this.onDrawingComplete});

  @override
  State<DrawingArea> createState() => _DrawingAreaState();
}

// Define a class to represent each stroke with timing data

class _DrawingAreaState extends State<DrawingArea> {
  List<DrawingStroke> _lines = [];
  List<Offset> _currentLine = [];
  List<Duration> _currentTimestamps = [];
  Color _selectedColor = Colors.black;
  double _strokeWidth = 5.0;
  final GlobalKey _drawingAreaKey = GlobalKey();
  DateTime? _drawingStartTime;

  void clearCanvas() {
    setState(() {
      _lines.clear();
      _drawingStartTime = null;
    });
  }

  Duration _getCurrentDuration() {
    return DateTime.now().difference(_drawingStartTime ?? DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (details) {
            final RenderBox renderBox =
                _drawingAreaKey.currentContext?.findRenderObject() as RenderBox;
            final localPosition = renderBox.globalToLocal(
              details.globalPosition,
            );

            if (localPosition.dx >= 0 &&
                localPosition.dy >= 0 &&
                localPosition.dx <= renderBox.size.width &&
                localPosition.dy <= renderBox.size.height) {
              setState(() {
                _currentLine.add(localPosition);
                _currentTimestamps.add(_getCurrentDuration());
              });
            }
          },
          onPanStart: (details) {
            if (_drawingStartTime == null) {
              _drawingStartTime = DateTime.now();
            }

            final RenderBox renderBox =
                _drawingAreaKey.currentContext?.findRenderObject() as RenderBox;
            final localPosition = renderBox.globalToLocal(
              details.globalPosition,
            );

            if (localPosition.dx >= 0 &&
                localPosition.dy >= 0 &&
                localPosition.dx <= renderBox.size.width &&
                localPosition.dy <= renderBox.size.height) {
              setState(() {
                _currentLine = [localPosition];
                _currentTimestamps = [_getCurrentDuration()];
              });
            }
          },
          onPanEnd: (details) {
            setState(() {
              if (_currentLine.isNotEmpty) {
                final newStroke = DrawingStroke(
                  points: List.from(_currentLine),
                  color: _selectedColor,
                  strokeWidth: _strokeWidth,
                  timestamps: List.from(_currentTimestamps),
                );
                _lines.add(newStroke);
                _currentLine = [];
                _currentTimestamps = [];

                // Notify parent about the complete drawing
                widget.onDrawingComplete?.call(_lines);
              }
            });
          },
          child: Container(
            key: _drawingAreaKey,
            decoration: BoxDecoration(color: Colors.yellow[50]),
            child: CustomPaint(
              painter: Sketcher(
                lines: _lines,
                currentLine: _currentLine,
                color: _selectedColor,
                strokeWidth: _strokeWidth,
              ),
              size: Size(constraints.maxWidth, constraints.maxHeight),
            ),
          ),
        );
      },
    );
  }
}

// Card setup
final List<PageCards> drawPageCards = [
  PageCards(
    title: 'Часы',
    description: clockTaskDesc,
    onTapDestination: '/draw/Clock',
  ),
  PageCards(
    title: 'Куб',
    description: cubeTaskDesc,
    onTapDestination: '/draw/Cube',
  ),
];

class DrawClock extends StatelessWidget {
  const DrawClock({super.key});

  @override
  Widget build(BuildContext context) {
    return const DrawPage(taskType: 'clock');
  }
}

class DrawCube extends StatelessWidget {
  const DrawCube({super.key});

  @override
  Widget build(BuildContext context) {
    // should return a draw page plus an image of a cube
    return const DrawPage(taskType: 'cube');
  }
}
