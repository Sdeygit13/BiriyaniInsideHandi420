import 'dart:convert';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_models.dart';
import '../theme/app_theme.dart';

final GlobalKey<NavigatorState> smaranNavigatorKey = GlobalKey<NavigatorState>();

class AlarmService {
  AlarmService._();

  static final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  static const String _channelId = 'smaran_native_alarm';
  static const String _channelName = 'Smaran Alarms';
  static const String _channelDescription = 'Exact reminders and alarm notifications for Smaran.';
  static Map<String, dynamic>? _pendingAlarm;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await AndroidAlarmManager.initialize();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final android = notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    final launchDetails = await notifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        _pendingAlarm = _decodePayload(payload);
      }
    }
  }

  static Future<void> requestPermissions() async {
    final android = notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    await android?.requestFullScreenIntentPermission();
  }

  static Future<void> schedule(AlarmReminder reminder) async {
    if (!reminder.isActive) return;
    await cancel(reminder.id);

    final target = reminder.nextSystemDateTime;
    if (!target.isAfter(DateTime.now())) return;

    reminder.systemTimeStamp = DateTime.now().millisecondsSinceEpoch;

    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('language') ?? 'English';

    final params = <String, dynamic>{
      'id': reminder.id,
      'title': reminder.title,
      'detail': reminder.detail,
      'hour': reminder.hour,
      'minute': reminder.minute,
      'amPm': reminder.amPm,
      'repeatType': reminder.repeatType.name,
      'specificDate': reminder.specificDate?.millisecondsSinceEpoch,
      'alarmType': reminder.alarmType.name,
      'medicineTiming': reminder.medicineTiming?.name,
      'language': language,
    };

    await AndroidAlarmManager.oneShotAt(
      target,
      reminder.id,
      alarmCallback,
      alarmClock: true,
      allowWhileIdle: true,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: params,
    );
  }

  static Future<void> cancel(int id) async {
    await AndroidAlarmManager.cancel(id);
    await notifications.cancel(id);
  }

  static Future<void> rescheduleAll(Iterable<AlarmReminder> reminders) async {
    for (final reminder in reminders) {
      if (reminder.isActive && !reminder.done) {
        try {
          await schedule(reminder);
        } catch (_) {
          // Keep the saved reminder even if Android temporarily refuses an alarm.
        }
      }
    }
  }

  static Future<void> openPendingAlarm() async {
    final payload = _pendingAlarm;
    _pendingAlarm = null;
    if (payload == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      smaranNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => AlarmScreen(payload: payload)),
      );
    });
  }

  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final decoded = _decodePayload(payload);
    if (decoded == null) return;
    final navigator = smaranNavigatorKey.currentState;
    if (navigator == null) {
      _pendingAlarm = decoded;
      return;
    }
    navigator.push(MaterialPageRoute(builder: (_) => AlarmScreen(payload: decoded)));
  }

  static Map<String, dynamic>? _decodePayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }


  static Future<void> _showAlarmNotification(Map<String, dynamic> params) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
        autoCancel: false,
        ongoing: true,
      ),
    );

    final payload = jsonEncode(params);
    final title = params['title']?.toString() ?? 'Smaran Reminder';
    final detail = params['detail']?.toString() ?? '';
    final type = params['alarmType']?.toString() ?? 'customTask';
    final medicineTiming = params['medicineTiming']?.toString();
    final body = type == 'medicine' && medicineTiming != null
        ? '$detail • ${medicineTiming == 'beforeFood' ? 'Before food' : 'After food'}'
        : detail;

    await notifications.show(
      id: (params['id'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: title,
      body: body.isEmpty ? 'It is time for your Smaran reminder.' : body,
      notificationDetails: details,
      payload: payload,
    );
  }

  @pragma('vm:entry-point')
  static Future<void> alarmCallback(int id, Map<String, dynamic> params) async {
    WidgetsFlutterBinding.ensureInitialized();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    await _showAlarmNotificationWithPlugin(plugin, params);

    if (params['repeatType']?.toString() == RepeatType.daily.name) {
      final next = _nextDailyFromParams(params);
      if (next != null) {
        await AndroidAlarmManager.oneShotAt(
          next,
          id,
          alarmCallback,
          alarmClock: true,
          allowWhileIdle: true,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
          params: params,
        );
      }
    } else {
      await _markOneShotInactive(id);
    }
  }

  static Future<void> _markOneShotInactive(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('reminders') ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final updated = decoded.map((entry) {
        if (entry is Map && (entry['id'] as num?)?.toInt() == id) {
          final copy = Map<String, dynamic>.from(entry);
          copy['isActive'] = false;
          return copy;
        }
        return entry;
      }).toList();
      await prefs.setString('reminders', jsonEncode(updated));
    } catch (_) {}
  }

  static Future<void> _showAlarmNotificationWithPlugin(
    FlutterLocalNotificationsPlugin plugin,
    Map<String, dynamic> params,
  ) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
        autoCancel: false,
        ongoing: true,
      ),
    );

    final payload = jsonEncode(params);
    final title = params['title']?.toString() ?? 'Smaran Reminder';
    final detail = params['detail']?.toString() ?? 'It is time for your reminder.';
    final type = params['alarmType']?.toString() ?? 'customTask';
    final medicineTiming = params['medicineTiming']?.toString();
    final body = type == 'medicine' && medicineTiming != null
        ? '$detail • ${medicineTiming == 'beforeFood' ? 'Before food' : 'After food'}'
        : detail;

    await plugin.show(
      id: (params['id'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  static DateTime? _nextDailyFromParams(Map<String, dynamic> params) {
    final hour = (params['hour'] as num?)?.toInt() ?? 8;
    final minute = (params['minute'] as num?)?.toInt() ?? 0;
    final amPm = params['amPm']?.toString() ?? 'AM';
    final hour24 = amPm.toUpperCase() == 'PM'
        ? (hour == 12 ? 12 : hour + 12)
        : (hour == 12 ? 0 : hour);
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour24, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }
}

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  // Full-screen notifications are delivered to MainActivity and handled there.
}

class AlarmScreen extends StatefulWidget {
  final Map<String, dynamic> payload;
  const AlarmScreen({super.key, required this.payload});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  String get title => widget.payload['title']?.toString() ?? 'Smaran Reminder';
  String get detail => widget.payload['detail']?.toString() ?? 'It is time for your reminder.';
  String get language => widget.payload['language']?.toString() ?? 'English';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

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
      final type = widget.payload['alarmType']?.toString() ?? 'customTask';
      final timing = widget.payload['medicineTiming']?.toString();
      final medicine = type == 'medicine' && timing != null
          ? ' ${timing == 'beforeFood' ? 'Before food.' : 'After food.'}'
          : '';
      await _tts.speak('Smaran reminder. $title. $detail.$medicine');
    } finally {
      _speaking = false;
    }
  }

  Future<void> _dismiss() async {
    final id = (widget.payload['id'] as num?)?.toInt();
    if (id != null) await AlarmService.notifications.cancel(id);
    await _tts.stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: cDeep,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.alarm_rounded, color: cSoft, size: 72),
                    const SizedBox(height: 22),
                    const Text('Smaran Reminder', style: TextStyle(color: cSoft, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 18, height: 1.45)),
                    const SizedBox(height: 42),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton(
                        onPressed: _dismiss,
                        style: FilledButton.styleFrom(backgroundColor: cPrimary),
                        child: const Text('I Understand', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _speak,
                      icon: const Icon(Icons.volume_up_rounded, color: cSoft),
                      label: const Text('Hear Again', style: TextStyle(color: cSoft, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
