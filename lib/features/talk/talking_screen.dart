import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/ai/voice_reminder_parser.dart';
import '../../core/domain/app_models.dart';
import '../../core/theme/app_theme.dart';

class TalkingScreen extends StatefulWidget {
  const TalkingScreen({super.key});

  @override
  State<TalkingScreen> createState() => _TalkingScreenState();
}

class _TalkingScreenState extends State<TalkingScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _manualInput = TextEditingController();
  final FlutterTts _tts = FlutterTts();

  bool _listening = false;
  bool _available = false;
  String _transcript = '';
  String _localeId = 'en_IN';
  AlarmReminder? _parsed;
  String? _queryAnswer;   // NEW: holds Q&A response
  String? _error;

  static const _languages = <String, String>{
    'en_IN': 'English',
    'bn_IN': 'বাংলা',
    'hi_IN': 'हिन्दी',
    'as_IN': 'অসমীয়া',
  };

  String get _languageName => _languages[_localeId] ?? 'English';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setSpeechRate(0.43);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (_) {}
  }

  Future<void> _initSpeech() async {
    try {
      _available = await _speech.initialize(
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _error = 'Microphone error: ${err.errorMsg}';
          });
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
      );
      if (mounted) setState(() {});
    } catch (_) {
      _available = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _error = null;
      _parsed = null;
      _queryAnswer = null;
      _transcript = '';
    });

    if (!_available) {
      setState(() =>
          _error = 'Microphone unavailable. Type your reminder below instead.');
      return;
    }

    final ok = await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _transcript = result.recognizedWords);
        if (result.finalResult && _transcript.trim().isNotEmpty) {
          _handleTranscript(_transcript);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        localeId: _localeId,
      ),
    );

    if (!mounted) return;
    setState(() => _listening = ok);
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _listening = false);
    if (_transcript.trim().isNotEmpty) {
      _handleTranscript(_transcript);
    }
  }

  /// Decide: is the transcript a question, or an alarm command?
  Future<void> _handleTranscript(String text) async {
    // 1. Try Q&A first
    final answer = VoiceQueryHandler.respond(
      transcript: text,
      reminders: const [],   // We don't have store here; swap for real store if needed
      language: _languageName,
    );

    if (answer != null) {
      setState(() {
        _queryAnswer = answer;
        _parsed = null;
        _error = null;
      });
      await _speak(answer);
      return;
    }

    // 2. Try alarm parse
    final result = VoiceReminderParser.parse(
      text,
      nextId: DateTime.now().microsecondsSinceEpoch.remainder(2147483647),
    );

    setState(() {
      if (result == null) {
        _error = 'Could not understand the time. '
            'Try: "Set medicine for 10 A.M" or "সকাল ১০টায় ঔষধ".';
        _parsed = null;
      } else {
        _parsed = result;
        _error = null;
      }
      _queryAnswer = null;
    });
  }

  Future<void> _speak(String text) async {
    try {
      final locale = switch (_languageName) {
        'বাংলা' => 'bn-IN',
        'हिन्दी' => 'hi-IN',
        'অসমীয়া' => 'as-IN',
        _ => 'en-IN',
      };
      await _tts.setLanguage(locale);
      await _tts.speak(text);
    } catch (_) {}
  }

  void _confirm() {
    if (_parsed == null) return;
    Navigator.pop(context, _parsed);
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _manualInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: cBg,
        elevation: 0,
        title: const Text(
          'Voice Reminder',
          style: TextStyle(fontWeight: FontWeight.w900, color: cDeep),
        ),
      ),
      body: SafeArea(
        // ── FIX: whole body scrolls, prevents RenderFlex overflow ──
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Language selector
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _languages.entries.map((e) {
                  final selected = _localeId == e.key;
                  return ChoiceChip(
                    label: Text(
                      e.value,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : cText,
                      ),
                    ),
                    selected: selected,
                    selectedColor: cPrimaryDark,
                    backgroundColor: cWhite,
                    onSelected: (_) => setState(() => _localeId = e.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Mic button
              Center(
                child: GestureDetector(
                  onTap: _listening ? _stopListening : _startListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _listening ? cDanger : cPrimaryDark,
                      boxShadow: [
                        BoxShadow(
                          color: (_listening ? cDanger : cPrimaryDark)
                              .withValues(alpha: 0.35),
                          blurRadius: _listening ? 40 : 20,
                          spreadRadius: _listening ? 8 : 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _listening ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 62,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                _listening ? 'Listening… Speak now' : 'Tap the mic and say your reminder',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: cDeep,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Example: "Set medicine for 10 A.M" or "সকাল ১০টায় ঔষধ"',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cMuted),
              ),

              // Live transcript
              if (_transcript.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: cMint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('You said:',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: cMuted)),
                      const SizedBox(height: 4),
                      Text(_transcript,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: cDeep)),
                    ],
                  ),
                ),
              ],

              // Q&A response card
              if (_queryAnswer != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cPrimaryDark, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.record_voice_over_rounded,
                              color: cPrimaryDark, size: 20),
                          SizedBox(width: 8),
                          Text('Smaran says',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: cPrimaryDark)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_queryAnswer!,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: cDeep,
                              height: 1.4)),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _speak(_queryAnswer!),
                          icon: const Icon(Icons.volume_up_rounded,
                              color: cPrimaryDark, size: 20),
                          label: const Text('Hear again',
                              style: TextStyle(
                                  color: cPrimaryDark,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Parsed alarm preview
              if (_parsed != null) ...[
                const SizedBox(height: 14),
                _PreviewCard(reminder: _parsed!),
              ],

              // Error
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: cDanger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: cDanger)),
                ),
              ],

              const SizedBox(height: 18),

              // Manual fallback input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualInput,
                      decoration: inputDec('Or type here',
                          hint: 'Set medicine for 10 A.M'),
                      onSubmitted: (v) {
                        if (v.trim().isEmpty) return;
                        _handleTranscript(v.trim());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: cPrimaryDark,
                    child: IconButton(
                      icon: const Icon(Icons.check_rounded, color: Colors.white),
                      onPressed: () {
                        if (_manualInput.text.trim().isEmpty) return;
                        _handleTranscript(_manualInput.text.trim());
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Confirm button (only when an alarm is parsed)
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _parsed == null ? null : _confirm,
                  icon: const Icon(Icons.alarm_add_rounded),
                  label: Text(
                    _parsed == null ? 'Waiting for reminder…' : 'Add this Alarm',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cPrimaryDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: cBorder,
                    disabledForegroundColor: cMuted,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PARSED PREVIEW CARD
// =============================================================================
class _PreviewCard extends StatelessWidget {
  final AlarmReminder reminder;
  const _PreviewCard({required this.reminder});

  String get _typeLabel => switch (reminder.alarmType) {
        AlarmType.medicine => 'Medicine',
        AlarmType.food => 'Food',
        AlarmType.memoryActivity => 'Memory Activity',
        AlarmType.customTask => 'Specific Task',
      };

  String get _medicineLabel =>
      reminder.medicineTiming == MedicineTiming.beforeFood
          ? ' • Before food'
          : reminder.medicineTiming == MedicineTiming.afterFood
              ? ' • After food'
              : '';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cPrimaryDark, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: cPrimaryDark, size: 20),
              SizedBox(width: 8),
              Text('Understood',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: cPrimaryDark)),
            ],
          ),
          const SizedBox(height: 10),
          Text(reminder.title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: cDeep)),
          const SizedBox(height: 4),
          Text(
            '${reminder.hour.toString().padLeft(2, '0')}:'
            '${reminder.minute.toString().padLeft(2, '0')} ${reminder.amPm}',
            style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: cPrimaryDark),
          ),
          const SizedBox(height: 4),
          Text('$_typeLabel$_medicineLabel • ${reminder.repeatType.name}',
              style: const TextStyle(fontSize: 12, color: cMuted)),
        ],
      ),
    );
  }
}