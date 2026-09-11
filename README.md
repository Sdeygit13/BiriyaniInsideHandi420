# Smaran Flutter Conversion

This package is the first real Flutter conversion of the supplied Smaran React Native project.

## What is included
- Smaran Durga Puja splash artwork
- 5-second splash timer
- Dhak beat audio
- Login + demo credentials
- Signup/profile setup
- Biometric authentication with development fallback
- Onboarding
- Home dashboard
- Daily reminders with local persistence
- Cognitive games
- Memory Garden with gallery image picker
- Family Circle with local persistence
- Smaran talking-help interface + TTS
- Music screen
- Relax screen
- Profile/settings
- Bottom navigation
- SharedPreferences local persistence

## Install into the existing Flutter project
Your existing project is already created at:
`D:\FlutterDev\projects\smaran_flutter`

Copy these folders/files into that project, replacing the existing `lib` and adding `assets`:
- `lib/`
- `assets/`
- `pubspec.yaml`

Then run:

```powershell
flutter pub get
flutter clean
flutter run
```

The React Native source project is intentionally not modified.

## Demo login
Email: `caregiver@smaran.app`
Password: `Smaran123`

## Next conversion layer
The first offline core contracts now live under `lib/core/`:

- `domain/smaran_models.dart` defines patient, game, interaction, reminder, face, and sync records.
- `ai/offline_ai_pipeline.dart` defines the regional ASR -> translation -> local LLM -> translation -> TTS sequence with a deterministic offline fallback.
- `games/difficulty_optimizer.dart` adapts difficulty from recent accuracy and error metrics.
- `sync/sync_queue.dart` keeps data local until an explicitly online transport flushes it.
- `storage/encrypted_storage_config.dart` defines the SQLCipher/key-alias boundary for the native database adapter.

The native adapters remain deliberately separate: Drift/SQLCipher, WorkManager, ONNX Runtime, llama.cpp, MediaPipe, and InsightFace require platform-specific bindings and model artifacts. They should implement these interfaces rather than putting network or model code into the patient-facing widgets. The current UI continues to use its existing local persistence and development fallbacks while those adapters are added incrementally.
