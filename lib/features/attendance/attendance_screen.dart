import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/states.dart';
import 'attendance_repository.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _day;
  AttendanceMark? _filter;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shiftMonth(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
        _day = null;
      });

  @override
  Widget build(BuildContext context) {
    final span = monthSpan(_month);
    final month = ref.watch(attendanceProvider(span));
    final yearSpan = ref.watch(enrollmentSpanProvider);
    final year = ref.watch(attendanceProvider(yearSpan));

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(attendanceProvider(yearSpan));
          return ref.refresh(attendanceProvider(span).future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: pagePadding(context),
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OverallCard(value: year, from: yearSpan.from, onRetry: () => ref.invalidate(attendanceProvider(yearSpan))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(tooltip: 'Previous month', onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left)),
                    Expanded(
                      child: Text(DateFormat('MMMM yyyy').format(_month),
                          textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: _isCurrentMonth ? null : () => _shiftMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AsyncValueView(
                  value: month,
                  onRetry: () => ref.invalidate(attendanceProvider(span)),
                  data: (report) => _MonthBody(
                    report: report,
                    month: _month,
                    selectedDay: _day,
                    filter: _filter,
                    onSelectDay: (d) => setState(() => _day = (_day != null && DateUtils.isSameDay(_day, d)) ? null : d),
                    onFilter: (m) => setState(() => _filter = m),
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

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.value, required this.from, required this.onRetry});
  final AsyncValue<AttendanceReport> value;
  final DateTime from;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'This academic year',
      icon: Icons.insights_outlined,
      child: AsyncValueView(
        value: value,
        compact: true,
        onRetry: onRetry,
        data: (r) => r.overall.total == 0
            ? const EmptyView(icon: Icons.fact_check_outlined, title: 'No attendance recorded yet.', compact: true)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Since ${formatDate(from)}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  CountsSummary(counts: r.overall),
                ],
              ),
      ),
    );
  }
}

/// Percentage with a progress bar and the per-status counts.
class CountsSummary extends StatelessWidget {
  const CountsSummary({super.key, required this.counts});
  final AttendanceCounts counts;

  @override
  Widget build(BuildContext context) {
    final p = counts.percentage;
    final color = percentColor(p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            StatTile(value: formatPercent(p), label: 'Attendance', color: color),
            const Spacer(),
            Text('${counts.attended} of ${counts.total - counts.leaveCount} attended',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Attendance ${formatPercent(p)}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (p ?? 0) / 100,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in [AttendanceMark.present, AttendanceMark.late, AttendanceMark.absent])
              StatusChip(label: '${m.label} ${counts.count(m)}', color: m.color, icon: m.icon),
            StatusChip(label: 'Leave ${counts.leaveCount}', color: AttendanceMark.leave.color, icon: AttendanceMark.leave.icon),
          ],
        ),
      ],
    );
  }
}

class _MonthBody extends StatelessWidget {
  const _MonthBody({
    required this.report,
    required this.month,
    required this.selectedDay,
    required this.filter,
    required this.onSelectDay,
    required this.onFilter,
  });

  final AttendanceReport report;
  final DateTime month;
  final DateTime? selectedDay;
  final AttendanceMark? filter;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<AttendanceMark?> onFilter;

