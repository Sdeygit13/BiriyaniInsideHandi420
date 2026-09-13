import '../domain/app_models.dart';

// =============================================================================
// REMINDER PARSER — "Set medicine for 10 AM" → AlarmReminder
// =============================================================================
class VoiceReminderParser {
  VoiceReminderParser._();

  /// Words that appear in a spoken command but are NOT part of the reminder
  /// title. These get stripped from the parsed title.
  static const _instructionWords = <String>[
    // English
    'please',
    'can you',
    'could you',
    'would you',
    'set',
    'set up',
    'setup',
    'create',
    'add',
    'make',
    'schedule',
    'remind me to',
    'remind me',
    'remind',
    'alarm for',
    'alarm',
    'reminder for',
    'reminder',
    // Bengali
    'দয়া করে',
    'অনুগ্রহ করে',
    'সেট',
    'সেট করুন',
    'বানাও',
    'তৈরি',
    'যোগ',
    'মনে করিয়ে',
    'রিমাইন্ডার',
    'অ্যালার্ম',
    // Hindi
    'कृपया',
    'सेट',
    'सेट करें',
    'बनाओ',
    'बनाएं',
    'जोड़ें',
    'याद दिलाएं',
    'रिमाइंडर',
    'अलार्म',
    // Assamese
    'অনুগ্ৰহ কৰি',
    'ছেট',
    'ছেট কৰক',
    'বনাওক',
    'সৃষ্টি',
    'যোগ',
    'মনত পেলাওক',
    'ৰিমাইণ্ডাৰ',
    'এলাৰম',
  ];

  static AlarmReminder? parse(String transcript, {required int nextId}) {
    final text = transcript.trim();
    if (text.isEmpty) return null;

    final lower = text.toLowerCase();

    // ── 1. Detect alarm type ─────────────────────────────────
    AlarmType type = AlarmType.customTask;
    if (_containsAny(lower, [
      'medicine', 'tablet', 'pill', 'medication', 'dose',
      'ঔষধ', 'ওষুধ', 'मेडिसिन', 'दवा', 'दवाई', 'औषध', 'ঔষধ',
    ])) {
      type = AlarmType.medicine;
    } else if (_containsAny(lower, [
      'food', 'lunch', 'dinner', 'breakfast', 'meal', 'eat', 'snack',
      'খাবার', 'খাওয়া', 'खाना', 'भोजन',
    ])) {
      type = AlarmType.food;
    } else if (_containsAny(lower, [
      'memory', 'game', 'activity', 'recall', 'puzzle',
      'স্মৃতি', 'খেলা', 'याद', 'खेल',
    ])) {
      type = AlarmType.memoryActivity;
    }

    // ── 2. Medicine timing ───────────────────────────────────
    MedicineTiming? medicineTiming;
    if (type == AlarmType.medicine) {
      if (_containsAny(lower, [
        'before food', 'before meal', 'before eating',
        'খাবারের আগে', 'খাওয়ার আগে', 'खाने से पहले', 'खोৱাৰ আগতে',
      ])) {
        medicineTiming = MedicineTiming.beforeFood;
      } else {
        medicineTiming = MedicineTiming.afterFood;
      }
    }

    // ── 3. Repeat ────────────────────────────────────────────
    RepeatType repeat = RepeatType.daily;
    if (_containsAny(lower, [
      'once', 'one time', 'only today', 'today only', 'just once',
      'একবার', 'एक बार',
    ])) {
      repeat = RepeatType.once;
    }

    // ── 4. Time ──────────────────────────────────────────────
    final timeResult = _extractTime(text);
    if (timeResult == null) return null;

    // ── 5. Title (stripped of instruction words) ─────────────
    final title = _buildTitle(text, type);

    return AlarmReminder(
      id: nextId,
      title: title,
      hour: timeResult.hour,
      minute: timeResult.minute,
      amPm: timeResult.amPm,
      repeatType: repeat,
      alarmType: type,
      medicineTiming: medicineTiming,
    );
  }

