import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/text_constants.dart';
import '../utils/utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _sessionVersion = 0;
  int _uploadVersion = 0;
  int _statusVersion = 0;

  Future<void> _resetParticipantSession({required bool deletePending}) async {
    if (deletePending) {
      final paths = await StorageUtils.checkDownloadsDir();
      await StorageUtils.deletePendingFiles(paths);
    }

    await StorageUtils.startParticipantSession();

    if (!mounted) return;
    setState(() {
      _sessionVersion += 1;
      _uploadVersion += 1;
      _statusVersion += 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Center(child: Text('Сессия нового участника начата')),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final titleStyle = TextStyle(
      fontSize: 22,
      color: theme.colorScheme.onSurface,
      height: 1.5,
    );
    final descriptionStyle = TextStyle(
      fontSize: 16,
      color: theme.colorScheme.onSurface,
      height: 1.5,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Руководство пользователя',
                style: titleStyle,
                textAlign: TextAlign.center,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                homeUserGuide,
                style: descriptionStyle,
                textAlign: TextAlign.start,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SessionStatusCard(
          key: ValueKey('status-$_statusVersion-$_uploadVersion'),
          titleStyle: titleStyle,
          descriptionStyle: descriptionStyle,
        ),
        const SizedBox(height: 10),
        NewSessionCard(
          titleStyle: titleStyle,
          descriptionStyle: descriptionStyle,
          onReset: _resetParticipantSession,
        ),
        const SizedBox(height: 10),
        InputCard(
          key: ValueKey(_sessionVersion),
          titleStyle: titleStyle,
          descriptionStyle: descriptionStyle,
          onSaved: _refreshStatus,
        ),
        const SizedBox(height: 10),
        UploadCard(
          key: ValueKey(_uploadVersion),
          titleStyle: titleStyle,
          onUploaded: _refreshUploadStatus,
        ),
      ],
    );
  }

  void _refreshStatus() {
    setState(() {
      _statusVersion += 1;
    });
  }

  void _refreshUploadStatus() {
    setState(() {
      _statusVersion += 1;
      _uploadVersion += 1;
    });
  }
}

class SessionStatusCard extends StatefulWidget {
  const SessionStatusCard({
    super.key,
    required this.titleStyle,
    required this.descriptionStyle,
  });

  final TextStyle titleStyle;
  final TextStyle descriptionStyle;

  @override
  State<SessionStatusCard> createState() => _SessionStatusCardState();
}

class _SessionStatusCardState extends State<SessionStatusCard> {
  ParticipantMetadata? metadata;
  String? sessionId;
  int pendingCount = 0;
  Map<String, String> taskStatuses = const {
    'clock': 'notStarted',
    'cube': 'notStarted',
  };

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final loadedMetadata = await ParticipantMetadata.load();
    final loadedSessionId = await StorageUtils.loadString(
      StorageKeys.sessionId,
    );
    final pendingPaths = await StorageUtils.checkDownloadsDir();
    final loadedTaskStatuses = await StorageUtils.loadTaskStatuses();

