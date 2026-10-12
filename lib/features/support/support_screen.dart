import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/states.dart';
import '../auth/auth_controller.dart';
import 'support_repository.dart';

const _faq = [
  (
    'I forgot my password.',
    'Sign out, then tap "Forgot password?" on the sign-in screen. A reset link is sent to your email. '
        'If you no longer use that email, ask your school office to reset your password.'
  ),
  (
    'My attendance or marks look wrong.',
    'Attendance and marks are official records and can only be corrected by your teacher or the school office. '
        'Raise a support request below with the date or exam and subject.'
  ),
  (
    'Why can\'t I see my exam result?',
    'Results appear only after the school publishes them. Until then they are not shown to anyone outside the exam office.'
  ),
  (
    'Can I change my name or date of birth?',
    'No — these come from your admission record. Ask the school office if something needs correcting. '
        'You can update your own contact phone number from your profile.'
  ),
  (
    'How do I pay fees?',
    'The app shows your invoices and balance. Payments are made through your school\'s accounts office.'
  ),
];

String ticketStatusLabel(String s) => switch (s) {
      'open' => 'Open',
      'in_progress' => 'In progress',
      'resolved' => 'Resolved',
      'closed' => 'Closed',
      _ => humanize(s),
    };

Color ticketStatusColor(String s) => switch (s) {
      'open' => AppColors.brand,
      'in_progress' => AppColors.warning,
      'resolved' => AppColors.success,
      _ => AppColors.neutral,
    };

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final tickets = ref.watch(ticketsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/support/new'),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Report a problem'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(ticketsProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: pagePadding(context).copyWith(bottom: 96),
          children: [
            PageBody(
              maxWidth: 820,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionCard(
                    title: 'Your school',
                    icon: Icons.school_outlined,
                    child: Column(children: [
                      InfoRow(label: 'Institution', value: auth.user?.organizationName),
                      InfoRow(label: 'Campus', value: auth.student?.campusName),
                      const SizedBox(height: 4),
                      Text(
                        'For anything about admissions, fees or records, visit or call your campus office.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'My requests',
                    icon: Icons.support_agent_outlined,
                    child: AsyncValueView(
                      value: tickets,
                      compact: true,
                      onRetry: () => ref.invalidate(ticketsProvider),
                      data: (list) {
                        if (list.items.isEmpty) {
                          return const EmptyView(
                            icon: Icons.inbox_outlined,
                            title: 'No requests yet. Use "Report a problem" if something isn\'t working.',
                            compact: true,
                          );
                        }
                        return Column(children: [
                          for (final t in list.items)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(t.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('#${t.id}  ·  ${formatDate(t.createdAt)}'),
                              trailing: StatusChip(label: ticketStatusLabel(t.status), color: ticketStatusColor(t.status)),
                              onTap: () => context.push('/support/${t.id}'),
                            ),
                          if (list.hasMore)
                            TextButton(
                              onPressed: () => ref.read(ticketsProvider.notifier).loadMore(),
                              child: const Text('Show more'),
                            ),
                        ]);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Frequently asked questions',
                    icon: Icons.help_outline,
                    child: Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: Column(children: [
                        for (final (q, a) in _faq)
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(q, style: theme.textTheme.bodyLarge),
                            childrenPadding: const EdgeInsets.only(bottom: 12),
                            expandedAlignment: Alignment.centerLeft,
                            children: [Text(a)],
                          ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key});

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;

  static const _topics = ['Can\'t sign in', 'App problem', 'Wrong information', 'Other'];

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final ticket = await ref.read(supportRepositoryProvider).create(subject: _subject.text, description: _description.text);
      ref.invalidate(ticketsProvider);
      if (!mounted) return;
      showMessage(context, 'Request #${ticket.id} sent. The school office will get back to you.');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a problem')),
      body: SingleChildScrollView(
        padding: pagePadding(context),
        child: PageBody(
          maxWidth: 640,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Tell the school office what went wrong. Don\'t include your password.'),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in _topics)
                    ActionChip(label: Text(t), onPressed: () => setState(() => _subject.text = t)),
                ]),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _subject,
                  enabled: !_busy,
                  maxLength: 200,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a short subject.' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _description,
                  enabled: !_busy,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Details',
                    alignLabelWithHint: true,
                    hintText: 'What happened, and when? What did you expect?',
                  ),
                  validator: (v) => (v == null || v.trim().length < 10) ? 'Please describe the problem (at least 10 characters).' : null,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Send request'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(supportRepositoryProvider).addComment(widget.id, _reply.text);
      _reply.clear();
      ref.invalidate(ticketCommentsProvider(widget.id));
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(ticketProvider(widget.id));
    final comments = ref.watch(ticketCommentsProvider(widget.id));
    final me = ref.watch(authControllerProvider.select((s) => s.user?.id));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Request #${widget.id}')),
      body: AsyncValueView(
        value: ticket,
        onRetry: () => ref.invalidate(ticketProvider(widget.id)),
        data: (t) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () {
                  ref.invalidate(ticketProvider(widget.id));
                  return ref.refresh(ticketCommentsProvider(widget.id).future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: pagePadding(context),
                  children: [
                    PageBody(
                      maxWidth: 720,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(child: Text(t.subject, style: theme.textTheme.titleLarge)),
                            StatusChip(label: ticketStatusLabel(t.status), color: ticketStatusColor(t.status)),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            'Sent ${formatDateTime(t.createdAt)}${t.assignedToName == null ? '' : '  ·  Handled by ${t.assignedToName}'}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Card(child: Padding(padding: const EdgeInsets.all(16), child: SelectableText(t.description))),
                          const SizedBox(height: 20),
                          Text('Conversation', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 8),
                          AsyncValueView(
                            value: comments,
                            compact: true,
                            onRetry: () => ref.invalidate(ticketCommentsProvider(widget.id)),
                            data: (items) => items.isEmpty
                                ? const EmptyView(icon: Icons.forum_outlined, title: 'No replies yet.', compact: true)
                                : Column(children: [for (final c in items) _Bubble(comment: c, mine: c.authorId == me)]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!t.isClosed)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: PageBody(
                    maxWidth: 720,
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          enabled: !_sending,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(hintText: 'Write a reply'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Send',
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_rounded),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.comment, required this.mine});
  final TicketComment comment;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mine ? 'You' : (comment.authorName ?? 'School office'), style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            SelectableText(comment.body),
            const SizedBox(height: 4),
            Text(formatDateTime(comment.createdAt), style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