  // ── Time extraction ───────────────────────────────────────
  static ({int hour, int minute, String amPm})? _extractTime(String text) {
    // English: "10 A.M", "10:30 PM"
    final enMatch = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)',
      caseSensitive: false,
    ).firstMatch(text);

    if (enMatch != null) {
      final hour = int.tryParse(enMatch.group(1)!) ?? 8;
      final minute = int.tryParse(enMatch.group(2) ?? '0') ?? 0;
      final marker = enMatch.group(3)!.toLowerCase();
      final amPm = marker.startsWith('p') ? 'PM' : 'AM';
      return (
        hour: hour == 0 ? 12 : hour.clamp(1, 12),
        minute: minute.clamp(0, 59),
        amPm: amPm,
      );
    }

    // Bengali digits → ASCII
    final normalized = text
        .replaceAll('০', '0').replaceAll('১', '1').replaceAll('২', '2')
        .replaceAll('৩', '3').replaceAll('৪', '4').replaceAll('৫', '5')
        .replaceAll('৬', '6').replaceAll('৭', '7').replaceAll('৮', '8')
        .replaceAll('৯', '9');

    final asianMatch = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(টা|টায়|বাজে|बजे|ঘটিকা)?',
    ).firstMatch(normalized);

    if (asianMatch != null) {
      final hour = int.tryParse(asianMatch.group(1)!) ?? 8;
      final minute = int.tryParse(asianMatch.group(2) ?? '0') ?? 0;

      String amPm = 'AM';
      if (_containsAny(text, ['রাত', 'रात', 'সন্ধ্যা', 'शाम', 'বিকাল'])) {
        amPm = 'PM';
      } else if (_containsAny(text, ['দুপুর', 'दोपहर'])) {
        amPm = 'PM';
        if (hour < 12) return (hour: hour, minute: minute, amPm: 'PM');
      } else if (_containsAny(text, ['সকাল', 'सुबह'])) {
        amPm = 'AM';
      }

      return (
        hour: hour == 0 ? 12 : hour.clamp(1, 12),
        minute: minute.clamp(0, 59),
        amPm: amPm,
      );
    }

    return null;
  }

  // ── Title builder (strips instruction words) ──────────────
  static String _buildTitle(String text, AlarmType type) {
    // 1. Remove time expressions
    var cleaned = text
        .replaceAll(
          RegExp(r'\b\d{1,2}(?::\d{2})?\s*(a\.?m\.?|p\.?m\.?)\b',
              caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'\b\d{1,2}(?::\d{2})?\s*(টা|টায়|বাজে|बजे|ঘটিকা)\b'),
          ' ',
        )
        .replaceAll(
          RegExp(r'\b\d{1,2}(?::\d{2})?\b'),
          ' ',
        );

    // 2. Remove "at", "for", "on", "to", "about"
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(at|for|on|to|about|@)\b', caseSensitive: false),
      ' ',
    );

    // 3. Remove Bengali/Hindi/Assamese time-of-day words
    for (final word in [
      'সকাল', 'দুপুর', 'বিকাল', 'সন্ধ্যা', 'রাত',
      'सुबह', 'दोपहर', 'शाम', 'रात',
      'ৰাতিপু', 'ৰাতি', 'পুৱা', 'আবেলি',
    ]) {
      cleaned = cleaned.replaceAll(word, ' ');
    }

    // 4. Remove instruction words (case-insensitive)
    final lowerClean = cleaned.toLowerCase();
    for (final instr in _instructionWords) {
      if (lowerClean.contains(instr)) {
        cleaned = cleaned.replaceAll(
          RegExp(RegExp.escape(instr), caseSensitive: false),
          ' ',
        );
      }
    }

    // 5. Collapse whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 6. Strip leading "for/to/about" leftovers
    cleaned = cleaned
        .replaceAll(RegExp(r'^(for|to|about|at|on)\s+', caseSensitive: false), '')
        .trim();

    // 7. Capitalize first letter
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    // 8. If empty, fall back to type-based default
    if (cleaned.isEmpty) {
      return switch (type) {
        AlarmType.medicine => 'Medicine',
        AlarmType.food => 'Meal',
        AlarmType.memoryActivity => 'Memory Activity',
        AlarmType.customTask => 'Reminder',
      };
    }

    return cleaned;
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}

// =============================================================================
// VOICE QUERY HANDLER — "What's my next reminder?" → spoken answer
// =============================================================================
class VoiceQueryHandler {
  VoiceQueryHandler._();

