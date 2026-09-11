# Smaran Task 1 + Task 2 — Feature Architecture Integration

This package is rebuilt against the feature-based Flutter structure:

```text
lib/
├── core/
│   ├── domain/app_models.dart
│   ├── services/alarm_service.dart
│   └── theme/app_theme.dart
├── features/
│   ├── home/home_screen.dart
│   ├── reminders/reminder_screen.dart
│   └── splash/splash_screen.dart
└── main.dart
```

## Task 1
- `showTimePicker` is forced to 12-hour mode.
- Daily, Once, Specific Date.
- `showDatePicker` for Specific Date.
- Medicine, Food, Memory Activity, Specific Task.
- Medicine requires Before Food / After Food.
- Exact Android `AlarmManager` scheduling uses `oneShotAt` with `alarmClock`, `exact`, `allowWhileIdle`, `wakeup`, and reboot rescheduling.
- Full-screen `flutter_local_notifications` alarm notification.
- Alarm screen speaks the reminder using Flutter TTS, preferring the saved regional language.
- One-shot alarms are marked inactive after they fire.

## Task 2
- Home's four primary feature tiles use `Row + Expanded` so all four share equal width and stay in one row.
- Splash contains only one explicit Smaran S logo. The previous duplicate overlay widget was removed.

## Android changes
- Exact alarm, notification, full-screen, boot and wake-lock permissions.
- AlarmManager service/receivers.
- MainActivity uses `showWhenLocked` and `turnScreenOn`.
- `kotlin.incremental=false` is retained because the original project had cross-drive Kotlin incremental-cache failures.

## Important storage note
The uploaded source project still uses `SharedPreferences` for the existing app store. This task preserves that working store and adds all required alarm fields to it. A full Drift + encrypted SQLite/SQLCipher migration is intentionally not silently substituted here because it requires a database schema/code-generation migration and key-management layer. The existing `EncryptedStorageConfig` remains available for that next migration.

## Build
Run from the project root after extracting:

```powershell
flutter pub get
flutter run
```

If the normal Flutter launcher hangs on this machine, use the direct Flutter tool invocation already established for this project.