    if (!mounted) return;
    setState(() {
      metadata = loadedMetadata;
      sessionId = loadedSessionId;
      pendingCount = pendingPaths.length;
      taskStatuses = loadedTaskStatuses;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentMetadata = metadata;
    final confirmed = currentMetadata?.isComplete ?? false;

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Статус сессии',
            style: widget.titleStyle,
            textAlign: TextAlign.center,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusLine(
                label: 'Участник',
                value:
                    confirmed
                        ? '${currentMetadata!.fullName}, ${currentMetadata.age}, ${_sexLabel(currentMetadata.sex)}'
                        : 'данные не подтверждены',
              ),
              _StatusLine(label: 'Сессия', value: sessionId ?? 'не начата'),
              _StatusLine(
                label: 'Ожидают загрузки',
                value: pendingCount.toString(),
              ),
              const SizedBox(height: 8),
              _StatusLine(
                label: 'Часы',
                value: _taskStatusLabel(taskStatuses['clock']),
              ),
              _StatusLine(
                label: 'Куб',
                value: _taskStatusLabel(taskStatuses['cube']),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _sexLabel(String? sex) {
  switch (sex) {
    case 'male':
      return 'мужчина';
    case 'female':
      return 'женщина';
    default:
      return 'не указан';
  }
}

String _taskStatusLabel(String? status) {
  switch (status) {
    case 'uploaded':
      return 'загружено';
    case 'pendingUpload':
      return 'ожидает ручной загрузки';
    case 'failed':
      return 'ошибка сохранения';
    default:
      return 'не начато';
  }
}

class NewSessionCard extends StatefulWidget {
  const NewSessionCard({
    super.key,
    required this.titleStyle,
    required this.descriptionStyle,
    required this.onReset,
  });

  final TextStyle titleStyle;
  final TextStyle descriptionStyle;
  final Future<void> Function({required bool deletePending}) onReset;

  @override
  State<NewSessionCard> createState() => _NewSessionCardState();
}

class _NewSessionCardState extends State<NewSessionCard> {
  bool _resetting = false;

  Future<void> _startNewSession() async {
    final pendingPaths = await StorageUtils.checkDownloadsDir();
    if (!mounted) return;

    bool deletePending = false;

    if (pendingPaths.isNotEmpty) {
      final action = await showDialog<_PendingFileAction>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Есть несохранённые GIF-файлы'),
              content: Text(
                'Найдено локальных файлов: ${pendingPaths.length}. '
                'Можно начать новую сессию и оставить их для ручной загрузки '
                'или удалить их перед началом.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed:
                      () =>
                          Navigator.pop(context, _PendingFileAction.keepFiles),
                  child: const Text('Оставить файлы'),
                ),
                FilledButton(
                  onPressed:
                      () => Navigator.pop(
                        context,
                        _PendingFileAction.deleteFiles,
                      ),
                  child: const Text('Удалить файлы'),
                ),
              ],
            ),
      );

      if (action == null) {
        return;
      }

      deletePending = action == _PendingFileAction.deleteFiles;
    }

    setState(() {
      _resetting = true;
    });

    await widget.onReset(deletePending: deletePending);

    if (!mounted) return;
    setState(() {
      _resetting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Новая сессия участника',
            style: widget.titleStyle,
            textAlign: TextAlign.center,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Очистите данные текущего участника перед передачей устройства следующему человеку.',
                style: widget.descriptionStyle,
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _resetting ? null : _startNewSession,
                icon:
                    _resetting
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.person_add_alt_1),
                label: const Text('НАЧАТЬ НОВУЮ СЕССИЮ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PendingFileAction { keepFiles, deleteFiles }

class UploadCard extends StatefulWidget {
  final TextStyle titleStyle;
  final VoidCallback onUploaded;
  const UploadCard({
    super.key,
    required this.titleStyle,
    required this.onUploaded,
  });

  @override
  State<UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<UploadCard> {
  List<String> paths = [];
  List<PendingUploadInfo> pendingInfos = [];
  bool _uploaded = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    final result = await StorageUtils.checkDownloadsDir();
    final infos = await StorageUtils.loadPendingUploadInfo(result);
    if (!mounted) return;
    setState(() {
      paths = result;
      pendingInfos = infos;
    });
  }

  void _showUploadStatus() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(
          child: Text(
            _uploaded
                ? 'Файлы успешно сохранены'
                : 'Ошибка соединения с сервером',
          ),
        ),
        backgroundColor: _uploaded ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _uploadPendingFiles() async {
    if (!mounted) return;

    setState(() {
      _uploading = true;
      _uploaded = false;
    });

    bool allSuccess = true;

    for (var path in paths) {
      try {
        final success = await StorageUtils.uploadPendingGif(path);
        if (!success) {
          allSuccess = false;
        }
      } catch (_) {
        allSuccess = false;
      }
    }

    if (!mounted) return;

    setState(() {
      _uploading = false;
      _uploaded = allSuccess;
    });
    await _loadPaths();
    widget.onUploaded();
    _showUploadStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Загрузить данные вручную',
            style: widget.titleStyle,
            textAlign: TextAlign.center,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_uploading)
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: CircularProgressIndicator(),
                    ),
                    Text(
                      'Идёт процесс сохранения. Не закрывайте приложение и не покидайте страницу!',
                      textAlign: TextAlign.justify,
                    ),
                  ],
                )
              else ...[
                Text(
                  paths.isEmpty
                      ? 'Нет локальных GIF-файлов для загрузки.'
                      : 'Локальных GIF-файлов: ${paths.length}',
                ),
                if (pendingInfos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...pendingInfos.take(3).map((info) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        info.hasSidecar
                            ? info.displayTitle
                            : '${info.fileName} - legacy',
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: paths.isEmpty ? null : _uploadPendingFiles,
                  child: const Text('Загрузить'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class InputCard extends StatefulWidget {
  const InputCard({
    super.key,
    required this.titleStyle,
    required this.descriptionStyle,
    required this.onSaved,
  });

  final TextStyle titleStyle;
  final TextStyle descriptionStyle;
  final VoidCallback onSaved;

  @override
  State<InputCard> createState() => _InputCardState();
}

enum SexChoice { male, female }

class _InputCardState extends State<InputCard> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController comController = TextEditingController();

  String fullName = '';
  int? age;
  SexChoice? sexChoiceView;
  String complaint = '';

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    comController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final metadata = await ParticipantMetadata.load();
    if (!mounted) return;

    final loadedSex =
        metadata.sex == null
            ? null
            : SexChoice.values.where((choice) => choice.name == metadata.sex);

    setState(() {
      fullName = metadata.fullName;
      age = metadata.age;
      complaint = metadata.complaint;
      sexChoiceView =
          loadedSex == null || loadedSex.isEmpty ? null : loadedSex.first;
      nameController.text = metadata.fullName;
      ageController.text = metadata.age?.toString() ?? '';
      comController.text = metadata.complaint;
    });
  }

  Future<void> submitForm() async {
    final nameValue = nameController.text.trim();
    final ageValue = int.tryParse(ageController.text.trim());
    final comValue = comController.text.trim();

    if (nameValue.isEmpty || ageValue == null || ageValue <= 0) {
      _showError('Пожалуйста, введите имя и корректный возраст');
      return;
    }

    if (sexChoiceView == null) {
      _showError('Пожалуйста, выберите пол');
      return;
    }

    final metadata = ParticipantMetadata(
      fullName: nameValue,
      age: ageValue,
      sex: sexChoiceView!.name,
      complaint: comValue,
    );

    await metadata.save();

    if (!mounted) return;
    setState(() {
      fullName = nameValue;
      age = ageValue;
      complaint = comValue;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Center(child: Text('Данные успешно подтверждены')),
        backgroundColor: Colors.green,
      ),
    );
    widget.onSaved();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(child: Text(message)),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Введите свои данные',
            style: widget.titleStyle,
            textAlign: TextAlign.center,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName.isEmpty ? 'Имя:' : 'Ваше имя - $fullName',
                style: widget.descriptionStyle,
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Введите ФИО здесь',
                ),
              ),
              const SizedBox(height: 5),
              Text(
                age == null ? 'Возраст:' : 'Ваш возраст - $age',
                style: widget.descriptionStyle,
              ),
              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Введите свой возраст здесь',
                ),
              ),
              const SizedBox(height: 5),
              Text('Пол:', style: widget.descriptionStyle),
              Center(
                child: SegmentedButton<SexChoice>(
                  emptySelectionAllowed: true,
                  segments: const <ButtonSegment<SexChoice>>[
                    ButtonSegment<SexChoice>(
                      value: SexChoice.male,
                      label: Text('Мужчина'),
                    ),
                    ButtonSegment<SexChoice>(
                      value: SexChoice.female,
                      label: Text('Женщина'),
                    ),
                  ],
                  selected:
                      sexChoiceView == null
                          ? <SexChoice>{}
                          : <SexChoice>{sexChoiceView!},
                  onSelectionChanged: (Set<SexChoice> newSelection) {
                    setState(() {
                      sexChoiceView =
                          newSelection.isEmpty ? null : newSelection.first;
                    });
                  },
                ),
              ),
              const SizedBox(height: 5),
              Text('Жалобы (если имеются):', style: widget.descriptionStyle),
              TextField(
                controller: comController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Укажите жалобы, если имеются',
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: submitForm,
                  child: const Text('ПОДТВЕРДИТЬ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
