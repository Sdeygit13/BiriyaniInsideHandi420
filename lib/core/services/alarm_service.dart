import 'dart:convert';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_models.dart';
import '../theme/app_theme.dart';

final GlobalKey<NavigatorState> smaranNavigatorKey =
    GlobalKey<NavigatorState>();

const String _alarmChannelId = 'smaran_native_alarm';
const String _alarmChannelName = 'Smaran Alarms';
const String _alarmChannelDescription =
    'Exact reminders and alarm notifications for Smaran.';

/* ============================================================================
 * ANDROID ALARM CALLBACK
 *
 * IMPORTANT:
 * This MUST be a TOP-LEVEL function.
 *
 * android_alarm_manager_plus executes this function from a background
 * isolate. Do NOT move this function inside AlarmService.
 * ========================================================================== */

@pragma('vm:entry-point')
Future<void> smaranAlarmCallback(
  int id,
  Map<String, dynamic> params,
) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    /*
     * Initialize the alarm manager inside the background isolate as well.
     */
    await AndroidAlarmManager.initialize();

    final plugin = FlutterLocalNotificationsPlugin();

    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        ),
      ),
    );

    /*
     * Make sure the notification channel exists when the callback is
     * running in the background isolate.
     */
    final android = plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _alarmChannelId,
        _alarmChannelName,
        description: _alarmChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    await _showAlarmNotificationWithPlugin(
      plugin,
      params,
    );

    /*
     * Daily reminder:
     * schedule tomorrow's occurrence.
     */
    if (params['repeatType']?.toString() ==
        RepeatType.daily.name) {
      final next = _nextDailyFromParams(params);

      if (next != null) {
        await AndroidAlarmManager.oneShotAt(
          next,
          id,
          smaranAlarmCallback,
          alarmClock: true,
          allowWhileIdle: true,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
          params: params,
        );
      }
    } else {
      /*
       * One-time reminder:
       * deactivate it so it does not get scheduled again.
       */
      await _markOneShotInactive(id);
    }
  } catch (_) {
    /*
     * Background isolates must not throw uncaught exceptions.
     */
  }
}

/* ============================================================================
 * ALARM SERVICE
 * ========================================================================== */

class AlarmService {
  AlarmService._();

  static final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  static Map<String, dynamic>? _pendingAlarm;

