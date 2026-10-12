import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/states.dart';
import '../exams/exam_card.dart';
import '../exams/exams_repository.dart';
import '../timetable/timetable_repository.dart';
import 'results_repository.dart';

/// Published results and the exam schedule, as two tabs.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey(initialTab),
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exams & results'),
          bottom: const TabBar(tabs: [Tab(text: 'Results'), Tab(text: 'Exam schedule')]),
        ),
        body: const TabBarView(children: [_ResultsTab(), _ExamsTab()]),
      ),
    );
  }
}

class _ResultsTab extends ConsumerWidget {
  const _ResultsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(reportCardsProvider);
    final transcript = ref.watch(transcriptProvider);
    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(transcriptProvider);
        return ref.refresh(reportCardsProvider.future);
      },
      child: AsyncValueView(
        value: cards,
        onRetry: () => ref.invalidate(reportCardsProvider),
        data: (items) {
          if (items.isEmpty) {
            return const ScrollableFill(
              child: EmptyView(
                icon: Icons.workspace_premium_outlined,
                title: 'No results yet',
                message: 'Results appear here as soon as your school publishes them.',
              ),
            );
          }
          final gpa = transcript.value?.gpa;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: pagePadding(context),
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (gpa != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            StatTile(value: formatNumber(gpa), label: 'Cumulative GPA'),
                            const Spacer(),
                            if (transcript.value?.creditsPassed != null)
                              StatTile(
                                value: formatNumber(transcript.value!.creditsPassed),
                                label: 'Credits passed',
                              ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    for (final c in items) ...[
                      ResultTile(card: c, onTap: () => context.push('/results/${c.resultId}')),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ResultTile extends StatelessWidget {
  const ResultTile({super.key, required this.card, this.onTap});
  final ReportCard card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = card.gradePoint != null
        ? 'GPA ${formatNumber(card.gradePoint)}'
        : (card.percentage != null ? formatPercent(card.percentage) : (card.letter ?? '—'));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      [?card.academicYear, ?card.term, if (card.publishedAt != null) 'Published ${formatDate(card.publishedAt)}']
                          .join('  ·  '),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      if (card.result != null) ResultStatusChip(status: card.result!),
                      if (card.letter != null && card.gradePoint != null)
                        StatusChip(label: 'Grade ${card.letter}', color: AppColors.brand),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(headline, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),
                  if (onTap != null) Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResultStatusChip extends StatelessWidget {
  const ResultStatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'pass' => AppColors.success,
      'fail' => AppColors.danger,
      'absent' => AppColors.warning,
      _ => AppColors.neutral,
    };
    return StatusChip(label: status == 'pass' ? 'Passed' : (status == 'fail' ? 'Not passed' : humanize(status)), color: color);
  }
}

class _ExamsTab extends ConsumerWidget {
  const _ExamsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(examsProvider);
    final now = today();
    return RefreshIndicator(
      onRefresh: () => ref.refresh(examsProvider.future),
      child: AsyncValueView(
        value: exams,
        onRetry: () => ref.invalidate(examsProvider),
        data: (items) {
          if (items.isEmpty) {
            return const ScrollableFill(
              child: EmptyView(
                icon: Icons.event_available_outlined,
                title: 'No exams scheduled',
                message: 'Exam dates for your class will show here once they are scheduled.',
              ),
            );
          }
          final upcoming = items.where((e) => e.isUpcoming(now)).toList();
          final past = items.where((e) => !e.isUpcoming(now)).toList().reversed.toList();
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: pagePadding(context),
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (upcoming.isEmpty)
                      const EmptyView(icon: Icons.event_available_outlined, title: 'No upcoming exams.', compact: true),
                    for (final e in upcoming) ...[ExamCard(exam: e, today: now), const SizedBox(height: 12)],
                    if (past.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Earlier this year', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      for (final e in past) ...[ExamCard(exam: e, today: now), const SizedBox(height: 12)],
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
