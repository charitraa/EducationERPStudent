import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import 'timetable_repository.dart';

enum LessonMoment { now, next }

/// Which lesson of [lessons] (all on [date]) is on now, or comes next.
(int, LessonMoment)? currentOrNext(List<Lesson> lessons, DateTime date, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  if (date.year != clock.year || date.month != clock.month || date.day != clock.day) return null;
  final minutes = clock.hour * 60 + clock.minute;
  for (var i = 0; i < lessons.length; i++) {
    final l = lessons[i];
    if (l.isOff || l.startMinutes == null || l.endMinutes == null) continue;
    if (minutes >= l.startMinutes! && minutes < l.endMinutes!) return (i, LessonMoment.now);
    if (minutes < l.startMinutes!) return (i, LessonMoment.next);
  }
  return null;
}

class LessonTile extends StatelessWidget {
  const LessonTile({super.key, required this.lesson, this.moment, this.dense = false});
  final Lesson lesson;
  final LessonMoment? moment;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final highlight = moment == LessonMoment.now;
    final muted = lesson.isOff;
    final details = [
      if (lesson.teacherName != null) lesson.teacherName!,
      if (lesson.roomName != null) 'Room ${lesson.roomName}',
    ].join('  ·  ');

    return Container(
      margin: EdgeInsets.only(bottom: dense ? 6 : 8),
      decoration: BoxDecoration(
        color: highlight ? scheme.primaryContainer.withValues(alpha: 0.55) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? scheme.primary.withValues(alpha: 0.5) : scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 8 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatMinutes(lesson.startMinutes), style: theme.textTheme.labelLarge),
                Text(
                  formatMinutes(lesson.endMinutes),
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(width: 3, height: dense ? 34 : 40, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(
            color: muted ? scheme.outlineVariant : scheme.primary,
            borderRadius: BorderRadius.circular(2),
          )),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.subjectName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    decoration: muted ? TextDecoration.lineThrough : null,
                    color: muted ? scheme.onSurfaceVariant : null,
                  ),
                ),
                if (details.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(details, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                if (lesson.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(lesson.note!, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                  ),
                if (moment != null || lesson.isOff || lesson.isSubstitute)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(spacing: 6, runSpacing: 4, children: [
                      if (moment == LessonMoment.now) const StatusChip(label: 'Now', color: AppColors.success, icon: Icons.circle),
                      if (moment == LessonMoment.next) const StatusChip(label: 'Next', color: AppColors.brand),
                      if (lesson.closedBy != null) StatusChip(label: lesson.closedBy!, color: AppColors.warning),
                      if (lesson.isCancelled && lesson.closedBy == null)
                        const StatusChip(label: 'Cancelled', color: AppColors.danger),
                      if (lesson.isSubstitute) const StatusChip(label: 'Substitute teacher', color: AppColors.info),
                    ]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