  @override
  Widget build(BuildContext context) {
    final marks = report.dayMarks;
    var records = report.records;
    if (selectedDay != null) records = records.where((r) => DateUtils.isSameDay(r.date, selectedDay)).toList();
    if (filter != null) records = records.where((r) => r.mark == filter).toList();
    final present = {for (final r in report.records) if (r.mark != null) r.mark!};

    final calendar = SectionCard(
      title: 'Calendar',
      icon: Icons.calendar_month_outlined,
      child: Column(
        children: [
          _MonthCalendar(month: month, marks: marks, selected: selectedDay, onTap: onSelectDay),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 6, children: [
            for (final m in [AttendanceMark.present, AttendanceMark.late, AttendanceMark.absent, AttendanceMark.leave])
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: m.color, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(m == AttendanceMark.leave ? 'Leave' : m.label, style: Theme.of(context).textTheme.bodySmall),
              ]),
          ]),
        ],
      ),
    );

    final summary = SectionCard(
      title: 'This month',
      icon: Icons.donut_large_outlined,
      child: report.overall.total == 0
          ? const EmptyView(icon: Icons.event_busy_outlined, title: 'No attendance recorded this month.', compact: true)
          : CountsSummary(counts: report.overall),
    );

    final subjects = report.subjects.isEmpty
        ? null
        : SectionCard(
            title: 'By subject',
            icon: Icons.menu_book_outlined,
            child: Column(children: [
              for (final s in report.subjects)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text(s.subjectName)),
                    Text('${s.counts.attended}/${s.counts.total - s.counts.leaveCount}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 56,
                      child: Text(formatPercent(s.counts.percentage),
                          textAlign: TextAlign.end,
                          style: TextStyle(fontWeight: FontWeight.w600, color: percentColor(s.counts.percentage))),
                    ),
                  ]),
                ),
            ]),
          );

    final list = SectionCard(
      title: selectedDay == null ? 'Records' : formatWeekdayDate(selectedDay),
      icon: Icons.list_alt_outlined,
      actionLabel: selectedDay == null ? null : 'Show all',
      onAction: selectedDay == null ? null : () => onSelectDay(selectedDay!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (present.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ChoiceChip(label: const Text('All'), selected: filter == null, onSelected: (_) => onFilter(null)),
                for (final m in AttendanceMark.values.where(present.contains)) ...[
                  const SizedBox(width: 6),
                  ChoiceChip(label: Text(m.label), selected: filter == m, onSelected: (_) => onFilter(filter == m ? null : m)),
                ],
              ]),
            ),
          if (records.isEmpty)
            const EmptyView(icon: Icons.inbox_outlined, title: 'No records to show.', compact: true)
          else
            for (final r in records) _RecordTile(record: r, showDate: selectedDay == null),
        ],
      ),
    );

    return ResponsiveColumns(children: [calendar, summary, list, ?subjects]);
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.showDate});
  final AttendanceRecord record;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final m = record.mark;
    final title = record.subjectName ?? 'Daily roll call';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(m?.icon ?? Icons.help_outline, color: m?.color),
      title: Text(title),
      subtitle: Text([
        if (showDate) formatWeekdayDate(record.date),
        if (record.note != null) record.note!,
      ].join(' · ')),
      trailing: m == null ? null : StatusChip(label: m.label, color: m.color),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.month, required this.marks, required this.selected, required this.onTap});
  final DateTime month;
  final Map<DateTime, AttendanceMark> marks;
  final DateTime? selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // Monday first
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();
    final today = DateTime.now();

    return Column(
      children: [
        Row(children: [
          for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
            Expanded(
              child: Center(
                child: Text(d, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        for (var row = 0; row < rows; row++)
          Row(children: [
            for (var col = 0; col < 7; col++)
              Expanded(child: _cell(context, row * 7 + col - leading + 1, daysInMonth, today)),
          ]),
      ],
    );
  }

  Widget _cell(BuildContext context, int day, int daysInMonth, DateTime today) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 42);
    final theme = Theme.of(context);
    final date = DateTime(month.year, month.month, day);
    final mark = marks[date];
    final isSelected = selected != null && DateUtils.isSameDay(selected, date);
    final isToday = DateUtils.isSameDay(today, date);
    final label = '${DateFormat('d MMMM').format(date)}${mark == null ? '' : ', ${mark.label}'}';
    return Semantics(
      button: mark != null,
      selected: isSelected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: mark == null ? null : () => onTap(date),
        child: Container(
          height: 42,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: mark?.color.withValues(alpha: isSelected ? 0.9 : 0.16),
            borderRadius: BorderRadius.circular(10),
            border: isToday ? Border.all(color: theme.colorScheme.primary, width: 1.5) : null,
          ),
          alignment: Alignment.center,
          child: ExcludeSemantics(
            child: Text(
              '$day',
              style: TextStyle(
                fontWeight: mark != null ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? Colors.white : (mark == null ? theme.colorScheme.onSurfaceVariant : null),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
