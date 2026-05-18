import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/utils.dart';
import '../constants/text_constants.dart';

import 'dart:io';
import 'dart:typed_data';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
    return ListView.builder(
      padding: EdgeInsets.all(16.0),
      itemCount:
          homePageCards.length +
          3, // +1 for user guide, +1 for user input card, +1 for upload card
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            children: [
              Card(
                margin: EdgeInsets.all(8),
                child: ListTile(
                  title: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Руководство пользователя',
                      style: titleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      homeUserGuide,
                      style: descriptionStyle,
                      textAlign: TextAlign.start,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
            ],
          );
        }
        if (index == 1) {
          return Column(
            children: [
              InputCard(
                titleStyle: titleStyle,
                descriptionStyle: descriptionStyle,
              ),
              SizedBox(height: 10),
            ],
          );
        }
        if (index == 2) {
          return Column(
            children: [
              UploadCard(titleStyle: titleStyle),
              SizedBox(height: 10),
            ],
          );
        }
        final card =
            homePageCards[index -
                3]; // -3 to offset for user guide card, input card and upload card
        return Column(
          children: [
            Card(
              margin: EdgeInsets.all(8),
              child: ListTile(
                title: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    card.title,
                    style: titleStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    card.description,
                    style: descriptionStyle,
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
          ],
        );
      },
    );
  }
}

class UploadCard extends StatefulWidget {
  final TextStyle titleStyle;
  const UploadCard({super.key, required this.titleStyle});

  @override
  State<UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<UploadCard> {
  List<String> paths = [];
  bool _uploaded = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    final result = await StorageUtils.checkDownloadsDir();
    setState(() {
      paths = result;
    });
  }

  void _showUploadStatus() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(
          child: Text(
            _uploaded
                ? 'Файлы успешно сохранён'
                : 'Ошибка соединения с сервером',
          ),
        ),
        backgroundColor: _uploaded ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: ListTile(
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Загрузить данные вручную',
            style: widget.titleStyle,
            textAlign: TextAlign.center,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_uploading)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: CircularProgressIndicator(),
                    ),
                    Text(
                      'Идёт процесс сохранения. Не закрывайте приложение и не покидайте страницу!',
                      textAlign: TextAlign.justify,
                    ),
                  ],
                )
              else ...[
                ElevatedButton(
                  onPressed:
                      paths.isEmpty
                          ? null
                          : () async {
                            if (!mounted) return;

                            setState(() {
                              _uploading = true;
                              _uploaded = false; // reset
                            });

                            bool allSuccess = true;

                            for (var path in paths) {
                              final fileName = path.split('/').last;
                              final file = File(path);
                              Uint8List gif = await file.readAsBytes();

                              // await upload and catch errors
                              try {
                                final success = await StorageUtils.uploadGif(
                                  gif,
                                  fileName,
                                );
                                if (success) {
                                  await file.delete();
                                } else {
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
                            _loadPaths();
                            _showUploadStatus();
                          },
                  child: Text('Загрузить'),
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
  });

  final TextStyle titleStyle;
  final TextStyle descriptionStyle;

  @override
  State<InputCard> createState() => _InputCardState();
}

enum SexChoice { male, female, none }

class _InputCardState extends State<InputCard> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController sexController = TextEditingController();
  final TextEditingController comController = TextEditingController();

  final String _storageKeyName = "fullName";
  final String _storageKeyAge = "age";
  final String _storageKeySex = "sex";
  final String _storageKeyCom = "comlpaint";

  String fullName = 'NO_NAME';
  int? age;
  String? sex;

  SexChoice sexChoiceView = SexChoice.none;

  String? complaint;

  @override
  void initState() {
    super.initState();

    StorageUtils.loadString(_storageKeyName).then((value) {
      if (value != null) {
        setState(() {
          fullName = value;
        });
      }
    });
    StorageUtils.loadString(_storageKeySex).then((value) {
      if (value != null) {
        setState(() {
          sex = value;
          sexChoiceView = SexChoice.values.firstWhere((e) => e.name == sex);
        });
      }
    });
    StorageUtils.loadInt(_storageKeyAge).then((value) {
      if (value != null) {
        setState(() {
          age = value;
        });
      }
    });
    StorageUtils.loadString(_storageKeyCom).then((value) {
      if (value != null) {
        setState(() {
          complaint = value;
        });
      }
    });
  }

  void submitForm() async {
    // Get values from all controllers
    String nameValue = nameController.text;
    String ageValue = ageController.text;
    String comValue = comController.text;

    // Your submission logic here (API call, validation, etc.)
    if (nameValue.isNotEmpty && ageValue.isNotEmpty) {
      // All fields have data, proceed with submission
      setState(() {
        fullName = nameValue;
        age = int.tryParse(ageValue);
        complaint = comValue;
      });
      await StorageUtils.saveString(_storageKeyName, nameValue);
      await StorageUtils.saveInt(_storageKeyAge, age!);
      await StorageUtils.saveString(_storageKeyCom, comValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text('Данные успешно подтверждены')),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text('Пожалуйста, введите все данные')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: ListTile(
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Введите свои данные',
            style: widget.titleStyle,
            textAlign: TextAlign.center,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName == "NO_NAME" ? 'Имя:' : 'Ваше имя - $fullName',
                style: widget.descriptionStyle,
              ),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Введите ФИО здесь',
                ),
                onSubmitted: (value) async {
                  setState(() {
                    fullName = value;
                  });
                  await StorageUtils.saveString(_storageKeyName, value);
                },
              ),
              SizedBox(height: 5),
              Text(
                age == null ? 'Возраст:' : 'Ваш возраст - $age',
                style: widget.descriptionStyle,
              ),
              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Введите свой возраст здесь',
                ),
                onSubmitted: (value) async {
                  setState(() {
                    age = int.tryParse(value);
                  });
                  await StorageUtils.saveInt(_storageKeyAge, age!);
                },
              ),
              SizedBox(height: 5),
              Text('Пол:', style: widget.descriptionStyle),
              Center(
                child: SegmentedButton<SexChoice>(
                  segments: <ButtonSegment<SexChoice>>[
                    ButtonSegment<SexChoice>(
                      value: SexChoice.male,
                      label: Text('Мужчина'),
                    ),
                    ButtonSegment<SexChoice>(
                      value: SexChoice.female,
                      label: Text('Женщина'),
                    ),
                  ],
                  selected: <SexChoice>{sexChoiceView},
                  onSelectionChanged: (Set<SexChoice> newSelection) async {
                    setState(() {
                      sexChoiceView = newSelection.first;
                    });
                    await StorageUtils.saveString(
                      _storageKeySex,
                      sexChoiceView.name,
                    );
                  },
                ),
              ),
              SizedBox(height: 5),
              Text('Жалобы (если имеются):', style: widget.descriptionStyle),
              TextField(
                controller: comController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Укажите жалобы, если имеются',
                ),
                onSubmitted: (value) async {
                  setState(() {
                    complaint = value;
                  });
                  await StorageUtils.saveString(_storageKeyCom, value);
                },
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: submitForm,
                  child: Text('ПОДТВЕРДИТЬ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final List<PageCards> homePageCards = [];
