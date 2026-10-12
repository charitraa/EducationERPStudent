import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/format.dart';
import '../../core/widgets/paged_list_view.dart';
import '../../core/widgets/states.dart';
import 'notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _icon(String eventType) => switch (eventType.split('.').first) {
        'examinations' => Icons.workspace_premium_outlined,
        'attendance' => Icons.fact_check_outlined,
        'finance' => Icons.receipt_long_outlined,
        'events' => Icons.event_outlined,
        'library' => Icons.local_library_outlined,
        'applications' => Icons.description_outlined,
        _ => Icons.notifications_outlined,
      };

  Future<void> _open(BuildContext context, WidgetRef ref, AppNotification n) async {
    try {
      await ref.read(notificationsProvider.notifier).markRead(n);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
    final route = n.route;
    if (route != null && context.mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationsProvider);
    final hasUnread = list.value?.items.any((n) => !n.isRead) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () async {
                try {
                  await ref.read(notificationsProvider.notifier).markAllRead();
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
              child: const Text('Mark all read'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: PagedListView<AppNotification>(
        value: list,
        onRefresh: () {
          ref.invalidate(unreadCountProvider);
          return ref.refresh(notificationsProvider.future);
        },
        onRetry: () => ref.invalidate(notificationsProvider),
        onLoadMore: () => ref.read(notificationsProvider.notifier).loadMore(),
        empty: const EmptyView(
          icon: Icons.notifications_none_outlined,
          title: 'You\'re all caught up',
          message: 'Updates about your results, attendance and fees will appear here.',
        ),
        itemBuilder: (context, n) {
          final theme = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              clipBehavior: Clip.antiAlias,
              color: n.isRead ? null : theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Icon(_icon(n.eventType), color: theme.colorScheme.primary),
                title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w700)),
                subtitle: Text([
                  if (n.body != null) n.body!,
                  if (n.createdAt != null) timeAgo(n.createdAt!),
                ].join('\n')),
                isThreeLine: n.body != null,
                trailing: n.isRead
                    ? null
                    : Semantics(
                        label: 'Unread',
                        child: Container(width: 10, height: 10, decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle)),
                      ),
                onTap: () => _open(context, ref, n),
              ),
            ),
          );
        },
      ),
    );
  }
}
