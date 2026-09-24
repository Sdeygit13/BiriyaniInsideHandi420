import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/auth/auth_store.dart';
import '../../core/domain/app_models.dart';
import '../../core/services/caregiver_analytics.dart';
import '../../core/theme/caregiver_theme.dart';

class CaregiverReportsScreen extends StatelessWidget {
  final SmaranStore store;
  const CaregiverReportsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final games = CaregiverAnalytics.gamesPlayedThisWeek(store);
    final (done, total) = CaregiverAnalytics.remindersToday(store);
    final compliance = CaregiverAnalytics.reminderCompliancePercent(store);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Care Report',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: CG.primary,
            ),
          ),
          const SizedBox(height: 4),
          const Text('20 Sep 2025 – 26 Sep 2025',
              style: TextStyle(fontSize: 12, color: CG.textMuted)),
          const SizedBox(height: 16),

          // Metric tiles
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  value: '$games',
                  label: 'Games This Week',
                  bg: CG.gamesBg,
                  fg: CG.gamesFg,
                  icon: Icons.sports_esports_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  value: '$compliance%',
                  label: 'Reminder Compliance',
                  bg: CG.medicineBg,
                  fg: CG.medicineFg,
                  icon: Icons.check_circle_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  value: '$done/$total',
                  label: 'Meds Today',
                  bg: CG.hydrationBg,
                  fg: CG.hydrationFg,
                  icon: Icons.medication_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  value: '76%',
                  label: 'Hydration',
                  bg: CG.moodBg,
                  fg: CG.moodFg,
                  icon: Icons.local_drink_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Actions
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _download(context),
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text(
                'Download Report',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: CG.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.share_rounded,
                  size: 20, color: CG.primary),
              label: const Text(
                'Share with Doctor',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: CG.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: CG.primary, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    final patients = AuthStore.instance.linkedPatients;
    final caregiver = AuthStore.instance.currentUser;
    if (patients.isEmpty || caregiver == null) return;

    final p = patients.first;
    final buffer = StringBuffer()
      ..writeln('SMARAN — WEEKLY REPORT')
      ..writeln('Patient: ${p.fullName}')
      ..writeln('Caregiver: ${caregiver.fullName}')
      ..writeln('Generated: ${DateTime.now()}')
      ..writeln('')
      ..writeln(
          'Games week: ${CaregiverAnalytics.gamesPlayedThisWeek(store)}')
      ..writeln(
          'Compliance: ${CaregiverAnalytics.reminderCompliancePercent(store)}%');

    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File(
          '${dir.path}/smaran_report_${DateTime.now().millisecondsSinceEpoch}.txt');
      await f.writeAsString(buffer.toString());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: ${f.path.split('/').last}'),
          backgroundColor: CG.primary,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not save.'),
            backgroundColor: CG.danger),
      );
    }
  }
}

class _MetricTile extends StatelessWidget {
  final String value;
  final String label;
  final Color bg;
  final Color fg;
  final IconData icon;

  const _MetricTile({
    required this.value,
    required this.label,
    required this.bg,
    required this.fg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: fg.withValues(alpha: 0.85),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}