  /// Returns a localised answer string, or null if the query isn't a
  /// question the handler recognises (so the caller can fall back to
  /// the alarm parser).
  static String? respond({
    required String transcript,
    required List<AlarmReminder> reminders,
    required String language,
  }) {
    final text = transcript.trim().toLowerCase();
    if (text.isEmpty) return null;

    final pending = reminders.where((r) => r.isActive && !r.done).toList()
      ..sort((a, b) => a.nextSystemDateTime.compareTo(b.nextSystemDateTime));

    // ── "Next reminder" ─────────────────────────────────────
    if (_matches(text, [
      "what's my next reminder", 'what is my next reminder',
      'next reminder', 'my next reminder', 'upcoming reminder',
      'মेरा अगला रिमाइंडर क्या है', 'अगला रिमाइंडर',
      'আমার পরবর্তী রিমাইন্ডার কী', 'পরবর্তী রিমাইন্ডার',
      'মোৰ পৰৱৰ্তী ৰিমাইণ্ডাৰটো কি', 'পৰৱৰ্তী ৰিমাইণ্ডাৰ',
    ])) {
      if (pending.isEmpty) {
        return _pick(language, {
          'English': 'You have no upcoming reminders right now.',
          'বাংলা': 'এই মুহূর্তে আপনার কোনো আসন্ন রিমাইন্ডার নেই।',
          'हिन्दी': 'अभी आपका कोई आने वाला रिमाइंडर नहीं है।',
          'অসমীয়া': 'এই মুহূর্তত আপোনাৰ কোনো আগন্তুক ৰিমাইণ্ডাৰ নাই।',
        });
      }
      final next = pending.first;
      final time = _fmt(next);
      return _pick(language, {
        'English': 'Your next reminder is ${next.title} at $time.',
        'বাংলা': 'আপনার পরবর্তী রিমাইন্ডার হলো ${next.title}, সময় $time।',
        'हिन्दी': 'आपका अगला रिमाइंडर ${next.title} है, समय $time।',
        'অসমীয়া': 'আপোনাৰ পৰৱৰ্তী ৰিমাইণ্ডাৰ হৈছে ${next.title}, সময় $time।',
      });
    }

    // ── "All reminders" / "Today's reminders" ───────────────
    if (_matches(text, [
      'all reminders', 'list reminders', 'show reminders',
      'my reminders', "today's reminders", 'today reminders',
      'আজ আমার কী আছে', 'সব রিমাইন্ডার',
      'आज मेरा क्या है', 'सभी रिमाइंडर',
      'আজিৰ বাবে মোৰ কি আছে', 'সকলো ৰিমাইণ্ডাৰ',
    ])) {
      if (pending.isEmpty) {
        return _pick(language, {
          'English': 'You have no reminders scheduled right now.',
          'বাংলা': 'এই মুহূর্তে আপনার কোনো রিমাইন্ডার নেই।',
          'हिन्दी': 'अभी आपके लिए कोई रिमाइंडर नहीं है।',
          'অসমীয়া': 'এই মুহূর্তত আপোনাৰ কোনো ৰিমাইণ্ডাৰ নাই।',
        });
      }
      final list = pending
          .take(4)
          .map((r) => '${r.title} at ${_fmt(r)}')
          .join(', ');
      return _pick(language, {
        'English': 'You have ${pending.length} reminders. $list.',
        'বাংলা': 'আপনার ${pending.length}টি রিমাইন্ডার আছে। $list।',
        'हिन्दी': 'आपके ${pending.length} रिमाइंडर हैं। $list।',
        'অসমীয়া': 'আপোনাৰ ${pending.length}টা ৰিমাইণ্ডাৰ আছে। $list।',
      });
    }

    // ── "Medicine reminders" ────────────────────────────────
    if (_matches(text, [
      'medicine reminder', 'my medicine', 'medication',
      'ঔষধের রিমাইন্ডার', 'আমার ওষুধ',
      'दवा का रिमाइंडर', 'मेरी दवा',
      'ঔষধৰ ৰিমাইণ্ডাৰ', 'মোৰ ঔষধ',
    ])) {
      final meds = pending.where((r) => r.alarmType == AlarmType.medicine).toList();
      if (meds.isEmpty) {
        return _pick(language, {
          'English': 'You have no medicine reminders right now.',
          'বাংলা': 'এই মুহূর্তে কোনো ওষুধের রিমাইন্ডার নেই।',
          'हिन्दी': 'अभी कोई दवा का रिमाइंडर नहीं है।',
          'অসমীয়া': 'এই মুহূর্তত কোনো ঔষধৰ ৰিমাইণ্ডাৰ নাই।',
        });
      }
      final list = meds.take(3).map((r) => '${r.title} at ${_fmt(r)}').join(', ');
      return _pick(language, {
        'English': 'Your medicine reminders are: $list.',
        'বাংলা': 'আপনার ওষুধের রিমাইন্ডার হলো: $list।',
        'हिन्दी': 'आपकी दवा के रिमाइंडर हैं: $list।',
        'অসমীয়া': 'আপোনাৰ ঔষধৰ ৰিমাইণ্ডাৰসমূহ: $list।',
      });
    }

    // Not a known query
    return null;
  }

  static String _fmt(AlarmReminder r) {
    var h = r.hour;
    if (h == 0) {
      h = 12;
    } else if (h > 12) {
      h -= 12;
    }
    return '$h:${r.minute.toString().padLeft(2, '0')} ${r.amPm.toUpperCase()}';
  }

  static bool _matches(String text, List<String> needles) {
    for (final n in needles) {
      if (text.contains(n.toLowerCase())) return true;
    }
    return false;
  }

  static String _pick(String lang, Map<String, String> variants) {
    return variants[lang] ?? variants['English']!;
  }
}