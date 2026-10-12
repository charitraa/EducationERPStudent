import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/common.dart';
import '../../core/widgets/states.dart';
import 'lesson_tile.dart';
import 'timetable_repository.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  bool _weekView = false;
  late DateTime _selected = today();

  DateTime get _monday => _selected.subtract(Duration(days: _selected.weekday - 1));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/results?tab=exams'),
            icon: const Icon(Icons.event_note_outlined),
            label: const Text('Exams'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PageBody(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pagePadding(context).left, 4, pagePadding(context).right, 8),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Day'), icon: Icon(Icons.view_day_outlined)),
                  ButtonSegment(value: true, label: Text('Week'), icon: Icon(Icons.calendar_view_week_outlined)),
                ],
                selected: {_weekView},
                onSelectionChanged: (s) => setState(() => _weekView = s.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
            Expanded(child: _weekView ? const _WeekView() : _dayView(context)),
          ],
        ),
      ),
    );
  }

  Widget _dayView(BuildContext context) {
    final lessons = ref.watch(dayTimetableProvider(_selected));
    final padding = pagePadding(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding.left - 8),
          child: _WeekStrip(
            monday: _monday,
            selected: _selected,
            onSelect: (d) => setState(() => _selected = d),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(dayTimetableProvider(_selected).future),
            child: AsyncValueView(
              value: lessons,
              onRetry: () => ref.invalidate(dayTimetableProvider(_selected)),
              data: (items) {
                if (items.isEmpty) {
                  return const ScrollableFill(
                    child: EmptyView(
                      icon: Icons.free_breakfast_outlined,
                      title: 'No classes',
                      message: 'Nothing is scheduled for this day.',
                    ),
                  );
                }
                final mark = currentOrNext(items, _selected);
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: padding,
                  itemCount: items.length,
                  itemBuilder: (context, i) => LessonTile(lesson: items[i], moment: mark?.$1 == i ? mark!.$2 : null),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.monday, required this.selected, required this.onSelect});
  final DateTime monday;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = today();
    final days = List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous week',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onSelect(selected.subtract(const Duration(days: 7))),
            ),
            Expanded(
              child: Text(
                '${DateFormat('d MMM').format(days.first)} – ${DateFormat('d MMM yyyy').format(days.last)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: 'Next week',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onSelect(selected.add(const Duration(days: 7))),
            ),
          ],
        ),
        Row(
          children: [
            for (final d in days)
              Expanded(
                child: _DayChip(
                  date: d,
                  selected: DateUtils.isSameDay(d, selected),
                  isToday: DateUtils.isSameDay(d, now),
                  onTap: () => onSelect(d),
                ),
              ),
          ],
        ),
        if (!days.any((d) => DateUtils.isSameDay(d, now)))
          TextButton(onPressed: () => onSelect(now), child: const Text('Back to today')),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.date, required this.selected, required this.isToday, required this.onTap});
  final DateTime date;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimary : (isToday ? scheme.primary : scheme.onSurface);
    return Semantics(
      selected: selected,
      button: true,
      label: DateFormat('EEEE d MMMM').format(date),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ExcludeSemantics(
                child: Column(
                  children: [
                    Text(DateFormat('E').format(date), style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.85))),
                    const SizedBox(height: 2),
                    Text('${date.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The regular week, without day-specific changes.
class _WeekView extends ConsumerWidget {
  const _WeekView();

  static const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(weekTimetableProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(weekTimetableProvider.future),
      child: AsyncValueView(
        value: week,
        onRetry: () => ref.invalidate(weekTimetableProvider),
        data: (lessons) {
          if (lessons.isEmpty) {
            return const ScrollableFill(
              child: EmptyView(
                icon: Icons.calendar_today_outlined,
                title: 'No timetable yet',
                message: 'Your class timetable will appear here once the school publishes it.',
              ),
            );
          }
          final todayDow = DateTime.now().weekday;
          final cards = <Widget>[
            for (var dow = 1; dow <= 7; dow++)
              if (lessons.any((l) => l.dayOfWeek == dow))
                SectionCard(
                  title: _dayNames[dow - 1] + (dow == todayDow ? '  (today)' : ''),
                  child: Column(children: [
                    for (final l in lessons.where((l) => l.dayOfWeek == dow)) LessonTile(lesson: l, dense: true),
                  ]),
                ),
          ];
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: pagePadding(context),
            child: ResponsiveColumns(children: cards),
          );
        },
      ),
    );
  }
}
