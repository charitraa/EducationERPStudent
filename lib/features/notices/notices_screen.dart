import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/paged_list_view.dart';
import '../../core/widgets/states.dart';
import 'notices_repository.dart';

/// Notices published in the last few days are marked "New"; the backend
/// keeps no per-student read state for notices.
bool isNewNotice(Notice n) => n.publishedAt != null && DateTime.now().difference(n.publishedAt!).inDays < 3;

class NoticesScreen extends ConsumerWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notices')),
      body: PagedListView<Notice>(
        value: ref.watch(noticesProvider),
        onRefresh: () => ref.refresh(noticesProvider.future),
        onRetry: () => ref.invalidate(noticesProvider),
        onLoadMore: () => ref.read(noticesProvider.notifier).loadMore(),
        empty: const EmptyView(
          icon: Icons.campaign_outlined,
          title: 'No notices',
          message: 'Announcements from your school will show here.',
        ),
        itemBuilder: (context, n) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: NoticeTile(notice: n, onTap: () => context.push('/notices/${n.id}')),
        ),
      ),
    );
  }
}

class NoticeTile extends StatelessWidget {
  const NoticeTile({super.key, required this.notice, this.onTap, this.flat = false});
  final Notice notice;
  final VoidCallback? onTap;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: flat ? 0 : 16, vertical: flat ? 8 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.campaign_outlined, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(notice.title, style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  if (isNewNotice(notice)) const StatusChip(label: 'New', color: AppColors.brand),
                ]),
                const SizedBox(height: 2),
                Text(
                  notice.body.replaceAll(RegExp(r'\s+'), ' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  [formatDate(notice.publishedAt), notice.campusName ?? 'All campuses'].join('  ·  '),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (flat) return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: content);
    return Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: onTap, child: content));
  }
}

class NoticeDetailScreen extends ConsumerWidget {
  const NoticeDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(noticeProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Notice')),
      body: AsyncValueView(
        value: notice,
        onRetry: () => ref.invalidate(noticeProvider(id)),
        data: (n) {
          final theme = Theme.of(context);
          return SingleChildScrollView(
            padding: pagePadding(context),
            child: PageBody(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    StatusChip(label: formatDateTime(n.publishedAt), color: AppColors.neutral, icon: Icons.schedule),
                    StatusChip(label: n.campusName ?? 'All campuses', color: AppColors.info, icon: Icons.place_outlined),
                    if (n.expiresAt != null)
                      StatusChip(label: 'Until ${formatDate(n.expiresAt)}', color: AppColors.warning, icon: Icons.event_outlined),
                  ]),
                  const SizedBox(height: 20),
                  SelectableText(n.body, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
