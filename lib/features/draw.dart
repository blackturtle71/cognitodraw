import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_recorder/screen_recorder.dart';

import '../utils/utils.dart';
import '../constants/text_constants.dart';

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

enum DrawTaskState { idle, recording, exporting, uploaded, failed }

class DrawPage extends StatefulWidget {
  final String taskType;
  const DrawPage({super.key, required this.taskType});

  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  DrawTaskState _taskState = DrawTaskState.idle;
  ScreenRecorderController controller = ScreenRecorderController();
  bool get canExport => controller.exporter.hasFrames;
  bool get _exporting => _taskState == DrawTaskState.exporting;

  final GlobalKey<_DrawingAreaState> _drawingAreaKey = GlobalKey();

  void _clearCanvas() {
    _drawingAreaKey.currentState?.clearCanvas();
  }

  void _showUploadStatus({required bool savedLocally}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(
          child: Text(
            _taskState == DrawTaskState.uploaded
                ? 'Файл успешно сохранён'
                : savedLocally
                ? 'Ошибка соединения с сервером. GIF сохранён локально'
                : 'Не удалось загрузить или сохранить GIF локально',
          ),
        ),
        backgroundColor:
            _taskState == DrawTaskState.uploaded ? Colors.green : Colors.red,
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

  int repeatTaps = 0;

  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      // Lock portrait on screen open
      DeviceOrientation.portraitUp,
    ]);
    _resetTaps();
  }

  Future<void> _resetTaps() async {
    await StorageUtils.saveInt(StorageKeys.repeatTaps, repeatTaps);
  }

  void _startTimer() {
    _stopwatch.reset();
    _stopwatch.start();
  }

  void _stopTimer() async {
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed.inSeconds;
    await StorageUtils.saveInt(StorageKeys.timeToComplete, elapsed);
  }

  Future<void> _startDrawing() async {
    final metadata = await ParticipantMetadata.load();
    if (!metadata.isComplete) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(
            child: Text(
              'Сначала подтвердите данные участника на главной странице',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      isDrawing = true;
      _taskState = DrawTaskState.recording;
      repeatTaps = 0;
    });
    await _resetTaps();
    _clearCanvas();
    controller.start();
    _startTimer();
  }

  Future<void> _finishDrawing() async {
    setState(() {
      isDrawing = false;
    });
    _stopTimer();
    _clearCanvas();
    controller.stop();

    if (!canExport || _exporting) {
      setState(() {
        _taskState = DrawTaskState.failed;
      });
      _showUploadStatus(savedLocally: false);
      return;
    }

    setState(() {
      _taskState = DrawTaskState.exporting;
    });

    final gif = await controller.exporter.exportGif();
    if (gif == null) {
      if (!mounted) return;
      setState(() {
        _taskState = DrawTaskState.failed;
      });
      _showUploadStatus(savedLocally: false);
      return;
    }

    final metadata = await ParticipantMetadata.load();
    final fileName = StorageUtils.buildGifFileName(
      metadata: metadata,
      taskType: widget.taskType,
    );

    final uploaded = await StorageUtils.uploadGif(gif, fileName);
    var savedLocally = false;

    if (!uploaded) {
      savedLocally = await StorageUtils.savePendingGif(gif, fileName);
    }

    if (!mounted) return;
    setState(() {
      _taskState = uploaded ? DrawTaskState.uploaded : DrawTaskState.failed;
    });
    _showUploadStatus(savedLocally: savedLocally);
    _showThanks();
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
                                              Navigator.pop(context);
                                              await _finishDrawing();
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
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await _startDrawing();
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
                              StorageKeys.repeatTaps,
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
  final List<DrawingStroke> _lines = [];
  List<Offset> _currentLine = [];
  List<Duration> _currentTimestamps = [];
  final Color _selectedColor = Colors.black;
  final double _strokeWidth = 5.0;
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
            _drawingStartTime ??= DateTime.now();

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
