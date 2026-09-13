import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/domain/app_models.dart';
import '../../core/services/alarm_service.dart';
import '../reminders/reminder_screen.dart';

// =============================================================================
// Design tokens
// =============================================================================
const _cBg = Color(0xFFFEF7E8);
const _cWhite = Color(0xFFFFFDFC);
const _cPrimaryDark = Color(0xFF4F743D);
const _cPrimarySoft = Color(0xFFE5F0D8);
const _cText = Color(0xFF26332E);
const _cMuted = Color(0xFF6D746E);
const _cDanger = Color(0xFFC64A4A);
const _cRemindButton = Color(0xFFE49A1E);
const _cDoneButton = Color(0xFF4F9A42);
const _shadowColor = Color(0x1A7A694E);

// =============================================================================
// Feature tile data
// =============================================================================
class _FeatureItem {
  final String key;
  final String iconAsset;
  final String title;
  final String subtitle;
  final Color background;
  final String route;
  const _FeatureItem({
    required this.key,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.route,
  });
}

const _featureData = <_FeatureItem>[
  _FeatureItem(
    key: 'daily',
    iconAsset: 'assets/icons/daily_task.svg',
    title: 'Your Daily Task',
    subtitle: 'Cognitive Memory Game (0/5)',
    background: _cPrimarySoft,
    route: 'games',
  ),
  _FeatureItem(
    key: 'garden',
    iconAsset: 'assets/icons/memory_garden.svg',
    title: 'Memory Garden',
    subtitle: 'Memory Assistant',
    background: Color(0xFFF6DCDD),
    route: 'talk',
  ),
  _FeatureItem(
    key: 'lane',
    iconAsset: 'assets/icons/take_a_trip_down_to_your_memory-lane.svg',
    title: 'Take a Trip Down Your Memory Lane',
    subtitle: 'Your Past Memories',
    background: Color(0xFFDCECF2),
    route: 'photos',
  ),
  _FeatureItem(
    key: 'scheduled',
    iconAsset: 'assets/icons/scheduled.svg',
    title: 'Scheduled',
    subtitle: 'Your Daily Routine',
    background: Color(0xFFF5E6C7),
    route: 'reminders',
  ),
];

// =============================================================================
// HOME SCREEN
// =============================================================================
class HomeScreen extends StatefulWidget {
  final SmaranStore store;
  final ValueChanged<String> onNavigate;
  final ValueChanged<String> onOpenFeature;

