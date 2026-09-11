import 'package:flutter/material.dart';

import '../../core/domain/app_models.dart';
import '../../core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final SmaranStore store;
  final ValueChanged<String> onNavigate;
  final ValueChanged<String> onOpenFeature;

  const HomeScreen({
    super.key,
    required this.store,
    required this.onNavigate,
    required this.onOpenFeature,
  });

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(store: store, greeting: greeting, onProfile: () => onNavigate('profile')),
              const SizedBox(height: 14),
              _WelcomeCard(store: store),
              const SizedBox(height: 16),
              const Text('Your Smaran space', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cDeep)),
              const SizedBox(height: 10),
              _FourMainTabs(
                onOpen: onOpenFeature,
              ),
              const SizedBox(height: 16),
              _TodayPlan(store: store, onOpenReminders: () => onOpenFeature('reminders')),
              const SizedBox(height: 16),
              _QuickActions(onOpenFeature: onOpenFeature, onNavigate: onNavigate),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final SmaranStore store;
  final String greeting;
  final VoidCallback onProfile;
  const _Header({required this.store, required this.greeting, required this.onProfile});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Logo(size: 50),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SMARAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2, color: cPrimaryDark)),
                Text(greeting, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: cDeep)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: onProfile,
            icon: const Icon(Icons.person_outline_rounded, size: 29, color: cDeep),
          ),
        ],
      );
}

class _WelcomeCard extends StatelessWidget {
  final SmaranStore store;
  const _WelcomeCard({required this.store});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: cDeep, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hello,', style: TextStyle(color: cMint, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(store.patientName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  const Text('Let’s make today calm, familiar and meaningful.', style: TextStyle(color: Color(0xFFD8E9DE), fontSize: 12.5, height: 1.35)),
                ],
              ),
            ),
            const CircleAvatar(radius: 34, backgroundColor: cSoft, child: Icon(Icons.favorite_rounded, size: 36, color: cPrimaryDark)),
          ],
        ),
      );
}

class _FourMainTabs extends StatelessWidget {
  final ValueChanged<String> onOpen;
  const _FourMainTabs({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('games', 'Daily Task', '🧠', cSoft),
      ('talk', 'Memory Garden', '☁', Color(0xFFF6DCDD)),
      ('photos', 'Memory Lane', '🛤', Color(0xFFDCECF2)),
      ('reminders', 'Scheduled', '🗓', Color(0xFFF5E6C7)),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _MainTab(
              title: items[i].$2,
              icon: items[i].$3,
              color: items[i].$4,
              onTap: () => onOpen(items[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _MainTab extends StatelessWidget {
  final String title;
  final String icon;
  final Color color;
  final VoidCallback onTap;
  const _MainTab({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 104),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 11),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, height: 1.1, fontWeight: FontWeight.w900, color: cText),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _TodayPlan extends StatelessWidget {
  final SmaranStore store;
  final VoidCallback onOpenReminders;
  const _TodayPlan({required this.store, required this.onOpenReminders});

  @override
  Widget build(BuildContext context) {
    final active = store.reminders.where((e) => e.isActive && !e.done).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: cWhite, borderRadius: BorderRadius.circular(20), border: Border.all(color: cBorder)),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: cSoft, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.today_rounded, color: cPrimaryDark)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today’s Plan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: cDeep)),
                const SizedBox(height: 3),
                Text(active.isEmpty ? 'No active alarms' : '${active.length} active alarm${active.length == 1 ? '' : 's'}', style: const TextStyle(color: cMuted, fontSize: 12.5)),
              ],
            ),
          ),
          TextButton(onPressed: onOpenReminders, child: const Text('Open')),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final ValueChanged<String> onOpenFeature;
  final ValueChanged<String> onNavigate;
  const _QuickActions({required this.onOpenFeature, required this.onNavigate});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _QuickAction(icon: '🧠', label: 'Games', onTap: () => onOpenFeature('games'))),
          const SizedBox(width: 10),
          Expanded(child: _QuickAction(icon: '💬', label: 'Talking Help', onTap: () => onOpenFeature('talk'))),
          const SizedBox(width: 10),
          Expanded(child: _QuickAction(icon: '👨‍👩‍👧', label: 'Family', onTap: () => onNavigate('family'))),
        ],
      );
}

class _QuickAction extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: cWhite,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Column(
              children: [
                Text(icon, style: const TextStyle(fontSize: 23)),
                const SizedBox(height: 4),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cText)),
              ],
            ),
          ),
        ),
      );
}
