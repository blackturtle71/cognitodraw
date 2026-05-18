# Cognitodraw

Cognitodraw is a Flutter application for collecting drawing-task data that can be used in cognitive impairment screening workflows. The app asks a participant for basic metadata, presents clock and cube drawing tasks in Russian, records the drawing interaction as a GIF, and uploads the result plus metadata to Supabase.

## Current Features

- Participant metadata form: full name, age, sex, and optional complaints.
- Two drawing tasks:
  - Clock drawing task.
  - Cube copying task with a reference image.
- Russian task instructions and audio descriptions.
- Canvas reset tracking through the `repeatTaps` metadata field.
- Time-to-complete tracking for each drawing task.
- GIF export of the recorded drawing session.
- Supabase upload for GIF files and participant metadata.
- Local fallback: if upload fails, exported GIFs are saved to the user's downloads directory and can be uploaded later from the home screen.

## Tech Stack

- Flutter / Dart, SDK constraint `^3.7.0`.
- Material UI with a generated light color scheme.
- `screen_recorder` for GIF capture.
- `audioplayers` for task audio prompts.
- `shared_preferences` for temporary local metadata.
- `path_provider` for downloads-directory access.
- `supabase_flutter` for metadata and file upload.

## Project Layout

```text
lib/
  main.dart                  App bootstrap, Supabase initialization, routes, bottom navigation.
  features/
    home.dart                User guide, participant form, manual upload UI.
    draw.dart                Task menu, drawing screens, recording/export flow.
    settings.dart            Placeholder settings screen.
  utils/
    utils.dart               Shared preferences, Supabase upload, drawing painter, dialogs, audio button.
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

Platform folders are present for Android, iOS, Linux, macOS, Windows, and web.

## Supabase Setup

The app loads Supabase configuration from a root `.env` file. This file is ignored by git and must exist before running the app:

```env
SUPABASE_URL=your-project-url
SUPABASE_ANON_KEY=your-anon-key
```

The current upload code expects:

- A storage bucket named `gif_storage`.
- A table named `user_meta`.

The `user_meta` upsert payload currently includes these fields:

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

## Data Flow

1. On startup, the app loads `.env`, initializes Supabase, clears saved participant metadata, and removes pending files from the downloads directory.
2. The participant fills out metadata on the home screen.
3. The participant chooses either the clock or cube task.
4. Pressing `Начать` starts the timer and screen recorder.
5. Pressing `Начать заново` clears the canvas and increments `repeatTaps`.
6. Pressing `Завершить` stops recording, exports a GIF, and attempts to upload it.
7. If upload succeeds, metadata is written to `user_meta` and the GIF is stored in `gif_storage`.
8. If upload fails, the GIF is saved locally in the downloads directory for manual upload.

## Notes for Development

- Most user-facing text is Russian and lives in `lib/constants/text_constants.dart`.
- The app currently clears shared preferences and pending download files on startup.
- The participant complaint key is currently spelled `comlpaint` in local storage and upload code; keep this in mind when reading existing data paths.
- `test/widget_test.dart` is still the default Flutter scaffold test and does not reflect the current UI.
