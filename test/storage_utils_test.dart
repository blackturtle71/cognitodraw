import 'dart:io';

import 'package:cognitodraw/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('participant metadata reports incomplete required fields', () {
    const missingSex = ParticipantMetadata(
      fullName: 'Иван Иванов',
      age: 72,
      sex: null,
      complaint: '',
    );

    const valid = ParticipantMetadata(
      fullName: 'Иван Иванов',
      age: 72,
      sex: 'male',
      complaint: '',
    );

    expect(missingSex.isComplete, isFalse);
    expect(valid.isComplete, isTrue);
  });

  test('legacy complaint key is migrated to the current key', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.fullName: 'Иван Иванов',
      StorageKeys.age: 72,
      StorageKeys.sex: 'male',
      StorageKeys.legacyComplaint: 'головная боль',
    });

    final metadata = await ParticipantMetadata.load();
    final prefs = await SharedPreferences.getInstance();

    expect(metadata.complaint, 'головная боль');
    expect(prefs.getString(StorageKeys.complaint), 'головная боль');
    expect(prefs.getString(StorageKeys.legacyComplaint), isNull);
  });

  test(
    'clearing participant session preserves unrelated and pending-file preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.fullName: 'Иван Иванов',
        StorageKeys.age: 72,
        StorageKeys.sex: 'male',
        StorageKeys.repeatTaps: 2,
        'operatorPreference': 'keep',
        'pendingGifPath': '/tmp/pending.gif',
      });

      await StorageUtils.clearParticipantSession();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString(StorageKeys.fullName), isNull);
      expect(prefs.getInt(StorageKeys.age), isNull);
      expect(prefs.getString(StorageKeys.sex), isNull);
      expect(prefs.getInt(StorageKeys.repeatTaps), isNull);
      expect(prefs.getString('operatorPreference'), 'keep');
      expect(prefs.getString('pendingGifPath'), '/tmp/pending.gif');
    },
  );

  test(
    'pending GIF storage gracefully reports unsupported test platform',
    () async {
      final available = await StorageUtils.canUsePendingGifStorage();
      final saved = await StorageUtils.savePendingGif([1, 2, 3], 'test.gif');

      expect(available, isFalse);
      expect(saved, isFalse);
    },
    skip: !Platform.isLinux,
  );

  test('GIF filenames are transliterated and task scoped', () {
    const metadata = ParticipantMetadata(
      fullName: 'Иван Иванов',
      age: 72,
      sex: 'male',
      complaint: '',
    );

    final fileName = StorageUtils.buildGifFileName(
      metadata: metadata,
      taskType: 'clock',
      timestamp: DateTime.fromMicrosecondsSinceEpoch(123),
    );

    expect(fileName, endsWith('_clock_123.gif'));
    expect(fileName, isNot(contains(' ')));
  });
}
