# Cognitodraw

Cognitodraw is a Flutter application for collecting drawing-task data for cognitive impairment screening workflows. It is currently optimized for a controlled Android/tablet pilot where one device can be used by multiple participants.

The app collects participant metadata, presents Russian clock and cube drawing tasks, records the drawing interaction as a GIF, and uploads the GIF plus metadata to Supabase. If upload fails, the app attempts to keep the exported GIF locally for manual upload.

## Current Features

- Participant metadata form: full name, age, sex, and optional complaints.
- Explicit new-participant session reset for shared-device use.
- Two drawing tasks:
  - Clock drawing task.
  - Cube copying task with a reference image.
- Russian task instructions and audio descriptions.
- Canvas reset tracking through the `repeatTaps` metadata field.
- Time-to-complete tracking for each drawing task.
- GIF export of the recorded drawing session.
- Supabase upload for GIF files and participant metadata.
- Local fallback for failed uploads, with manual upload from the home screen.
- Pending local GIFs are kept across new participant sessions unless the operator explicitly deletes them.

## Tech Stack

- Flutter / Dart, SDK constraint `^3.7.0`.
- Material UI with a generated light color scheme.
- `screen_recorder` for GIF capture.
- `audioplayers` for task audio prompts.
- `shared_preferences` for temporary participant/session metadata.
- `path_provider` for pending GIF storage access.
- `supabase_flutter` for metadata and file upload.

## Project Layout

```text
lib/
  main.dart                  App bootstrap, Supabase initialization, routes, bottom navigation.
  features/
    home.dart                User guide, new-session reset, participant form, manual upload UI.
    draw.dart                Task menu, drawing screens, recording/export flow.
    settings.dart            Placeholder settings screen.
  utils/
    utils.dart               Storage keys, metadata model, Supabase upload, pending files, drawing painter, dialogs, audio button.
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

## Supabase Setup

The app loads Supabase configuration from a root `.env` file. This file is ignored by git and must exist before running the app:

```env
SUPABASE_URL=your-project-url
SUPABASE_ANON_KEY=your-anon-key
```

The upload code expects:

- A storage bucket named `gif_storage`.
- A table named `user_meta`.

The `user_meta` upsert payload includes:

```text
fullName
age
sex
filename
timeToComplete
repeatTaps
complaint
comment
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
3. Confirm `.env` points at the intended Supabase project.
4. Confirm the `gif_storage` bucket and `user_meta` table exist.
5. Confirm the tablet has network access.

For each participant:

1. On the home screen, press `НАЧАТЬ НОВУЮ СЕССИЮ`.
2. If the app reports pending local GIF files, upload them first or explicitly choose whether to keep/delete them.
3. Enter participant metadata and press `ПОДТВЕРДИТЬ`.
4. Open the drawing tab and choose `Часы` or `Куб`.
5. Press `Начать`, complete the task, then press `Завершить`.
6. Confirm the app reports successful upload or local fallback.
7. Before handing the tablet to the next participant, return to step 1.

Manual upload procedure:

1. Open the home screen.
2. Use `Загрузить данные вручную`.
3. If upload succeeds, the local pending GIF files are deleted.
4. If upload fails, keep the files and retry when network/server access is restored.

## Data Flow

1. On startup, the app loads `.env` and initializes Supabase. It does not clear participant data automatically.
2. The operator starts a new participant session from the home screen.
3. The app clears participant metadata and task state. Pending GIF files are preserved unless the operator chooses deletion.
4. The participant metadata form must be confirmed before drawing can start.
5. Pressing `Начать` starts the timer and screen recorder.
6. Pressing `Начать заново` clears the canvas and increments `repeatTaps`.
7. Pressing `Завершить` stops recording, exports a GIF, and attempts upload.
8. If upload succeeds, metadata is written to `user_meta` and the GIF is stored in `gif_storage`.
9. If upload fails, the GIF is saved locally when the platform provides a downloads directory.

## Notes for Development

- Most user-facing text is Russian and lives in `lib/constants/text_constants.dart`.
- Local participant data uses centralized keys in `StorageKeys`.
- The old misspelled complaint key `comlpaint` is read once and migrated to `complaint`.
- Android release builds still use debug signing for the controlled pilot; replace signing before production distribution.
- `flutter analyze` and `flutter test` should pass before installing a pilot build.
