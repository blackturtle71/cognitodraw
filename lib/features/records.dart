import 'dart:io';

import 'package:flutter/material.dart';
import 'package:public_file_saver/public_file_saver.dart';
import 'package:share_plus/share_plus.dart';

import '../data/local_records_repository.dart';
import '../inference/mobile_inference.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({
    super.key,
    this.repository,
    this.initialRecords,
    this.inference,
  });

  final LocalRecordsRepository? repository;
  final List<DrawingRecord>? initialRecords;
  final DrawingInference? inference;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  late final LocalRecordsRepository _repository =
      widget.repository ?? LocalRecordsRepository();
  List<DrawingRecord> _records = [];
  late final DrawingInference _inference =
      widget.inference ?? MobileDrawingInference();
  String? _modelVersion;
  int? _assessingId;
  bool _loading = true;
  bool _working = false;
  final PublicFileSaver _fileSaver = PublicFileSaver();

  @override
  void initState() {
    super.initState();
    _loadModelInfo();
    final initialRecords = widget.initialRecords;
    if (initialRecords == null) {
      _loadRecords();
    } else {
      _records = initialRecords;
      _loading = false;
    }
  }

  Future<void> _loadModelInfo() async {
    try {
      final version = await _inference.modelVersion();
      if (mounted) {
        setState(() {
          _modelVersion = version;
        });
      }
    } catch (_) {
      // Экспорт и просмотр записей доступны даже при недоступной модели.
    }
  }

  Future<void> _assessRecord(DrawingRecord record) async {
    if (_working) return;
    setState(() {
      _working = true;
      _assessingId = record.id;
    });
    try {
      final assessment = await _inference.assess(record);
      await _repository.saveAssessment(record, assessment);
      if (!mounted) return;
      setState(() {
        _modelVersion = assessment.modelVersion;
      });
      await _loadRecords();
    } catch (error) {
      if (mounted) {
        _showMessage('Не удалось оценить рисунок: $error', success: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _assessingId = null;
        });
      }
    }
  }

  Future<void> _loadRecords() async {
    final records = await _repository.listRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _shareCsv() async {
    setState(() {
      _working = true;
    });
    try {
      final file = await _repository.exportCsv(modelVersion: _modelVersion);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Cognitodraw CSV'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _saveCsv() async {
    setState(() {
      _working = true;
    });
    try {
      final file = await _repository.exportCsv(modelVersion: _modelVersion);
      final result = await _fileSaver.saveBytes(
        bytes: await file.readAsBytes(),
        fileName: file.uri.pathSegments.last,
        mimeType: 'text/csv',
        subDir: 'Cognitodraw',
      );
      if (!mounted) return;
      _showMessage(
        result?.isSuccess == true
            ? 'CSV сохранён в Downloads/Cognitodraw'
            : 'Не удалось сохранить CSV',
        success: result?.isSuccess == true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _shareGifZip() async {
    setState(() {
      _working = true;
    });
    try {
      final zip = await _createGifZip();
      if (zip == null) return;

      await SharePlus.instance.share(
        ShareParams(files: [XFile(zip.path)], text: 'Cognitodraw GIF ZIP'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _saveGifZip() async {
    setState(() {
      _working = true;
    });
    try {
      final zip = await _createGifZip();
      if (zip == null) return;

      final result = await _fileSaver.saveBytes(
        bytes: await zip.readAsBytes(),
        fileName: zip.uri.pathSegments.last,
        mimeType: 'application/zip',
        subDir: 'Cognitodraw',
      );
      if (!mounted) return;
      _showMessage(
        result?.isSuccess == true
            ? 'ZIP сохранён в Downloads/Cognitodraw'
            : 'Не удалось сохранить ZIP',
        success: result?.isSuccess == true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<File?> _createGifZip() async {
    final zip = await _repository.exportGifZip();
    if (!mounted) return null;
    if (zip == null) {
      _showMessage('Нет GIF-файлов для экспорта', success: false);
      return null;
    }
    return zip;
  }

  Future<void> _shareGif(DrawingRecord record) async {
    final file = File(record.gifPath);
    if (!await file.exists()) {
      if (!mounted) return;
      _showMessage('GIF-файл не найден', success: false);
      return;
    }

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: record.fileName),
    );
  }

  Future<void> _editRecord(DrawingRecord record) async {
    final edited = await showDialog<DrawingRecord>(
      context: context,
      builder: (context) => _RecordEditDialog(record: record),
    );

    if (edited == null) {
      return;
    }

    await _repository.updateRecord(edited);
    await _loadRecords();
    if (!mounted) return;
    _showMessage('Запись обновлена', success: true);
  }

  Future<void> _deleteRecord(DrawingRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Удалить запись?'),
            content: const Text(
              'Запись будет удалена из локальной базы данных вместе с GIF-файлом.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteRecord(record);
      await _loadRecords();
      if (!mounted) return;
      _showMessage('Запись удалена', success: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Не удалось удалить запись', success: false);
    }
  }

  void _showMessage(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(child: Text(message)),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = TextStyle(
      fontSize: 22,
      color: theme.colorScheme.onSurface,
      height: 1.4,
    );

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _ExportGroup(
                label: 'Рисунки (GIF и PNG)',
                children: [
                  FilledButton.icon(
                    onPressed: _working ? null : _shareGifZip,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Отправить ZIP'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _working ? null : _saveGifZip,
                    icon: const Icon(Icons.download),
                    label: const Text('Сохранить ZIP'),
                  ),
                ],
              ),
              _ExportGroup(
                label: 'CSV',
                children: [
                  FilledButton.icon(
                    onPressed: _working ? null : _shareCsv,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Отправить CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _working ? null : _saveCsv,
                    icon: const Icon(Icons.download),
                    label: const Text('Сохранить CSV'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _records.isEmpty
                  ? Center(
                    child: Text(
                      'Локальная база данных пуста',
                      style: titleStyle,
                      textAlign: TextAlign.center,
                    ),
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return _RecordTile(
                        record: record,
                        onEdit: _working ? null : () => _editRecord(record),
                        onDelete: _working ? null : () => _deleteRecord(record),
                        onShareGif: _working ? null : () => _shareGif(record),
                        onAssess: _working ? null : () => _assessRecord(record),
                        assessing: _working && _assessingId == record.id,
                        modelVersion: _modelVersion,
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class _ExportGroup extends StatelessWidget {
  const _ExportGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: children),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    required this.onEdit,
    required this.onDelete,
    required this.onShareGif,
    required this.onAssess,
    required this.assessing,
    required this.modelVersion,
  });

  final DrawingRecord record;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShareGif;
  final VoidCallback? onAssess;
  final bool assessing;
  final String? modelVersion;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(
          record.fullName.isEmpty ? 'Без имени' : record.fullName,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_taskLabel(record.taskType)} - ${record.createdAt}'),
              Text('Файл: ${record.fileName}'),
              Text(
                'Время: ${record.timeToComplete ?? '-'} сек, повторы: ${record.repeatTaps ?? '-'}',
              ),
              if (record.comment.isNotEmpty)
                Text('Комментарий: ${record.comment}'),
              if (record.assessment != null) ...[
                Text(
                  record.assessment!.label == 1
                      ? 'Модель указала на возможные нарушения'
                      : 'Модель не указала на нарушения',
                ),
                Text(
                  'Оценка модели: ${record.assessment!.score.toStringAsFixed(3)}',
                ),
                if (modelVersion == null)
                  const Text('Версия модели ещё не проверена')
                else if (record.assessment!.modelVersion != modelVersion)
                  const Text('Результат устарел. Повторите оценку.'),
                const Text(
                  'Экспериментальная оценка, не диагноз. Оценка не является вероятностью заболевания.',
                ),
                if (record.taskType == 'clock')
                  const Text('У модели часов ограниченная точность.'),
              ],
              TextButton.icon(
                onPressed: onAssess,
                icon:
                    assessing
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(),
                        )
                        : const Icon(Icons.psychology_outlined),
                label: Text(assessing ? 'Идёт оценка…' : 'Оценить рисунок'),
              ),
              Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Отправить GIF',
                    onPressed: onShareGif,
                    icon: const Icon(Icons.ios_share),
                  ),
                  IconButton(
                    tooltip: 'Редактировать',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    tooltip: 'Удалить',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordEditDialog extends StatefulWidget {
  const _RecordEditDialog({required this.record});

  final DrawingRecord record;

  @override
  State<_RecordEditDialog> createState() => _RecordEditDialogState();
}

class _RecordEditDialogState extends State<_RecordEditDialog> {
  late final TextEditingController fullNameController;
  late final TextEditingController ageController;
  late final TextEditingController sexController;
  late final TextEditingController complaintController;
  late final TextEditingController taskTypeController;
  late final TextEditingController sessionIdController;
  late final TextEditingController attemptIdController;
  late final TextEditingController fileNameController;
  late final TextEditingController gifPathController;
  late final TextEditingController timeController;
  late final TextEditingController repeatController;
  late final TextEditingController commentController;
  late final TextEditingController createdAtController;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    fullNameController = TextEditingController(text: record.fullName);
    ageController = TextEditingController(text: record.age?.toString() ?? '');
    sexController = TextEditingController(text: record.sex ?? '');
    complaintController = TextEditingController(text: record.complaint);
    taskTypeController = TextEditingController(text: record.taskType);
    sessionIdController = TextEditingController(text: record.sessionId);
    attemptIdController = TextEditingController(text: record.attemptId);
    fileNameController = TextEditingController(text: record.fileName);
    gifPathController = TextEditingController(text: record.gifPath);
    timeController = TextEditingController(
      text: record.timeToComplete?.toString() ?? '',
    );
    repeatController = TextEditingController(
      text: record.repeatTaps?.toString() ?? '',
    );
    commentController = TextEditingController(text: record.comment);
    createdAtController = TextEditingController(text: record.createdAt);
  }

  @override
  void dispose() {
    fullNameController.dispose();
    ageController.dispose();
    sexController.dispose();
    complaintController.dispose();
    taskTypeController.dispose();
    sessionIdController.dispose();
    attemptIdController.dispose();
    fileNameController.dispose();
    gifPathController.dispose();
    timeController.dispose();
    repeatController.dispose();
    commentController.dispose();
    createdAtController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      widget.record.copyWith(
        fullName: fullNameController.text.trim(),
        age: _parseInt(ageController.text),
        sex:
            sexController.text.trim().isEmpty
                ? null
                : sexController.text.trim(),
        complaint: complaintController.text.trim(),
        taskType: taskTypeController.text.trim(),
        sessionId: sessionIdController.text.trim(),
        attemptId: attemptIdController.text.trim(),
        fileName: fileNameController.text.trim(),
        gifPath: gifPathController.text.trim(),
        timeToComplete: _parseInt(timeController.text),
        repeatTaps: _parseInt(repeatController.text),
        comment: commentController.text.trim(),
        createdAt: createdAtController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Редактировать запись'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(fullNameController, 'ФИО'),
              _field(ageController, 'Возраст', number: true),
              _field(sexController, 'Пол'),
              _field(complaintController, 'Жалобы'),
              _field(taskTypeController, 'Задание'),
              _field(sessionIdController, 'ID сессии'),
              _field(attemptIdController, 'ID попытки'),
              _field(fileNameController, 'Имя GIF-файла'),
              _field(gifPathController, 'Путь к GIF'),
              _field(timeController, 'Время выполнения', number: true),
              _field(repeatController, 'Повторы', number: true),
              _field(commentController, 'Комментарий'),
              _field(createdAtController, 'Дата создания'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }

  int? _parseInt(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : int.tryParse(trimmed);
  }
}

String _taskLabel(String taskType) {
  switch (taskType) {
    case 'clock':
      return 'Часы';
    case 'cube':
      return 'Куб';
    default:
      return taskType;
  }
}
