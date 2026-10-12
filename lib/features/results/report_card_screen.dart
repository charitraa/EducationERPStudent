import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/states.dart';
import 'results_repository.dart';
import 'results_screen.dart';

class ReportCardScreen extends ConsumerWidget {
  const ReportCardScreen({super.key, required this.resultId});
  final int resultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(reportCardsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Report card')),
      body: AsyncValueView(
        value: cards,
        onRetry: () => ref.invalidate(reportCardsProvider),
        data: (items) {
          final card = items.where((c) => c.resultId == resultId).firstOrNull;
          if (card == null) {
            return const EmptyView(
              icon: Icons.search_off_outlined,
              title: 'Result not found',
              message: 'It may have been withdrawn by the school.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(reportCardsProvider.future),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: pagePadding(context),
              child: PageBody(maxWidth: 820, child: _Body(card: card)),
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.card});
  final ReportCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = card.rankInSection == null
        ? null
        : '${card.rankInSection}${card.classSize == null ? '' : ' of ${card.classSize}'}';
    final stats = <Widget>[
      if (card.percentage != null) StatTile(value: formatPercent(card.percentage), label: 'Percentage'),
      if (card.gradePoint != null) StatTile(value: formatNumber(card.gradePoint), label: 'GPA'),
      if (card.letter != null) StatTile(value: card.letter!, label: 'Grade'),
      if (card.totalObtained != null)
        StatTile(value: '${formatNumber(card.totalObtained)}/${formatNumber(card.totalFull)}', label: 'Total marks'),
      if (rank != null) StatTile(value: rank, label: 'Rank in class'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(card.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          [?card.examType, ?card.academicYear, ?card.term].join('  ·  '),
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (card.result != null) ResultStatusChip(status: card.result!),
          if (card.division != null) StatusChip(label: card.division!, color: theme.colorScheme.primary),
        ]),
        const SizedBox(height: 16),
        if (stats.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(spacing: 32, runSpacing: 16, children: stats),
            ),
          ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Subjects',
          icon: Icons.menu_book_outlined,
          child: card.subjects.isEmpty
              ? const EmptyView(icon: Icons.inbox_outlined, title: 'No subject marks on this result.', compact: true)
              : Column(children: [for (final s in card.subjects) _SubjectRow(line: s)]),
        ),
        const SizedBox(height: 16),
        if (card.attendancePercentage != null || card.remark != null)
          SectionCard(
            title: 'Remarks',
            icon: Icons.rate_review_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (card.attendancePercentage != null)
                  InfoRow(
                    label: 'Attendance for this period',
                    value: '${formatPercent(card.attendancePercentage)} (${card.attendanceAttended}/${card.attendanceTotal})',
                  ),
                if (card.remark != null) ...[
                  const SizedBox(height: 4),
                  Text('Class teacher', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(card.remark!),
                ],
              ],
            ),
          ),
        if (card.grading.isNotEmpty) ...[
          const SizedBox(height: 16),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: Card(
              child: ExpansionTile(
                title: const Text('Grading scale'),
                shape: const RoundedRectangleBorder(),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  for (final b in card.grading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        SizedBox(width: 48, child: Text(b.letter, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(child: Text('${formatNumber(b.from)}% and above${b.remark == null ? '' : ' · ${b.remark}'}')),
                        if (b.gradePoint != null) Text(formatNumber(b.gradePoint)),
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.line});
  final SubjectLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marks = line.absent
        ? 'Absent'
        : (line.obtained == null ? '—' : '${formatNumber(line.obtained)} / ${formatNumber(line.full)}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.subjectName, style: theme.textTheme.bodyLarge),
                Text(
                  [
                    marks,
                    if (line.creditHours != null) '${formatNumber(line.creditHours)} credits',
                    ?line.remark,
                  ].join('  ·  '),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(line.letter ?? formatPercent(line.percentage), style: theme.textTheme.titleMedium),
              if (line.status != null && line.status != 'pass') ResultStatusChip(status: line.status!),
            ],
          ),
        ],
      ),
    );
  }
}
