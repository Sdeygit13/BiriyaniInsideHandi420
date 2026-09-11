# Smaran Flutter — Step 2: Reminder & Alarm System

Implemented in this package:

- Flutter Local Notifications integration
- High-priority Smaran reminder notification channel
- Exact Android alarm scheduling while idle
- Daily recurring reminder scheduling from the user's saved time
- Notification permission request
- Exact-alarm permission request
- Full-screen intent permission request
- Lock-screen / wake-screen activity flags
- Full-screen alarm presentation using an in-app AlarmScreen
- Voice reminder using Flutter TTS when the alarm screen opens
- Notification payload containing reminder title/detail/time
- Notification tap/full-screen launch recovery when the app was not running
- Reminder IDs persisted for stable notification cancellation
- Reminder cancellation when a task is completed or deleted
- Reminder rescheduling
- Existing reminder data remains compatible with older saved records
- "Enable alerts" button
- "Test alarm now" button on the Daily Routine screen
- Existing Smaran UI/navigation retained

## Important

The Android OS may require the user to approve notification, exact-alarm, and full-screen permissions. Smaran requests those permissions from the app. Android/OEM battery restrictions can also affect background delivery; the next hardening pass should add OEM battery-optimization guidance and WorkManager-based missed-task processing.

## Run

Use the known-working direct Flutter tool if the normal `flutter` launcher still hangs:

```powershell
cd D:\FlutterDev\projects\smaran_flutter
Remove-Item -Recurse -Force .\build -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .\.dart_tool -ErrorAction SilentlyContinue
& "D:\FlutterDev\sdk\flutter\bin\cache\dart-sdk\bin\dart.exe" "D:\FlutterDev\sdk\flutter\bin\cache\flutter_tools.snapshot" pub get
& "D:\FlutterDev\sdk\flutter\bin\cache\dart-sdk\bin\dart.exe" "D:\FlutterDev\sdk\flutter\bin\cache\flutter_tools.snapshot" run -d 55ca701
```

Test:

1. Open Daily Routine.
2. Tap Enable alerts and allow Android permissions.
3. Tap Test alarm now.
4. Lock the phone and create a reminder one or two minutes ahead.
5. Confirm notification, screen wake/full-screen behavior and spoken reminder.
6. Complete/delete the reminder and verify its scheduled notification is cancelled.
