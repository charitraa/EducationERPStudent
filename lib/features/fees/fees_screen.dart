import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/states.dart';
import 'fees_repository.dart';

class FeesScreen extends ConsumerWidget {
  const FeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statement = ref.watch(feeStatementProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Fees')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(feeStatementProvider.future),
        child: AsyncValueView(
          value: statement,
          onRetry: () => ref.invalidate(feeStatementProvider),
          data: (s) {
            if (!s.hasFees) {
              return const ScrollableFill(
                child: EmptyView(
                  icon: Icons.receipt_long_outlined,
                  title: 'No fee invoices',
                  message: 'Invoices issued by your school will appear here.',
                ),
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: pagePadding(context),
              children: [
                PageBody(
                  maxWidth: 820,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FeeSummaryCard(statement: s),
                      const SizedBox(height: 16),
                      Text('Invoices', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final i in s.invoices) ...[_InvoiceCard(invoice: i), const SizedBox(height: 10)],
                      const SizedBox(height: 8),
                      Text(
                        'To pay fees or get a receipt, please contact your school\'s accounts office.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class FeeSummaryCard extends StatelessWidget {
  const FeeSummaryCard({super.key, required this.statement});
  final FeeStatement statement;

  @override
  Widget build(BuildContext context) {
    final s = statement;
    final owing = (s.balance ?? 0) > 0;
    final color = !owing ? AppColors.success : (s.anyOverdue ? AppColors.danger : AppColors.warning);
    final paidShare = (s.totalBilled ?? 0) > 0 ? ((s.totalPaid ?? 0) / s.totalBilled!).clamp(0.0, 1.0) : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              StatTile(value: formatMoney(s.balance), label: 'Outstanding balance', color: color),
              const Spacer(),
              StatusChip(
                label: !owing ? 'All paid' : (s.anyOverdue ? 'Overdue' : 'Due ${formatDate(s.nextDue)}'),
                color: color,
              ),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: paidShare,
                minHeight: 8,
                color: AppColors.success,
                backgroundColor: AppColors.success.withValues(alpha: 0.15),
                semanticsLabel: 'Fees paid',
                semanticsValue: '${(paidShare * 100).round()}%',
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: StatTile(value: formatMoney(s.totalBilled), label: 'Total billed')),
              Expanded(child: StatTile(value: formatMoney(s.totalPaid), label: 'Paid')),
            ]),
          ],
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});
  final InvoiceLine invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i = invoice;
    final (label, color) = i.isPaid
        ? ('Paid', AppColors.success)
        : (i.isOverdue ? ('Overdue', AppColors.danger) : ((i.paid ?? 0) > 0 ? ('Partly paid', AppColors.warning) : ('Unpaid', AppColors.warning)));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(i.termName ?? 'Invoice ${i.invoiceNumber}', style: theme.textTheme.titleSmall)),
              StatusChip(label: label, color: color),
            ]),
            const SizedBox(height: 2),
            Text('No. ${i.invoiceNumber}  ·  Issued ${formatDate(i.issueDate)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            InfoRow(label: 'Total', value: formatMoney(i.total)),
            InfoRow(label: 'Paid', value: formatMoney(i.paid)),
            InfoRow(label: 'Balance', value: formatMoney(i.balance)),
            if (!i.isPaid) InfoRow(label: 'Due date', value: formatDate(i.dueDate)),
          ],
        ),
      ),
    );
  }
}
