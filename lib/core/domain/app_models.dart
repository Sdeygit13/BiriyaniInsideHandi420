import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum RepeatType { once, daily, specificDate }

enum AlarmType { medicine, food, memoryActivity, customTask }

enum MedicineTiming { beforeFood, afterFood }

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
    int? systemTimeStamp,
  }) : systemTimeStamp = systemTimeStamp ?? DateTime.now().millisecondsSinceEpoch;

  String get time => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $amPm';

  DateTime get nextSystemDateTime {
    final now = DateTime.now();
    final hour24 = amPm.toUpperCase() == 'PM'
        ? (hour == 12 ? 12 : hour + 12)
        : (hour == 12 ? 0 : hour);
    var target = repeatType == RepeatType.specificDate && specificDate != null
        ? DateTime(specificDate!.year, specificDate!.month, specificDate!.day, hour24, minute)
        : DateTime(now.year, now.month, now.day, hour24, minute);
    if (repeatType == RepeatType.daily || repeatType == RepeatType.once) {
      if (!target.isAfter(now)) target = target.add(const Duration(days: 1));
    }
    return target;
  }

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
      id: (json['id'] as num?)?.toInt() ?? DateTime.now().microsecondsSinceEpoch.remainder(2147483647),
      title: json['title']?.toString() ?? 'Reminder',
      detail: json['detail']?.toString() ?? '',
      hour: (json['hour'] as num?)?.toInt() ?? 8,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      amPm: json['amPm']?.toString() ?? 'AM',
      repeatType: parseRepeat(json['repeatType']?.toString()),
      specificDate: rawDate is num ? DateTime.fromMillisecondsSinceEpoch(rawDate.toInt()) : null,
      alarmType: parseAlarm(json['alarmType']?.toString()),
      medicineTiming: parseMedicine(json['medicineTiming']?.toString()),
      isActive: json['isActive'] as bool? ?? true,
      done: json['done'] as bool? ?? false,
      systemTimeStamp: (json['systemTimeStamp'] as num?)?.toInt(),
    );
  }
}

class Person {
  String name;
  String relation;
  Person({required this.name, required this.relation});
  Map<String, dynamic> toJson() => {'name': name, 'relation': relation};
  factory Person.fromJson(Map<String, dynamic> e) => Person(
        name: e['name']?.toString() ?? '',
        relation: e['relation']?.toString() ?? 'Family',
      );
}

class Memory {
  String title;
  String path;
  Memory({required this.title, required this.path});
  Map<String, dynamic> toJson() => {'title': title, 'path': path};
  factory Memory.fromJson(Map<String, dynamic> e) => Memory(
        title: e['title']?.toString() ?? 'Memory',
        path: e['path']?.toString() ?? '',
      );
}

class SmaranStore {
  late SharedPreferences prefs;
  String patientName = 'Patient';
  String caregiverName = 'Caregiver';
  String language = 'English';
  bool guardian = false;
  final List<AlarmReminder> reminders = [];
  final List<Person> people = [];
  final List<Memory> memories = [];

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
  }

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

  Future<void> save() async {
    await prefs.setString('patientName', patientName);
    await prefs.setString('caregiverName', caregiverName);
    await prefs.setString('language', language);
    await prefs.setBool('guardian', guardian);
    await prefs.setString('reminders', jsonEncode(reminders.map((e) => e.toJson()).toList()));
    await prefs.setString('people', jsonEncode(people.map((e) => e.toJson()).toList()));
    await prefs.setString('memories', jsonEncode(memories.map((e) => e.toJson()).toList()));
  }
}