  const HomeScreen({
    super.key,
    required this.store,
    required this.onNavigate,
    required this.onOpenFeature,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _imagePicker = ImagePicker();
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() async {
    await Future.delayed(const Duration(seconds: 30));
    if (!mounted) return;
    setState(() => _now = DateTime.now());
    _tick();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Derived values ───────────────────────────────────────────
  String get _firstName {
    final raw = widget.store.patientName.trim();
    if (raw.isEmpty) return 'Patient';
    return raw.split(RegExp(r'\s+')).first;
  }

  String get _greeting {
    final h = _now.hour;
    if (h >= 5 && h < 12) return 'Good Morning';
    if (h >= 12 && h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  bool get _isDaytime => _now.hour >= 6 && _now.hour < 18;

  String get _formattedDate {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${weekdays[_now.weekday - 1]}, '
        '${months[_now.month - 1]} ${_now.day}, ${_now.year}';
  }

  List<AlarmReminder> get _activeReminders {
    final list = widget.store.reminders
        .where((r) => r.isActive && !r.done)
        .toList();
    list.sort((a, b) => a.nextSystemDateTime.compareTo(b.nextSystemDateTime));
    return list;
  }

  List<AlarmReminder> get _todayPlan => _activeReminders.take(2).toList();
  int get _pendingCount => _activeReminders.length;
  int get _completedGamesCount =>
      widget.store.reminders.where((r) => r.done).length.clamp(0, 5);

  // ── Actions ──────────────────────────────────────────────────
  Future<void> _openReminders() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RemindersScreen(store: widget.store)),
    );
    if (mounted) setState(() {});
  }

  void _handleFeaturePress(_FeatureItem item) {
    switch (item.route) {
      case 'games':
        widget.onOpenFeature('games');
        break;
      case 'talk':
        widget.onOpenFeature('talk');
        break;
      case 'photos':
        widget.onNavigate('photos');
        break;
      case 'reminders':
        _openReminders();
        break;
    }
  }

  void _handleMicrophone() => widget.onOpenFeature('talk');

  Future<void> _handleCamera() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (!mounted || image == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo captured. Smaran can use it for memory search.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera is not available right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Toggle done ↔ pending.
  ///
  /// When marked done:
  ///   - reminder.done = true
  ///   - reminder.isActive = false  ← so Reminders screen switch flips OFF
  ///   - alarm cancelled
  ///
  /// When un-marked:
  ///   - reminder.done = false
  ///   - reminder.isActive = true   ← so Reminders screen switch flips ON
  ///   - alarm rescheduled
  Future<void> _toggleReminder(AlarmReminder reminder) async {
    final markDone = !reminder.done;

    reminder.done = markDone;
    // Sync the active flag too, so Reminders screen stays in sync.
    reminder.isActive = !markDone;

    if (markDone) {
      await AlarmService.cancel(reminder.id);
    } else {
      try {
        await AlarmService.schedule(reminder);
      } catch (_) {}
    }

    await widget.store.save();
    if (!mounted) return;
    setState(() {});

    if (markDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Great! "${reminder.title}" marked as done.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _cPrimaryDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;
    final scale = math.min(w / 449.0, h / 900.0).clamp(0.92, 1.10);

    return Scaffold(
      backgroundColor: _cBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16 * scale, 14 * scale, 16 * scale, 20 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnimatedEntry(
                delayMs: 40,
                child: _Header(
                  scale: scale,
                  firstName: _firstName,
                  greeting: _greeting,
                  isDaytime: _isDaytime,
                  date: _formattedDate,
                  pendingCount: _pendingCount,
                  onBellTap: _openReminders,
                ),
              ),

              _FeatureGrid(
                scale: scale,
                items: _featureData,
                onTap: _handleFeaturePress,
              ),

              SizedBox(height: 17 * scale),

              _AnimatedEntry(
                delayMs: 570,
                child: _ProgressBanner(
                  scale: scale,
                  completed: _completedGamesCount,
                  total: 5,
                  onTap: () => widget.onOpenFeature('games'),
                ),
              ),

              SizedBox(height: 20 * scale),

              _AnimatedEntry(
                delayMs: 650,
                child: _PlanHeader(
                  scale: scale,
                  onFullSchedule: _openReminders,
                ),
              ),

              SizedBox(height: 10 * scale),

              if (_todayPlan.isEmpty)
                _AnimatedEntry(
                  delayMs: 720,
                  child: _EmptyPlan(scale: scale, onAdd: _openReminders),
                )
              else
                for (int i = 0; i < _todayPlan.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: 6 * scale),
                    child: _AnimatedEntry(
                      delayMs: 720 + (i * 100),
                      child: _PlanCard(
                        scale: scale,
                        reminder: _todayPlan[i],
                        onToggle: () => _toggleReminder(_todayPlan[i]),
                      ),
                    ),
                  ),

              // Tight gap — no more floating whitespace above composer
              SizedBox(height: 6 * scale),

              _AnimatedEntry(
                delayMs: 900,
                child: _AiReminderSection(
                  scale: scale,
                  controller: _searchController,
                  onMicrophone: _handleMicrophone,
                  onCamera: _handleCamera,
                  onSubmit: (_) => widget.onOpenFeature('talk'),
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
// Animated entry wrapper
// =============================================================================
class _AnimatedEntry extends StatefulWidget {
  final int delayMs;
  final Widget child;

  const _AnimatedEntry({
    required this.child,
    this.delayMs = 0,
  });

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (_, child) => Opacity(
          opacity: _opacity.value,
          child: FractionalTranslation(
            translation: _slide.value,
            child: child,
          ),
        ),
        child: widget.child,
      );
}

// =============================================================================
// HEADER
// =============================================================================
class _Header extends StatelessWidget {
  final double scale;
  final String firstName;
  final String greeting;
  final bool isDaytime;
  final String date;
  final int pendingCount;
  final VoidCallback onBellTap;

  const _Header({
    required this.scale,
    required this.firstName,
    required this.greeting,
    required this.isDaytime,
    required this.date,
    required this.pendingCount,
    required this.onBellTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hello,',
                style: TextStyle(
                  fontSize: 31 * scale,
                  height: 36 / 31,
                  fontWeight: FontWeight.w700,
                  color: _cText,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(
                height: 45 * scale,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      firstName,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 40 * scale,
                        height: 45 / 40,
                        fontWeight: FontWeight.w900,
                        color: _cPrimaryDark,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 7 * scale),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18 * scale,
                        height: 23 / 18,
                        fontWeight: FontWeight.w800,
                        color: _cText,
                      ),
                    ),
                  ),
                  SizedBox(width: 7 * scale),
                  Text(
                    isDaytime ? '☀️' : '🌙',
                    style: TextStyle(fontSize: 19 * scale),
                  ),
                ],
              ),
              SizedBox(height: 2 * scale),
              Text(
                date,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12 * scale,
                  height: 17 / 12,
                  fontWeight: FontWeight.w600,
                  color: _cMuted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 10 * scale),
        Material(
          color: _cWhite,
          borderRadius: BorderRadius.circular(20 * scale),
          elevation: 3,
          shadowColor: _shadowColor,
          child: InkWell(
            onTap: onBellTap,
            borderRadius: BorderRadius.circular(20 * scale),
            child: SizedBox(
              width: 57 * scale,
              height: 57 * scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 29 * scale,
                    color: _cPrimaryDark,
                  ),
                  if (pendingCount > 0)
                    Positioned(
                      right: 5 * scale,
                      top: 4 * scale,
                      child: Container(
                        constraints: BoxConstraints(
                          minWidth: 19 * scale,
                          minHeight: 19 * scale,
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 4 * scale),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _cDanger,
                          borderRadius: BorderRadius.circular(10 * scale),
                          border: Border.all(color: _cWhite, width: 1.5),
                        ),
                        child: Text(
                          pendingCount > 9 ? '9' : '$pendingCount',
                          style: TextStyle(
                            fontSize: 9 * scale,
                            color: _cWhite,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// FEATURE GRID
// =============================================================================
class _FeatureGrid extends StatelessWidget {
  final double scale;
  final List<_FeatureItem> items;
  final ValueChanged<_FeatureItem> onTap;

  const _FeatureGrid({
    required this.scale,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 4 * scale : 12 * scale),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _AnimatedEntry(
                    delayMs: 160 + (i * 90),
                    child: _FeatureTile(
                      scale: scale,
                      item: items[i],
                      onTap: () => onTap(items[i]),
                    ),
                  ),
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: i + 1 < items.length
                      ? _AnimatedEntry(
                          delayMs: 160 + ((i + 1) * 90),
                          child: _FeatureTile(
                            scale: scale,
                            item: items[i + 1],
                            onTap: () => onTap(items[i + 1]),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final double scale;
  final _FeatureItem item;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.scale,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cWhite,
      elevation: 3,
      shadowColor: _shadowColor,
      borderRadius: BorderRadius.circular(21 * scale),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21 * scale),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 142 * scale),
          child: Padding(
            padding: EdgeInsets.all(14 * scale),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46 * scale,
                      height: 46 * scale,
                      decoration: BoxDecoration(
                        color: item.background,
                        borderRadius: BorderRadius.circular(16 * scale),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(11 * scale),
                        child: SvgPicture.asset(
                          item.iconAsset,
                          colorFilter: const ColorFilter.mode(
                            _cPrimaryDark,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 11 * scale),
                    Padding(
                      padding: EdgeInsets.only(right: 16 * scale),
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16 * scale,
                          height: 20 / 16,
                          fontWeight: FontWeight.w900,
                          color: _cText,
                        ),
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Padding(
                      padding: EdgeInsets.only(right: 5 * scale),
                      child: Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5 * scale,
                          height: 14 / 10.5,
                          fontWeight: FontWeight.w600,
                          color: _cMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Text(
                    '›',
                    style: TextStyle(
                      fontSize: 27 * scale,
                      height: 1,
                      color: _cText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PROGRESS BANNER
// =============================================================================
class _ProgressBanner extends StatelessWidget {
  final double scale;
  final int completed;
  final int total;
  final VoidCallback onTap;

  const _ProgressBanner({
    required this.scale,
    required this.completed,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE2F1D6),
      borderRadius: BorderRadius.circular(21 * scale),
      elevation: 3,
      shadowColor: _shadowColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21 * scale),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 78 * scale),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12 * scale),
            child: Row(
              children: [
                Container(
                  width: 51 * scale,
                  height: 51 * scale,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD8EAC9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite_border_rounded,
                    size: 27 * scale,
                    color: _cPrimaryDark,
                  ),
                ),
                SizedBox(width: 10 * scale),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: 5 * scale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Great job! You completed $completed of $total games today.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14 * scale,
                            height: 18 / 14,
                            fontWeight: FontWeight.w900,
                            color: _cPrimaryDark,
                          ),
                        ),
                        SizedBox(height: 2 * scale),
                        Text(
                          'Keep your mind active with a little practice.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10 * scale,
                            height: 14 / 10,
                            fontWeight: FontWeight.w700,
                            color: _cMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  '›',
                  style: TextStyle(
                    fontSize: 30 * scale,
                    height: 1,
                    color: _cPrimaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TODAY'S PLAN HEADER
// =============================================================================
class _PlanHeader extends StatelessWidget {
  final double scale;
  final VoidCallback onFullSchedule;

  const _PlanHeader({required this.scale, required this.onFullSchedule});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            "Today's Plan",
            style: TextStyle(
              fontSize: 26 * scale,
              height: 31 / 26,
              fontWeight: FontWeight.w900,
              color: _cText,
            ),
          ),
        ),
        InkWell(
          onTap: onFullSchedule,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 7 * scale,
              vertical: 5 * scale,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18 * scale,
                  color: _cPrimaryDark,
                ),
                SizedBox(width: 5 * scale),
                Text(
                  'Full Schedule',
                  style: TextStyle(
                    fontSize: 11 * scale,
                    color: _cPrimaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// PLAN CARD — thin & clean
// =============================================================================
class _PlanCard extends StatelessWidget {
  final double scale;
  final AlarmReminder reminder;
  final VoidCallback onToggle;

  const _PlanCard({
    required this.scale,
    required this.reminder,
    required this.onToggle,
  });

  String get _timeLabel {
    var hour = reminder.hour;
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    return '$hour:${reminder.minute.toString().padLeft(2, '0')} '
        '${reminder.amPm.toUpperCase()}';
  }

  String get _detailLabel {
    final d = reminder.detail.trim();
    if (d.isEmpty) return 'Smaran reminder';
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final isDone = reminder.done;

    return SizedBox(
      // Thin card
      height: 68 * scale,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: _cWhite,
                borderRadius: BorderRadius.circular(14 * scale),
                boxShadow: const [
                  BoxShadow(
                    color: _shadowColor,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 10 * scale,
                vertical: 6 * scale,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left circular icon — smaller
                  Container(
                    width: 38 * scale,
                    height: 38 * scale,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE3F0D7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDone
                          ? Icons.check_rounded
                          : Icons.access_time_rounded,
                      size: 18 * scale,
                      color: _cPrimaryDark,
                    ),
                  ),
                  SizedBox(width: 10 * scale),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 92 * scale),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _timeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9 * scale,
                              height: 12 / 9,
                              fontWeight: FontWeight.w700,
                              color: _cMuted,
                            ),
                          ),
                          SizedBox(height: 1 * scale),
                          Text(
                            reminder.title.isEmpty
                                ? 'Reminder'
                                : reminder.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13 * scale,
                              height: 16 / 13,
                              fontWeight: FontWeight.w900,
                              color: isDone ? _cMuted : _cText,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          SizedBox(height: 1 * scale),
                          Text(
                            _detailLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8.5 * scale,
                              height: 11 / 8.5,
                              color: _cMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right button — thin pill
          Positioned(
            top: 16 * scale,
            right: 10 * scale,
            bottom: 16 * scale,
            width: 80 * scale,
            child: Material(
              color: isDone ? _cDoneButton : _cRemindButton,
              borderRadius: BorderRadius.circular(11 * scale),
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(11 * scale),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDone
                            ? Icons.check_circle_rounded
                            : Icons.notifications_none_rounded,
                        size: 12 * scale,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4 * scale),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isDone ? "I'm Done" : 'Remind Me',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 9.5 * scale,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EMPTY PLAN
// =============================================================================
class _EmptyPlan extends StatelessWidget {
  final double scale;
  final VoidCallback onAdd;

  const _EmptyPlan({required this.scale, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cWhite,
      borderRadius: BorderRadius.circular(16 * scale),
      elevation: 3,
      shadowColor: _shadowColor,
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(16 * scale),
        child: Padding(
          padding: EdgeInsets.all(11 * scale),
          child: Row(
            children: [
              Container(
                width: 42 * scale,
                height: 42 * scale,
                decoration: const BoxDecoration(
                  color: _cPrimarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  size: 20 * scale,
                  color: _cPrimaryDark,
                ),
              ),
              SizedBox(width: 10 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nothing scheduled yet',
                      style: TextStyle(
                        fontSize: 13.5 * scale,
                        fontWeight: FontWeight.w900,
                        color: _cText,
                      ),
                    ),
                    SizedBox(height: 2 * scale),
                    Text(
                      "Add a reminder to build today's plan.",
                      style: TextStyle(
                        fontSize: 9.5 * scale,
                        height: 13 / 9.5,
                        color: _cMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '›',
                style: TextStyle(
                  fontSize: 24 * scale,
                  height: 1,
                  color: _cPrimaryDark,
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
// AI REMINDER SECTION
// =============================================================================
class _AiReminderSection extends StatelessWidget {
  final double scale;
  final TextEditingController controller;
  final VoidCallback onMicrophone;
  final VoidCallback onCamera;
  final ValueChanged<String> onSubmit;

  const _AiReminderSection({
    required this.scale,
    required this.controller,
    required this.onMicrophone,
    required this.onCamera,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cWhite,
      borderRadius: BorderRadius.circular(31 * scale),
      elevation: 3,
      shadowColor: _shadowColor,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(31 * scale),
          border: Border.all(color: const Color(0xFFE8E1D5)),
        ),
        padding: EdgeInsets.only(
          left: 13 * scale,
          right: 6 * scale,
          top: 4 * scale,
          bottom: 4 * scale,
        ),
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 23 * scale,
              color: _cPrimaryDark,
            ),
            SizedBox(width: 8 * scale),
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: onSubmit,
                textInputAction: TextInputAction.send,
                style: TextStyle(fontSize: 15 * scale, color: _cText),
                decoration: InputDecoration(
                  hintText: 'Ask me about your reminders...',
                  hintStyle: TextStyle(fontSize: 14 * scale, color: _cMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12 * scale),
                ),
              ),
            ),
            _ComposerActionButton(
              icon: Icons.mic_none_rounded,
              background: const Color(0xFFE5F2DA),
              border: const Color(0xFFD4E5C8),
              scale: scale,
              onTap: onMicrophone,
            ),
            SizedBox(width: 4 * scale),
            _ComposerActionButton(
              icon: Icons.camera_alt_outlined,
              background: const Color(0xFFF7F8F1),
              border: const Color(0xFFE0E6D8),
              scale: scale,
              onTap: onCamera,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerActionButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color border;
  final double scale;
  final VoidCallback onTap;

  const _ComposerActionButton({
    required this.icon,
    required this.background,
    required this.border,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44 * scale,
          height: 44 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: border),
          ),
          child: Icon(icon, size: 22 * scale, color: _cPrimaryDark),
        ),
      ),
    );
  }
}