# Cognitodraw

Cognitodraw is a Flutter application for collecting drawing-task data for cognitive impairment screening workflows. It is currently optimized for a controlled Android/tablet pilot where one device can be used by multiple participants.

The app collects participant metadata, presents Russian clock and cube drawing tasks, records the drawing interaction as a GIF, and stores both the GIF and metadata locally on the Android device for offline use.

## Current Features

- Participant metadata form: full name, age, sex, and optional complaints.
- Explicit new-participant session reset for shared-device use.
- Home-screen session status: participant metadata, session ID, task status, and saved record count.
- Two drawing tasks:
  - Clock drawing task.
  - Cube copying task with a reference image.
- Russian task instructions and audio descriptions.
- Canvas reset tracking through the `repeatTaps` metadata field.
- Time-to-complete tracking for each drawing task.
- GIF export of the recorded drawing session.
- Local SQLite database with one row per drawing attempt.
- App-managed GIF storage on the device.
- Data screen for viewing/editing records, sharing/saving CSV, and sharing/saving GIF ZIP archives.

## Tech Stack

- Flutter / Dart, SDK constraint `^3.7.0`.
- Material UI with a generated light color scheme.
- `screen_recorder` for GIF capture.
- `audioplayers` for task audio prompts.
- `shared_preferences` for temporary participant/session metadata.
- `path_provider` for local GIF, database, and export paths.
- `sqflite` for the local records database.
- `share_plus` for CSV/ZIP export through Android share UI.
- `public_file_saver` for saving CSV/ZIP files to public Downloads.

## Project Layout

```text
lib/
  main.dart                  App bootstrap, routes, bottom navigation.
  data/
    local_records_repository.dart
                               SQLite records, GIF storage, CSV export.
  features/
    home.dart                User guide, session status, new-session reset, participant form.
    draw.dart                Task menu, drawing screens, recording/export flow.
    records.dart             Local database viewer/editor and CSV/ZIP export UI.
    settings.dart            Placeholder settings screen.
  utils/
    utils.dart               Storage keys, metadata model, drawing painter, dialogs, audio button.
  constants/
    text_constants.dart      Russian UI/task copy.
    theme.dart               Material color schemes.

assets/
  audio/
    clock_task.mp3
    cube_task.mp3
  images/
    cube.png
    icon.png
```

Platform folders are present for Android, iOS, Linux, macOS, Windows, and web. The active pilot target is Android/tablet.

## Local Data

Records are stored in an on-device SQLite database named `cognitodraw.sqlite`.
GIF files are stored in the app documents directory under `gifs/`.

CSV export includes:

```text
id
fullName
age
sex
complaint
taskType
sessionId
attemptId
fileName
gifPath
timeToComplete
repeatTaps
comment
createdAt
updatedAt
```

## Getting Started

Install dependencies:

```sh
flutter pub get
```

Run the app:

```sh
flutter run
```

Run static analysis:

```sh
flutter analyze
```

Run tests:

```sh
flutter test
```

## Android Pilot Checklist

Before a pilot session:

1. Install a build on the target Android tablet.
2. Confirm the app is named `Cognitodraw` on the launcher.
3. Confirm the app opens without network access.
4. Open `Данные` and confirm the local database screen is available.

For each participant:

1. On the home screen, press `НАЧАТЬ НОВУЮ СЕССИЮ`.
2. Enter participant metadata and press `ПОДТВЕРДИТЬ`.
3. Check `Статус сессии` to confirm the participant and task state.
4. Open the drawing tab and choose `Часы` or `Куб`.
5. Press `Начать`, complete the task, then press `Завершить`.
6. Confirm the app reports successful local save.
7. Open `Данные` to view/edit records, export/save CSV, or export/save GIF ZIP archives.
8. Before handing the tablet to the next participant, return to step 1.

## Data Flow

1. On startup, the app initializes local UI state. It does not clear participant data automatically.
2. The operator starts a new participant session from the home screen.
3. The app clears current participant metadata and task state. Historical SQLite records are preserved.
4. The participant metadata form must be confirmed before drawing can start.
5. Pressing `Начать` starts the timer and screen recorder.
6. Pressing `Начать заново` clears the canvas and increments `repeatTaps`.
7. Pressing `Завершить` stops recording, exports a GIF, writes the GIF into app storage, and inserts a SQLite record.
8. The `Данные` tab lists saved records, allows full-field edits, and can share/save CSV plus GIF ZIP archives.

