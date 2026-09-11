import 'package:flutter/material.dart';

import '../../core/domain/app_models.dart';
import '../../core/services/alarm_service.dart';
import '../../core/theme/app_theme.dart';

class RemindersScreen extends StatefulWidget {
  final SmaranStore store;
  const RemindersScreen({super.key, required this.store});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  Future<void> _addReminder() async {
    final reminder = await showDialog<AlarmReminder>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ReminderEditorDialog(),
    );
    if (reminder == null) return;

    try {
      await AlarmService.requestPermissions();
      await AlarmService.schedule(reminder);
      widget.store.reminders.add(reminder);
      await widget.store.save();
      if (mounted) setState(() {});
      _message('Alarm scheduled using Android system time.');
    } catch (e) {
      _message('Could not schedule the alarm. Check Exact Alarm permission.', error: true);
    }
  }

  Future<void> _toggle(AlarmReminder reminder, bool active) async {
    reminder.isActive = active;
    reminder.done = false;
    if (active) {
      try {
        await AlarmService.requestPermissions();
        await AlarmService.schedule(reminder);
      } catch (_) {
        reminder.isActive = false;
        _message('Android exact-alarm permission is required.', error: true);
      }
    } else {
      await AlarmService.cancel(reminder.id);
    }
    await widget.store.save();
    if (mounted) setState(() {});
  }

  Future<void> _delete(AlarmReminder reminder) async {
    await AlarmService.cancel(reminder.id);
    widget.store.reminders.removeWhere((e) => e.id == reminder.id);
    await widget.store.save();
    if (mounted) setState(() {});
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? cDanger : cDeep),
    );
  }

  String _repeatLabel(AlarmReminder reminder) {
    switch (reminder.repeatType) {
      case RepeatType.daily:
        return 'Every day';
      case RepeatType.once:
        return 'Once';
      case RepeatType.specificDate:
        final d = reminder.specificDate;
        return d == null ? 'Specific date' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
  }

  String _typeLabel(AlarmReminder reminder) {
    switch (reminder.alarmType) {
      case AlarmType.medicine:
        return 'Medicine';
      case AlarmType.food:
        return 'Food';
      case AlarmType.memoryActivity:
        return 'Memory Activity';
      case AlarmType.customTask:
        return 'Specific Task';
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminders = [...widget.store.reminders]..sort((a, b) => a.nextSystemDateTime.compareTo(b.nextSystemDateTime));
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(title: 'Daily Routine', subtitle: 'Set reminders like an Android alarm clock.'),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _addReminder,
                  icon: const Icon(Icons.add_alarm_rounded),
                  label: const Text('Set New Alarm', style: TextStyle(fontWeight: FontWeight.w900)),
                  style: FilledButton.styleFrom(backgroundColor: cPrimaryDark),
                ),
              ),
            ),
            Expanded(
              child: reminders.isEmpty
                  ? const _EmptyReminders()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      itemCount: reminders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final reminder = reminders[index];
                        return _ReminderCard(
                          reminder: reminder,
                          repeatLabel: _repeatLabel(reminder),
                          typeLabel: _typeLabel(reminder),
                          onToggle: (value) => _toggle(reminder, value),
                          onDelete: () => _delete(reminder),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderEditorDialog extends StatefulWidget {
  const _ReminderEditorDialog();
  @override
  State<_ReminderEditorDialog> createState() => _ReminderEditorDialogState();
}

class _ReminderEditorDialogState extends State<_ReminderEditorDialog> {
  final _title = TextEditingController();
  final _detail = TextEditingController();
  TimeOfDay _time = TimeOfDay.now();
  RepeatType _repeat = RepeatType.daily;
  DateTime? _specificDate;
  AlarmType _alarmType = AlarmType.customTask;
  MedicineTiming? _medicineTiming;

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'SET ALARM TIME',
      cancelText: 'CANCEL',
      confirmText: 'OK',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      initialDate: _specificDate ?? now,
      helpText: 'SELECT ALARM DATE',
      cancelText: 'CANCEL',
      confirmText: 'SET DATE',
    );
    if (picked != null) setState(() => _specificDate = picked);
  }

  void _selectType(AlarmType type) {
    setState(() {
      _alarmType = type;
      if (type != AlarmType.medicine) _medicineTiming = null;
      if (_title.text.trim().isEmpty) {
        _title.text = switch (type) {
          AlarmType.medicine => 'Medicine',
          AlarmType.food => 'Food',
          AlarmType.memoryActivity => 'Memory Activity',
          AlarmType.customTask => '',
        };
      }
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _error('Enter what this alarm is for.');
      return;
    }
    if (_alarmType == AlarmType.medicine && _medicineTiming == null) {
      _error('Medicine alarms require Before Food or After Food.');
      return;
    }
    if (_repeat == RepeatType.specificDate && _specificDate == null) {
      _error('Select a calendar date.');
      return;
    }

    final now = DateTime.now();
    final hour24 = _time.period == DayPeriod.pm
        ? (_time.hourOfPeriod == 12 ? 12 : _time.hourOfPeriod + 12)
        : (_time.hourOfPeriod == 12 ? 0 : _time.hourOfPeriod);
    final target = _repeat == RepeatType.specificDate
        ? DateTime(_specificDate!.year, _specificDate!.month, _specificDate!.day, hour24, _time.minute)
        : DateTime(now.year, now.month, now.day, hour24, _time.minute);

    if (_repeat == RepeatType.specificDate && !target.isAfter(now)) {
      _error('That date and time has already passed.');
      return;
    }

    final reminder = AlarmReminder(
      id: DateTime.now().microsecondsSinceEpoch.remainder(2147483647),
      title: title,
      detail: _detail.text.trim(),
      hour: _time.hourOfPeriod == 0 ? 12 : _time.hourOfPeriod,
      minute: _time.minute,
      amPm: _time.period == DayPeriod.pm ? 'PM' : 'AM',
      repeatType: _repeat,
      specificDate: _specificDate,
      alarmType: _alarmType,
      medicineTiming: _medicineTiming,
    );

    Navigator.of(context).pop(reminder);
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: cDanger));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.alarm_rounded, color: cPrimaryDark),
          SizedBox(width: 10),
          Expanded(child: Text('Set Alarm', style: TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TimePickerTile(time: _time, onTap: _pickTime),
              const SizedBox(height: 16),
              const Text('Repeat', style: TextStyle(fontWeight: FontWeight.w900, color: cDeep)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    selected: _repeat == RepeatType.daily,
                    label: const Text('Daily'),
                    avatar: const Icon(Icons.repeat, size: 18),
                    onSelected: (_) => setState(() => _repeat = RepeatType.daily),
                  ),
                  ChoiceChip(
                    selected: _repeat == RepeatType.once,
                    label: const Text('Once'),
                    avatar: const Icon(Icons.looks_one_rounded, size: 18),
                    onSelected: (_) => setState(() => _repeat = RepeatType.once),
                  ),
                  ChoiceChip(
                    selected: _repeat == RepeatType.specificDate,
                    label: const Text('Specific Date'),
                    avatar: const Icon(Icons.calendar_month, size: 18),
                    onSelected: (_) async {
                      setState(() => _repeat = RepeatType.specificDate);
                      await _pickDate();
                    },
                  ),
                ],
              ),
              if (_repeat == RepeatType.specificDate) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(_specificDate == null ? 'Select Date' : '${_specificDate!.day}/${_specificDate!.month}/${_specificDate!.year}'),
                ),
              ],
              const SizedBox(height: 18),
              const Text('Alarm Type', style: TextStyle(fontWeight: FontWeight.w900, color: cDeep)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AlarmType.values.map((type) {
                  final selected = type == _alarmType;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(_alarmTypeLabel(type)),
                    avatar: Icon(_alarmTypeIcon(type), size: 18),
                    onSelected: (_) => _selectType(type),
                  );
                }).toList(),
              ),
              if (_alarmType == AlarmType.medicine) ...[
                const SizedBox(height: 16),
                const Text('When?', style: TextStyle(fontWeight: FontWeight.w900, color: cDeep)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      selected: _medicineTiming == MedicineTiming.beforeFood,
                      label: const Text('Before Food'),
                      onSelected: (_) => setState(() => _medicineTiming = MedicineTiming.beforeFood),
                    ),
                    ChoiceChip(
                      selected: _medicineTiming == MedicineTiming.afterFood,
                      label: const Text('After Food'),
                      onSelected: (_) => setState(() => _medicineTiming = MedicineTiming.afterFood),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TextField(controller: _title, decoration: inputDec('Task / Reminder name *')),
              const SizedBox(height: 12),
              TextField(controller: _detail, maxLines: 2, decoration: inputDec('Notes / details')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.alarm_add_rounded), label: const Text('Save Alarm')),
      ],
    );
  }

  String _alarmTypeLabel(AlarmType type) => switch (type) {
        AlarmType.medicine => 'Medicine',
        AlarmType.food => 'Food',
        AlarmType.memoryActivity => 'Memory Activity',
        AlarmType.customTask => 'Specific Task',
      };

  IconData _alarmTypeIcon(AlarmType type) => switch (type) {
        AlarmType.medicine => Icons.medication_rounded,
        AlarmType.food => Icons.restaurant_rounded,
        AlarmType.memoryActivity => Icons.psychology_rounded,
        AlarmType.customTask => Icons.task_alt_rounded,
      };
}

