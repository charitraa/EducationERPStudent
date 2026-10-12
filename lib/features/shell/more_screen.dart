import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../auth/auth_controller.dart';
import '../notifications/notifications_repository.dart';
import '../profile/profile_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = ref.watch(authControllerProvider.select((s) => s.student));
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final theme = Theme.of(context);

    Widget tile(IconData icon, String title, String subtitle, String path, {Widget? trailing}) => ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: trailing ?? const Icon(Icons.chevron_right),
          onTap: () => context.push(path),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: pagePadding(context),
        children: [
          PageBody(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (student != null)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: StudentAvatar(initials: student.initials, radius: 24),
                      title: Text(student.fullName, style: theme.textTheme.titleMedium),
                      subtitle: Text('ID ${student.studentNumber}  ·  View profile'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/profile'),
                    ),
                  ),
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    tile(Icons.notifications_outlined, 'Notifications', 'Results, attendance and fee updates', '/notifications',
                        trailing: unread > 0 ? Badge(label: Text('$unread')) : null),
                    const Divider(),
                    tile(Icons.campaign_outlined, 'Notices', 'Announcements from your school', '/notices'),
                    const Divider(),
                    tile(Icons.receipt_long_outlined, 'Fees', 'Invoices and outstanding balance', '/fees'),
                    const Divider(),
                    tile(Icons.event_note_outlined, 'Exam schedule', 'Dates, rooms and admit cards', '/results?tab=exams'),
                  ]),
                ),
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    tile(Icons.help_outline, 'Help & support', 'FAQ, school contact and problem reports', '/support'),
                    const Divider(),
                    ListTile(
                      leading: Icon(Icons.logout, color: theme.colorScheme.error),
                      title: Text('Sign out', style: TextStyle(color: theme.colorScheme.error)),
                      onTap: () => confirmSignOut(context, ref),
                    ),
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
