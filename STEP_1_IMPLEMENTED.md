# Smaran Flutter — Step 1 implementation

This step restores the dashboard behavior and strengthens the existing Flutter conversion without adding new third-party dependencies.

## Implemented

- Concept-style compact, single-viewport Home dashboard.
- No vertical scrolling on the Home dashboard.
- Header with patient name, greeting, date and notification badge.
- Integrated Smaran assistant bar with voice and camera actions.
- Compact 2x2 feature grid:
  - Your Daily Task -> Cognitive Games
  - Memory Garden -> Memory Garden
  - Take a Trip Down Your Memory Lane -> Memory Garden / memories
  - Scheduled -> Daily Routine
- Today's Plan section using persisted reminders.
- Reminder completion updates the dashboard immediately.
- Persistent daily game completion count (0/5) and game history.
- Five cognitive activity entries instead of four.
- Talking Help now uses patient context for reminders, family and game questions and speaks responses with Flutter TTS.
- Memory Garden persists selected photos.
- Family Circle persists trusted people.
- Profile changes persist and return to Home.
- Shell is reactive through ChangeNotifier, so Home data refreshes without restarting the app.
- Existing splash, dhak audio, biometric flow, onboarding, music and relax behavior retained.

## Deliberately not claimed as complete in Step 1

- Android scheduled notifications / WorkManager.
- Lock-screen/full-screen alarm.
- Real offline ASR/IndicConformer.
- Real IndicTrans2 translation.
- Qwen/llama.cpp inference.
- IndicTTS2.
- Flame games.
- MediaPipe/ArcFace.
- SQLCipher + Drift encrypted database.
- REST sync engine.

Those are the next implementation stages and require native/plugin/model integration rather than UI-only changes.

## Install

Copy the contents of this package over the existing Flutter project, or at minimum replace `lib/main.dart` with the included file.

Then run a clean build. The existing `pubspec.yaml` is unchanged in this step, so no new package installation is required.