  static bool _initialized = false;

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  static Future<void> initialize() async {
    if (_initialized) return;

    _initialized = true;

    await AndroidAlarmManager.initialize();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      ),
    );

    await notifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse:
          _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          notificationTapBackground,
    );

    final android = notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _alarmChannelId,
        _alarmChannelName,
        description: _alarmChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    final launchDetails =
        await notifications.getNotificationAppLaunchDetails();

    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload =
          launchDetails?.notificationResponse?.payload;

      if (payload != null && payload.isNotEmpty) {
        _pendingAlarm = _decodePayload(payload);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PERMISSIONS
  // ---------------------------------------------------------------------------

  static Future<void> requestPermissions() async {
    final android = notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();

    await android?.requestExactAlarmsPermission();

    await android?.requestFullScreenIntentPermission();
  }

  // ---------------------------------------------------------------------------
  // SCHEDULE
  // ---------------------------------------------------------------------------

  static Future<void> schedule(
    AlarmReminder reminder,
  ) async {
    if (!reminder.isActive) return;

    await cancel(reminder.id);

    final target = reminder.nextSystemDateTime;

    if (!target.isAfter(DateTime.now())) {
      return;
    }

    reminder.systemTimeStamp =
        DateTime.now().millisecondsSinceEpoch;

    final prefs =
        await SharedPreferences.getInstance();

    final language =
        prefs.getString('language') ?? 'English';

    final params = <String, dynamic>{
      'id': reminder.id,
      'title': reminder.title,
      'detail': reminder.detail,
      'hour': reminder.hour,
      'minute': reminder.minute,
      'amPm': reminder.amPm,
      'repeatType': reminder.repeatType.name,
      'specificDate':
          reminder.specificDate?.millisecondsSinceEpoch,
      'alarmType': reminder.alarmType.name,
      'medicineTiming':
          reminder.medicineTiming?.name,
      'language': language,
      'smaran_alarm_launch': true,
    };

    await AndroidAlarmManager.oneShotAt(
      target,
      reminder.id,
      smaranAlarmCallback,
      alarmClock: true,
      allowWhileIdle: true,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: params,
    );
  }

  // ---------------------------------------------------------------------------
  // CANCEL
  // ---------------------------------------------------------------------------

  static Future<void> cancel(int id) async {
    await AndroidAlarmManager.cancel(id);

    await notifications.cancel(
      id: id,
    );
  }

  // ---------------------------------------------------------------------------
  // RESCHEDULE ALL
  // ---------------------------------------------------------------------------

  static Future<void> rescheduleAll(
    Iterable<AlarmReminder> reminders,
  ) async {
    for (final reminder in reminders) {
      if (reminder.isActive && !reminder.done) {
        try {
          await schedule(reminder);
        } catch (_) {
          /*
           * Keep the saved reminder even if Android temporarily
           * refuses to schedule it.
           */
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // OPEN PENDING ALARM
  // ---------------------------------------------------------------------------

  static Future<void> openPendingAlarm() async {
    final payload = _pendingAlarm;

    _pendingAlarm = null;

    if (payload == null) return;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        smaranNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => AlarmScreen(
              payload: payload,
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATION TAP
  // ---------------------------------------------------------------------------

  static void _onNotificationResponse(
    NotificationResponse response,
  ) {
    final payload = response.payload;

    if (payload == null || payload.isEmpty) {
      return;
    }

    final decoded = _decodePayload(payload);

    if (decoded == null) {
      return;
    }

    final navigator =
        smaranNavigatorKey.currentState;

    if (navigator == null) {
      _pendingAlarm = decoded;
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => AlarmScreen(
          payload: decoded,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DECODE PAYLOAD
  // ---------------------------------------------------------------------------

  static Map<String, dynamic>? _decodePayload(
    String payload,
  ) {
    try {
      final decoded = jsonDecode(payload);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}

/* ============================================================================
 * SHOW BACKGROUND NOTIFICATION — now multilingual + full-screen
 * ========================================================================== */

Future<void> _showAlarmNotificationWithPlugin(
  FlutterLocalNotificationsPlugin plugin,
  Map<String, dynamic> params,
) async {
  final language = params['language']?.toString() ?? 'English';
  final alarmType = params['alarmType']?.toString() ?? 'customTask';
  final medicineTiming = params['medicineTiming']?.toString();

  final (String notifTitle, String notifBody) =
      _buildNotificationText(
    language: language,
    alarmType: alarmType,
    medicineTiming: medicineTiming,
    title: params['title']?.toString() ?? 'Smaran Reminder',
    detail: params['detail']?.toString() ??
        'It is time for your reminder.',
  );

  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      _alarmChannelId,
      _alarmChannelName,
      channelDescription: _alarmChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      autoCancel: false,
      ongoing: true,
      visibility: NotificationVisibility.public,
      showWhen: true,
      styleInformation: BigTextStyleInformation(''),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'dismiss',
          'I Understand',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    ),
  );

  final payload = jsonEncode(params);

  final notificationId =
      (params['id'] as num?)?.toInt() ??
          DateTime.now()
              .millisecondsSinceEpoch
              .remainder(2147483647);

  await plugin.show(
    id: notificationId,
    title: notifTitle,
    body: notifBody,
    notificationDetails: details,
    payload: payload,
  );
}

/* ============================================================================
 * MULTILINGUAL NOTIFICATION TEXT
 * ========================================================================== */

(String, String) _buildNotificationText({
  required String language,
  required String alarmType,
  required String? medicineTiming,
  required String title,
  required String detail,
}) {
  final medicine = (alarmType == 'medicine' &&
          medicineTiming != null)
      ? ' • ${medicineTiming == 'beforeFood' ? _beforeFood(language) : _afterFood(language)}'
      : '';

  switch (language) {
    case 'বাংলা':
      return (
        'স্মরণ রিমাইন্ডার',
        '$title$medicine\n$detail',
      );
    case 'हिन्दी':
      return (
        'स्मरण रिमाइंडर',
        '$title$medicine\n$detail',
      );
    case 'অসমীয়া':
      return (
        'স্মৰণ ৰিমাইণ্ডাৰ',
        '$title$medicine\n$detail',
      );
    default:
      return (
        'Smaran Reminder',
        '$title$medicine\n$detail',
      );
  }
}

String _beforeFood(String language) {
  switch (language) {
    case 'বাংলা':
      return 'খাবারের আগে';
    case 'हिन्दी':
      return 'खाने से पहले';
    case 'অসমীয়া':
      return 'খোৱাৰ আগতে';
    default:
      return 'Before food';
  }
}

String _afterFood(String language) {
  switch (language) {
    case 'বাংলা':
      return 'খাবারের পরে';
    case 'हिन्दी':
      return 'खाने के बाद';
    case 'অসমীয়া':
      return 'খোৱাৰ পিছত';
    default:
      return 'After food';
  }
}

/* ============================================================================
 * MARK ONE-SHOT INACTIVE
 * ========================================================================== */

Future<void> _markOneShotInactive(
  int id,
) async {
  try {
    final prefs =
        await SharedPreferences.getInstance();

    final raw =
        prefs.getString('reminders') ?? '[]';

    final decoded = jsonDecode(raw);

    if (decoded is! List) {
      return;
    }

    final updated = decoded.map((entry) {
      if (entry is Map &&
          (entry['id'] as num?)?.toInt() == id) {
        final copy =
            Map<String, dynamic>.from(entry);

        copy['isActive'] = false;

        return copy;
      }

      return entry;
    }).toList();

    await prefs.setString(
      'reminders',
      jsonEncode(updated),
    );
  } catch (_) {
    /*
     * Ignore persistence failures inside background isolate.
     */
  }
}

/* ============================================================================
 * NEXT DAILY ALARM
 * ========================================================================== */

DateTime? _nextDailyFromParams(
  Map<String, dynamic> params,
) {
  final hour =
      (params['hour'] as num?)?.toInt() ?? 8;

  final minute =
      (params['minute'] as num?)?.toInt() ?? 0;

  final amPm =
      params['amPm']?.toString() ?? 'AM';

  final hour24 =
      amPm.toUpperCase() == 'PM'
          ? (hour == 12 ? 12 : hour + 12)
          : (hour == 12 ? 0 : hour);

  final now = DateTime.now();

  var next = DateTime(
    now.year,
    now.month,
    now.day,
    hour24,
    minute,
  );

  if (!next.isAfter(now)) {
    next = next.add(
      const Duration(days: 1),
    );
  }

  return next;
}

/* ============================================================================
 * BACKGROUND NOTIFICATION TAP
 * ========================================================================== */

@pragma('vm:entry-point')
Future<void> notificationTapBackground(
  NotificationResponse response,
) async {
  /*
   * Full-screen notifications are handled by the Android activity.
   *
   * Keep this function top-level because flutter_local_notifications
   * invokes it from a background isolate.
   */
}

/* ============================================================================
 * ALARM SCREEN
 * ========================================================================== */

class AlarmScreen extends StatefulWidget {
  final Map<String, dynamic> payload;

  const AlarmScreen({
    super.key,
    required this.payload,
  });

  @override
  State<AlarmScreen> createState() =>
      _AlarmScreenState();
}

class _AlarmScreenState
    extends State<AlarmScreen> {
  final FlutterTts _tts = FlutterTts();

  bool _speaking = false;

  // ---------------------------------------------------------------------------
  // PAYLOAD
  // ---------------------------------------------------------------------------

  String get title =>
      widget.payload['title']?.toString() ??
      'Smaran Reminder';

  String get detail =>
      widget.payload['detail']?.toString() ??
      'It is time for your reminder.';

  String get language =>
      widget.payload['language']?.toString() ??
      'English';

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _speak(),
    );
  }

  // ---------------------------------------------------------------------------
  // SPEAK
  // ---------------------------------------------------------------------------

  Future<void> _speak() async {
    if (_speaking) return;

    _speaking = true;

    try {
      await _tts.setSpeechRate(0.43);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      final locale = switch (language) {
        'বাংলা' => 'bn-IN',
        'हिन्दी' => 'hi-IN',
        'অসমীয়া' => 'as-IN',
        _ => 'en-IN',
      };

      try {
        await _tts.setLanguage(locale);
      } catch (_) {
        await _tts.setLanguage('en-IN');
      }

      final type =
          widget.payload['alarmType']
              ?.toString() ??
          'customTask';

      final timing =
          widget.payload['medicineTiming']
              ?.toString();

      final medicine =
          type == 'medicine' &&
                  timing != null
              ? ' '
                  '${timing == 'beforeFood'
                      ? 'Before food.'
                      : 'After food.'}'
              : '';

      await _tts.speak(
        'Smaran reminder. '
        '$title. '
        '$detail.'
        '$medicine',
      );
    } catch (_) {
      // TTS failure must not prevent the alarm screen.
    } finally {
      _speaking = false;
    }
  }

  // ---------------------------------------------------------------------------
  // DISMISS
  // ---------------------------------------------------------------------------

  Future<void> _dismiss() async {
    final id =
        (widget.payload['id'] as num?)?.toInt();

    if (id != null) {
      await AlarmService.notifications.cancel(
        id: id,
      );
    }

    await _tts.stop();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: cDeep,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.alarm_rounded,
                    color: cSoft,
                    size: 72,
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Smaran Reminder',
                    style: TextStyle(
                      color: cSoft,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 42),

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton(
                      onPressed: _dismiss,
                      style: FilledButton.styleFrom(
                        backgroundColor: cPrimary,
                      ),
                      child: const Text(
                        'I Understand',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton.icon(
                    onPressed: _speak,
                    icon: const Icon(
                      Icons.volume_up_rounded,
                      color: cSoft,
                    ),
                    label: const Text(
                      'Hear Again',
                      style: TextStyle(
                        color: cSoft,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}