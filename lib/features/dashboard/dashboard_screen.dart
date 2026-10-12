import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/states.dart';
import '../attendance/attendance_repository.dart';
import '../auth/auth_controller.dart';
import '../exams/exams_repository.dart';
import '../fees/fees_repository.dart';
import '../notices/notices_repository.dart';
import '../notices/notices_screen.dart';
import '../profile/profile_screen.dart';
import '../results/results_repository.dart';
import '../results/results_screen.dart';
import '../shell/notification_bell.dart';
import '../timetable/lesson_tile.dart';
import '../timetable/timetable_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _refresh(WidgetRef ref) async {
    final day = today();
    ref.invalidate(attendanceProvider((from: day, to: day)));
    ref.invalidate(examsProvider);
    ref.invalidate(reportCardsProvider);
    ref.invalidate(recentNoticesProvider);
    ref.invalidate(feeStatementProvider);
    try {
      await ref.read(authControllerProvider.notifier).reload();
    } catch (_) {
      // The header keeps the last known profile; sections show their own errors.
    }
    return ref.refresh(dayTimetableProvider(day).future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final student = auth.student;
    if (student == null) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(
        title: Text(auth.user?.organizationName ?? 'Student Portal', overflow: TextOverflow.ellipsis),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: pagePadding(context),
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(greeting: _greeting()),
                const SizedBox(height: 16),
                const _QuickActions(),
                const SizedBox(height: 16),
                const ResponsiveColumns(children: [
                  _TodayClasses(),
                  _TodayAttendance(),
                  _UpcomingExams(),
                  _LatestResult(),
                  _RecentNotices(),
                  _FeesSummary(),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.greeting});
  final String greeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = ref.watch(authControllerProvider.select((s) => s.student))!;
    final e = student.enrollment;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brand, Color(0xFF3B57B3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go('/profile'),
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: StudentAvatar(initials: student.initials, radius: 30),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$greeting,', style: const TextStyle(color: Colors.white70)),
                  Text(
                    student.firstName.isNotEmpty ? student.firstName : student.fullName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _Pill('ID ${student.studentNumber}'),
                    _Pill(classLabel(e)),
                    if (e?.academicYearName != null) _Pill(e!.academicYearName!),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _items = [
    (Icons.fact_check_outlined, 'Attendance', '/attendance'),
    (Icons.schedule_outlined, 'Timetable', '/timetable'),
    (Icons.event_note_outlined, 'Exams', '/results?tab=exams'),
    (Icons.workspace_premium_outlined, 'Results', '/results'),
    (Icons.campaign_outlined, 'Notices', '/notices'),
    (Icons.receipt_long_outlined, 'Fees', '/fees'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 720 ? 6 : 3;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (icon, label, route) in _items)
            SizedBox(
              width: width,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.go(route),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
                        child: Icon(icon, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(label, style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _TodayClasses extends ConsumerWidget {
  const _TodayClasses();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = today();
    final lessons = ref.watch(dayTimetableProvider(day));
    return SectionCard(
      title: 'Today\'s classes',
      icon: Icons.schedule_outlined,
      actionLabel: 'Timetable',
      onAction: () => context.go('/timetable'),
      child: AsyncValueView(
        value: lessons,
        compact: true,
        onRetry: () => ref.invalidate(dayTimetableProvider(day)),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(icon: Icons.free_breakfast_outlined, title: 'No classes today.', compact: true);
          }
          final mark = currentOrNext(items, day);
          final now = DateTime.now();
          final minutes = now.hour * 60 + now.minute;
          final allDone = mark == null && items.every((l) => l.isOff || (l.endMinutes ?? 0) <= minutes);
          if (allDone) {
            return EmptyView(
              icon: Icons.check_circle_outline,
              title: 'Classes are over for today (${items.where((l) => !l.isOff).length} held).',
              compact: true,
            );
          }
          // Show from the current/next lesson on, up to four.
          final start = mark?.$1 ?? 0;
          final visible = items.skip(start).take(4).toList();
          return Column(children: [
            for (var i = 0; i < visible.length; i++)
              LessonTile(lesson: visible[i], dense: true, moment: (mark != null && i == 0) ? mark.$2 : null),
            if (items.length - start > visible.length)
              Text('+${items.length - start - visible.length} more', style: Theme.of(context).textTheme.bodySmall),
          ]);
        },
      ),
    );
  }
}

class _TodayAttendance extends ConsumerWidget {
  const _TodayAttendance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = today();
    final report = ref.watch(attendanceProvider((from: day, to: day)));
    return SectionCard(
      title: 'Today\'s attendance',
      icon: Icons.fact_check_outlined,
      actionLabel: 'History',
      onAction: () => context.go('/attendance'),
      child: AsyncValueView(
        value: report,
        compact: true,
        onRetry: () => ref.invalidate(attendanceProvider((from: day, to: day))),
        data: (r) {
          final mark = r.dayMarks[day];
          if (mark == null) {
            return const EmptyView(icon: Icons.hourglass_empty, title: 'Not marked yet today.', compact: true);
          }
          final lessons = r.records.where((x) => !x.isDaily).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(mark.icon, color: mark.color, size: 28),
                const SizedBox(width: 10),
                Text(mark.label, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: mark.color)),
              ]),
              if (lessons.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final l in lessons)
                    if (l.mark != null) StatusChip(label: '${l.subjectName}: ${l.mark!.label}', color: l.mark!.color),
                ]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _UpcomingExams extends ConsumerWidget {
  const _UpcomingExams();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(examsProvider);
    final now = today();
    return SectionCard(
      title: 'Upcoming exams',
      icon: Icons.event_note_outlined,
      actionLabel: 'Schedule',
      onAction: () => context.go('/results?tab=exams'),
      child: AsyncValueView(
        value: exams,
        compact: true,
        onRetry: () => ref.invalidate(examsProvider),
        data: (items) {
          final upcoming = items.where((e) => e.isUpcoming(now)).take(2).toList();
          if (upcoming.isEmpty) {
            return const EmptyView(icon: Icons.event_available_outlined, title: 'No upcoming exams.', compact: true);
          }
          return Column(children: [
            for (final e in upcoming)
              Builder(builder: (context) {
                final next = e.remainingPapers(now).firstOrNull;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.name),
                  subtitle: Text(next == null
                      ? formatDate(e.startDate)
                      : 'Next: ${next.subjectName}, ${formatWeekdayDate(next.date)}'
                          '${next.startMinutes == null ? '' : ' at ${formatMinutes(next.startMinutes)}'}'),
                  trailing: (next?.date ?? e.startDate) == null
                      ? null
                      : StatusChip(label: relativeDays((next?.date ?? e.startDate)!, now: now), color: AppColors.brand),
                  onTap: () => context.go('/results?tab=exams'),
                );
              }),
          ]);
        },
      ),
    );
  }
}

class _LatestResult extends ConsumerWidget {
  const _LatestResult();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(reportCardsProvider);
    return SectionCard(
      title: 'Latest result',
      icon: Icons.workspace_premium_outlined,
      actionLabel: 'All results',
      onAction: () => context.go('/results'),
      child: AsyncValueView(
        value: cards,
        compact: true,
        onRetry: () => ref.invalidate(reportCardsProvider),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(icon: Icons.hourglass_empty, title: 'No published results yet.', compact: true);
          }
          final c = items.first;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ResultTile(card: c, onTap: () => context.push('/results/${c.resultId}')),
          );
        },
      ),
    );
  }
}