class _TimePickerTile extends StatelessWidget {
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimePickerTile({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.pm ? 'PM' : 'AM';
    return Material(
      color: cDeep,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.access_time_filled_rounded, color: cSoft, size: 34),
              const SizedBox(width: 16),
              Text('$hour:${minute.padLeft(2, '0')}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              Text(period, style: const TextStyle(color: cSoft, fontSize: 20, fontWeight: FontWeight.w900)),
              const Spacer(),
              const Icon(Icons.edit_rounded, color: cSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final AlarmReminder reminder;
  final String repeatLabel;
  final String typeLabel;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _ReminderCard({
    required this.reminder,
    required this.repeatLabel,
    required this.typeLabel,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final medicine = reminder.alarmType == AlarmType.medicine && reminder.medicineTiming != null
        ? ' • ${reminder.medicineTiming == MedicineTiming.beforeFood ? 'Before food' : 'After food'}'
        : '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: cSoft, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.alarm_rounded, color: cPrimaryDark, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: cText)),
                const SizedBox(height: 4),
                Text('${reminder.hour.toString().padLeft(2, '0')}:${reminder.minute.toString().padLeft(2, '0')} ${reminder.amPm}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: cPrimaryDark)),
                const SizedBox(height: 3),
                Text('$typeLabel • $repeatLabel$medicine', style: const TextStyle(color: cMuted, fontSize: 12.5, fontWeight: FontWeight.w700)),
                if (reminder.detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(reminder.detail, style: const TextStyle(color: cMuted)),
                ],
              ],
            ),
          ),
          Column(
            children: [
              Switch(value: reminder.isActive, onChanged: onToggle),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: cDanger)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyReminders extends StatelessWidget {
  const _EmptyReminders();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.alarm_add_rounded, size: 64, color: cPrimaryDark),
              SizedBox(height: 12),
              Text('No alarms yet', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: cDeep)),
              SizedBox(height: 6),
              Text('Create a medicine, food, memory activity or custom task alarm.', textAlign: TextAlign.center, style: TextStyle(color: cMuted, height: 1.4)),
            ],
          ),
        ),
      );
}
