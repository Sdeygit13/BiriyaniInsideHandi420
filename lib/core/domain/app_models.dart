import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// ENUMS
// =============================================================================

enum RepeatType { once, daily, specificDate }

enum AlarmType { medicine, food, memoryActivity, customTask }

enum MedicineTiming { beforeFood, afterFood }

// =============================================================================
// GAME SESSION
//
// One record per completed game. Used for:
//   - Progress banner on Home ("2 of 5 games today")
//   - Difficulty Optimizer (adjusts next game difficulty)
//   - Caregiver dashboard (long-term trends)
// =============================================================================

class GameSession {
  /// 'memory_match' | 'sequence_recall' | 'pattern_tap' | 'word_picture' | 'sound_match'
  final String gameId;

  /// 0..100. Higher = better performance.
  final int score;

  /// How long the user took, in seconds.
  final int durationSec;

  /// Difficulty level when this session was played. 1..10.
  final int difficulty;

  /// Number of moves / taps / attempts.
  final int moves;

  /// When the session finished.
  final DateTime timestamp;

  const GameSession({
    required this.gameId,
    required this.score,
    required this.durationSec,
    required this.difficulty,
    required this.moves,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'score': score,
        'durationSec': durationSec,
        'difficulty': difficulty,
        'moves': moves,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory GameSession.fromJson(Map<String, dynamic> j) => GameSession(
        gameId: j['gameId']?.toString() ?? '',
        score: (j['score'] as num?)?.toInt() ?? 0,
        durationSec: (j['durationSec'] as num?)?.toInt() ?? 0,
        difficulty: (j['difficulty'] as num?)?.toInt() ?? 1,
        moves: (j['moves'] as num?)?.toInt() ?? 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (j['timestamp'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
        ),
      );
}

// =============================================================================
// ALARM REMINDER
// =============================================================================

class AlarmReminder {
  final int id;
  String title;
  String detail;
  int hour;
  int minute;
  String amPm;
  RepeatType repeatType;
  DateTime? specificDate;
  AlarmType alarmType;
  MedicineTiming? medicineTiming;
  bool isActive;
  bool done;

  /// The language used to set this reminder.
  String language;

  /// Display name of whoever created this reminder.
  /// `null` means the patient created it themselves.
  /// Non-null means a caregiver / family member set it.
  String? createdByName;

  int systemTimeStamp;

  AlarmReminder({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    required this.amPm,
    required this.repeatType,
    required this.alarmType,
    this.detail = '',
    this.specificDate,
    this.medicineTiming,
    this.isActive = true,
    this.done = false,
    this.language = 'english',
    this.createdByName,
    int? systemTimeStamp,
  }) : systemTimeStamp = systemTimeStamp ?? DateTime.now().millisecondsSinceEpoch;

  /// True if a caregiver / family member set this reminder.
  bool get isCaregiverSet => createdByName != null;

  // ── Convenience getters ─────────────────────────────────────

  /// Display string like "10:30 AM".
  String get time =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $amPm';

  /// Next actual DateTime this alarm should fire.
  DateTime get nextSystemDateTime {
    final now = DateTime.now();
    final hour24 = amPm.toUpperCase() == 'PM'
        ? (hour == 12 ? 12 : hour + 12)
        : (hour == 12 ? 0 : hour);

    var target = repeatType == RepeatType.specificDate && specificDate != null
        ? DateTime(
            specificDate!.year,
            specificDate!.month,
            specificDate!.day,
            hour24,
            minute,
          )
        : DateTime(now.year, now.month, now.day, hour24, minute);

    if (repeatType == RepeatType.daily || repeatType == RepeatType.once) {
      if (!target.isAfter(now)) target = target.add(const Duration(days: 1));
    }
    return target;
  }

  // ── JSON ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'detail': detail,
        'hour': hour,
        'minute': minute,
        'amPm': amPm,
        'repeatType': repeatType.name,
        'specificDate': specificDate?.millisecondsSinceEpoch,
        'alarmType': alarmType.name,
        'medicineTiming': medicineTiming?.name,
        'isActive': isActive,
        'done': done,
        'language': language,
        'createdByName': createdByName,
        'systemTimeStamp': systemTimeStamp,
      };

  factory AlarmReminder.fromJson(Map<String, dynamic> json) {
    RepeatType parseRepeat(String? value) => RepeatType.values.firstWhere(
          (e) => e.name == value,
          orElse: () => RepeatType.daily,
        );
    AlarmType parseAlarm(String? value) => AlarmType.values.firstWhere(
          (e) => e.name == value,
          orElse: () => AlarmType.customTask,
        );
    MedicineTiming? parseMedicine(String? value) => value == null
        ? null
        : MedicineTiming.values.firstWhere(
            (e) => e.name == value,
            orElse: () => MedicineTiming.beforeFood,
          );

    final rawDate = json['specificDate'];
    return AlarmReminder(
      id: (json['id'] as num?)?.toInt() ??
          DateTime.now().microsecondsSinceEpoch.remainder(2147483647),
      title: json['title']?.toString() ?? 'Reminder',
      detail: json['detail']?.toString() ?? '',
      hour: (json['hour'] as num?)?.toInt() ?? 8,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      amPm: json['amPm']?.toString() ?? 'AM',
      repeatType: parseRepeat(json['repeatType']?.toString()),
      specificDate: rawDate is num
          ? DateTime.fromMillisecondsSinceEpoch(rawDate.toInt())
          : null,
      alarmType: parseAlarm(json['alarmType']?.toString()),
      medicineTiming: parseMedicine(json['medicineTiming']?.toString()),
      isActive: json['isActive'] as bool? ?? true,
      done: json['done'] as bool? ?? false,
      language: json['language']?.toString() ?? 'english',
      createdByName: json['createdByName']?.toString(),
      systemTimeStamp: (json['systemTimeStamp'] as num?)?.toInt(),
    );
  }
}

// =============================================================================
// PERSON
// =============================================================================

class Person {
  String name;
  String relation;

  Person({required this.name, required this.relation});

  Map<String, dynamic> toJson() => {
        'name': name,
        'relation': relation,
      };

  factory Person.fromJson(Map<String, dynamic> e) => Person(
        name: e['name']?.toString() ?? '',
        relation: e['relation']?.toString() ?? 'Family',
      );
}

// =============================================================================
// MEMORY
// =============================================================================

class Memory {
  String title;
  String path;

  Memory({required this.title, required this.path});

  Map<String, dynamic> toJson() => {
        'title': title,
        'path': path,
      };

  factory Memory.fromJson(Map<String, dynamic> e) => Memory(
        title: e['title']?.toString() ?? 'Memory',
        path: e['path']?.toString() ?? '',
      );
}

// =============================================================================
// SMARAN STORE
// =============================================================================

class SmaranStore extends ChangeNotifier {
  late SharedPreferences prefs;

  String patientName = 'Patient';
  String caregiverName = 'Caregiver';
  String language = 'English';
  bool guardian = false;

  final List<AlarmReminder> reminders = [];
  final List<Person> people = [];
  final List<Memory> memories = [];
  final List<GameSession> gameSessions = [];

  // ── Load ────────────────────────────────────────────────────

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();

    patientName = prefs.getString('patientName') ?? 'Patient';
    caregiverName = prefs.getString('caregiverName') ?? 'Caregiver';
    language = prefs.getString('language') ?? 'English';
    guardian = prefs.getBool('guardian') ?? false;

    reminders
      ..clear()
      ..addAll(_decodeList('reminders').map(AlarmReminder.fromJson));

    people
      ..clear()
      ..addAll(_decodeList('people').map(Person.fromJson));

    memories
      ..clear()
      ..addAll(_decodeList('memories').map(Memory.fromJson));

    gameSessions
      ..clear()
      ..addAll(_decodeList('gameSessions').map(GameSession.fromJson));

    notifyListeners();  
  }

  // ── Save ────────────────────────────────────────────────────

  Future<void> save() async {
    await prefs.setString('patientName', patientName);
    await prefs.setString('caregiverName', caregiverName);
    await prefs.setString('language', language);
    await prefs.setBool('guardian', guardian);

    await prefs.setString(
      'reminders',
      jsonEncode(reminders.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'people',
      jsonEncode(people.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'memories',
      jsonEncode(memories.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'gameSessions',
      jsonEncode(gameSessions.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  // ── Game helpers ────────────────────────────────────────────

  /// Number of distinct games completed today (max 5).
  int gamesCompletedToday() {
    final today = DateTime.now();
    final ids = <String>{};
    for (final s in gameSessions) {
      if (s.timestamp.year == today.year &&
          s.timestamp.month == today.month &&
          s.timestamp.day == today.day) {
        ids.add(s.gameId);
      }
    }
    return ids.length.clamp(0, 5);
  }

  /// Sessions of a given game, newest first.
  List<GameSession> sessionsFor(String gameId) {
    final list = gameSessions.where((s) => s.gameId == gameId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  // ── Helpers ─────────────────────────────────────────────────

  List<Map<String, dynamic>> _decodeList(String key) {
    final raw = prefs.getString(key) ?? '[]';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}