class _RecentNotices extends ConsumerWidget {
  const _RecentNotices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(recentNoticesProvider);
    return SectionCard(
      title: 'Notices',
      icon: Icons.campaign_outlined,
      actionLabel: 'See all',
      onAction: () => context.go('/notices'),
      child: AsyncValueView(
        value: notices,
        compact: true,
        onRetry: () => ref.invalidate(recentNoticesProvider),
        data: (items) {
          if (items.isEmpty) return const EmptyView(icon: Icons.campaign_outlined, title: 'No notices right now.', compact: true);
          return Column(children: [
            for (final n in items) NoticeTile(notice: n, flat: true, onTap: () => context.push('/notices/${n.id}')),
          ]);
        },
      ),
    );
  }
}

/// Shown only when the school bills this student through the ERP.
class _FeesSummary extends ConsumerWidget {
  const _FeesSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statement = ref.watch(feeStatementProvider);
    if (statement.hasValue && !statement.value!.hasFees) return const SizedBox.shrink();
    return SectionCard(
      title: 'Fees',
      icon: Icons.receipt_long_outlined,
      actionLabel: 'Details',
      onAction: () => context.go('/fees'),
      child: AsyncValueView(
        value: statement,
        compact: true,
        onRetry: () => ref.invalidate(feeStatementProvider),
        data: (s) {
          final owing = (s.balance ?? 0) > 0;
          final color = !owing ? AppColors.success : (s.anyOverdue ? AppColors.danger : AppColors.warning);
          return Row(children: [
            StatTile(value: formatMoney(s.balance), label: 'Outstanding', color: color),
            const Spacer(),
            StatusChip(
              label: !owing ? 'All paid' : (s.anyOverdue ? 'Overdue' : 'Due ${formatDateShort(s.nextDue)}'),
              color: color,
            ),
          ]);
        },
      ),
    );
  }
}