## Notes for Development

- Most user-facing text is Russian and lives in `lib/constants/text_constants.dart`.
- Local participant data uses centralized keys in `StorageKeys`.
- GIF filenames use `{userName}_{taskType}_{sessionId}_{attemptId}.gif`.
- Task status is stored per session for clock and cube tasks.
- The old misspelled complaint key `comlpaint` is read once and migrated to `complaint`.
- Android release builds still use debug signing for the controlled pilot; replace signing before production distribution.
- `flutter analyze` and `flutter test` should pass before installing a pilot build.

## Offline model assessments

The Android app bundles one DINOv2 ViT-S/14 encoder and separate clock/cube classifiers.
On `Данные`, press `Оценить рисунок` to run an assessment locally. The app displays the
binary assessment and an uncalibrated model score, saves the result, and includes it in
CSV export. No drawing or participant data is uploaded. ONNX Runtime telemetry is disabled.
The labels were learned from narrative drawing assessments, not confirmed diagnoses;
the result is experimental. The clock model has weaker measured performance.

New drawings use a canvas with the training proportions, independent of phone dimensions.
Completion saves a canonical 343×548 final PNG before clearing the canvas, alongside the
GIF. Failed saves retain their pending image and can be retried. Older GIF-only records
can be assessed only when their last composited frame matches the original 343×548 format.
The original training masks and Pillow-compatible resize are applied to both input types.

Database version 2 preserves existing attempts and adds final-image/capture metadata
plus a separate `model_assessments` table. Results include model/preprocessing versions,
input fingerprint, and assessment time. Editing model inputs clears the assessment;
editing names, comments, or complaints does not. A changed bundled model makes older
assessments outdated until manually rerun. CSV appends `modelLabel`, `modelScore`,
`modelVersion`, `modelPreprocessingVersion`, `modelInputFingerprint`, `modelAssessedAt`,
and `modelAssessmentStatus`, as well as `finalImageFileName` and `captureVersion`.
A model prediction never populates a human training `label`. Drawing ZIP exports now
include canonical PNGs alongside GIFs; individual GIF sharing is unchanged.

### Generate the bundled models

From the sibling `cognitodraw_model` project, follow its `Offline Android export`
instructions. Copy only the encoder, heads, manifest, and license into
`assets/models/dinov2/`. These generated files are gitignored but are packaged into the
APK by Flutter. Building a fresh checkout requires generating/copying the bundle first.
No Python runtime is needed on the Android device.

Build an ARM64 pilot APK without packaging unused native ABIs:

```sh
flutter pub get
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

The APK is `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. Pilot release
signing retains the existing debug-signing configuration. iOS/desktop inference is not
implemented; record collection and export remain separate from Android model inference.

### Verify conversion and native components

Run `flutter analyze` and `flutter test`. These cover assessment controls, error handling,
migration, invalidation, export, and identical canonical captures across viewport sizes.

The model exporter produces the private `validation` directory. To verify Flutter's
last-frame decoding against Pillow for all original GIFs, run:

```sh
COGNITODRAW_REFERENCE_DIR=/absolute/path/to/cognitodraw_model/artifacts/mobile/dinov2/validation flutter test
```

This private-reference test is explicitly skipped when the environment variable is absent.
To check every reference
with compiled Kotlin preprocessing and classifier heads, run from `android/` with a
supported Gradle JDK (Android Studio's bundled JDK works):

```sh
./gradlew :app:testDebugUnitTest \
  -PmobileReferenceDir=/absolute/path/to/cognitodraw_model/artifacts/mobile/dinov2/validation
```

Without `mobileReferenceDir`, the full private-reference test is explicitly skipped;
the boundary/error tests still run. Reference drawings are never committed or included
in the normal app APK. To check the actual Android ONNX engine on a connected emulator
or device, run:

```sh
./gradlew :app:connectedDebugAndroidTest \
  -PmobileReferenceDir=/absolute/path/to/cognitodraw_model/artifacts/mobile/dinov2/validation
```

The instrumentation test compares all reference pixels, labels, and scores, and logs
cold/warm assessment times and the maximum observed process PSS under `MobileParity`.
For an offline smoke test, disable device networking, create both drawing types, assess
saved records, restart the app, and verify persistence and CSV/ZIP export.
