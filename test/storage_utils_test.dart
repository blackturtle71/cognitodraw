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
    'clearing participant session preserves unrelated preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.fullName: 'Иван Иванов',
        StorageKeys.age: 72,
        StorageKeys.sex: 'male',
        StorageKeys.repeatTaps: 2,
        StorageKeys.sessionId: 's_existing',
        'operatorPreference': 'keep',
      });

      await StorageUtils.clearParticipantSession();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString(StorageKeys.fullName), isNull);
      expect(prefs.getInt(StorageKeys.age), isNull);
      expect(prefs.getString(StorageKeys.sex), isNull);
      expect(prefs.getInt(StorageKeys.repeatTaps), isNull);
      expect(prefs.getString(StorageKeys.sessionId), isNull);
      expect(prefs.getString('operatorPreference'), 'keep');
    },
  );

  test(
    'starting participant session clears old session and creates a new id',
    () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.fullName: 'Иван Иванов',
        StorageKeys.sessionId: 's_old',
      });

      final sessionId = await StorageUtils.startParticipantSession();
      final prefs = await SharedPreferences.getInstance();

      expect(sessionId, startsWith('s_'));
      expect(prefs.getString(StorageKeys.fullName), isNull);
      expect(prefs.getString(StorageKeys.sessionId), sessionId);
    },
  );

  test('GIF filenames include user name, task, session, and attempt id', () {
    const metadata = ParticipantMetadata(
      fullName: 'Иван Иванов',
      age: 72,
      sex: 'male',
      complaint: '',
    );

    final fileName = StorageUtils.buildGifFileName(
      metadata: metadata,
      taskType: 'clock',
      sessionId: 's_123',
      attemptId: 'a_456',
    );

    expect(fileName, 'Ivan_Ivanov_clock_s_123_a_456.gif');
    expect(fileName, isNot(contains(' ')));
  });

  test('attempt snapshot round trips local record metadata', () {
    const snapshot = DrawingAttemptSnapshot(
      metadata: ParticipantMetadata(
        fullName: 'Иван Иванов',
        age: 72,
        sex: 'male',
        complaint: 'нет',
      ),
      taskType: 'clock',
      sessionId: 's_123',
      attemptId: 'a_456',
      fileName: 'Ivan_Ivanov_clock_s_123_a_456.gif',
      timeToComplete: 10,
      repeatTaps: 1,
      createdAt: '2026-05-18T12:00:00.000Z',
    );

    final restored = DrawingAttemptSnapshot.fromJson(snapshot.toJson());

    expect(restored.fileName, snapshot.fileName);
    expect(restored.sessionId, snapshot.sessionId);
    expect(restored.attemptId, snapshot.attemptId);
    expect(restored.metadata.fullName, 'Иван Иванов');
    expect(restored.timeToComplete, 10);
  });

  test('task statuses default and persist per task', () async {
    expect(await StorageUtils.loadTaskStatus('clock'), 'notStarted');

    await StorageUtils.saveTaskStatus('clock', 'saved');
    await StorageUtils.saveTaskStatus('cube', 'failed');

    final statuses = await StorageUtils.loadTaskStatuses();

    expect(statuses['clock'], 'saved');
    expect(statuses['cube'], 'failed');
  });
}
