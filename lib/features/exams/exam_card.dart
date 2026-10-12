import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import 'exams_repository.dart';

/// One exam with its paper schedule, seat and admit card.
class ExamCard extends StatelessWidget {
  const ExamCard({super.key, required this.exam, required this.today});
  final Exam exam;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final upcoming = exam.isUpcoming(today);
    final span = exam.startDate == null
        ? null
        : (exam.endDate == null || exam.endDate == exam.startDate
            ? formatDate(exam.startDate)
            : '${formatDateShort(exam.startDate)} – ${formatDate(exam.endDate)}');
    final card = exam.admitCard;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exam.name, style: theme.textTheme.titleMedium),
                      if (exam.type != null || span != null)
                        Text(
                          [?exam.type, ?span].join('  ·  '),
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                if (exam.status == 'published')
                  const StatusChip(label: 'Results out', color: AppColors.success)
                else if (upcoming && exam.startDate != null)
                  StatusChip(label: relativeDays(exam.startDate!, now: today), color: AppColors.brand),
              ],
            ),
            if (exam.seatRoom != null || card != null) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (exam.seatRoom != null)
                  StatusChip(
                    label: 'Room ${exam.seatRoom}${exam.seatNumber == null ? '' : ', seat ${exam.seatNumber}'}',
                    color: AppColors.info,
                    icon: Icons.event_seat_outlined,
                  ),
                if (card != null)
                  StatusChip(
                    label: card.isWithheld ? 'Admit card withheld' : 'Admit card ${card.cardNumber}',
                    color: card.isWithheld ? AppColors.danger : AppColors.success,
                    icon: Icons.badge_outlined,
                  ),
              ]),
              if (card?.withheldReason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(card!.withheldReason!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger)),
                ),
            ],
            if (exam.papers.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              for (final p in exam.papers) _PaperRow(paper: p, today: today),
            ],
            if (exam.instructions != null) ...[
              const SizedBox(height: 8),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Instructions'),
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  expandedAlignment: Alignment.centerLeft,
                  children: [Text(exam.instructions!)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaperRow extends StatelessWidget {
  const _PaperRow({required this.paper, required this.today});
  final ExamPaper paper;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = paper.date != null && paper.date!.isBefore(today);
    final isToday = paper.date != null && DateUtils.isSameDay(paper.date, today);
    final time = paper.startMinutes == null
        ? null
        : '${formatMinutes(paper.startMinutes)} – ${formatMinutes(paper.endMinutes)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              formatWeekdayDate(paper.date),
              style: theme.textTheme.labelMedium?.copyWith(
                color: isToday ? theme.colorScheme.primary : (done ? theme.colorScheme.onSurfaceVariant : null),
                fontWeight: isToday ? FontWeight.w700 : null,
              ),
            ),
          ),
          Expanded(
            child: Text(
              paper.subjectName,
              style: theme.textTheme.bodyMedium?.copyWith(color: done ? theme.colorScheme.onSurfaceVariant : null),
            ),
          ),
          if (time != null) Text(time, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
