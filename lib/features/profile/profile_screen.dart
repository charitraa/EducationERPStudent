import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/states.dart';
import '../auth/auth_controller.dart';
import 'student.dart';

class StudentAvatar extends StatelessWidget {
  const StudentAvatar({super.key, required this.initials, this.radius = 28});
  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(initials, style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
    );
  }
}

/// "Grade 10 - A" plus the program, when the section name doesn't already include it.
String classLabel(Enrollment? e) {
  if (e == null) return 'Not placed in a class';
  final section = e.sectionName;
  final program = e.programName;
  if (section == null) return program ?? 'Not placed in a class';
  if (program == null || section.contains(program)) return section;
  return '$program · $section';
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final student = auth.student;
    final user = auth.user;
    if (student == null || user == null) return const Scaffold(body: LoadingView());
    final theme = Theme.of(context);
    final e = student.enrollment;

    final academic = SectionCard(
      title: 'Academic',
      icon: Icons.school_outlined,
      child: Column(children: [
        InfoRow(label: 'Student ID', value: student.studentNumber),
        InfoRow(label: 'Class', value: classLabel(e)),
        InfoRow(label: 'Academic year', value: e?.academicYearName),
        InfoRow(label: 'Institution', value: user.organizationName),
        InfoRow(label: 'Campus', value: student.campusName),
        InfoRow(label: 'Admitted on', value: formatDate(student.admittedOn)),
        InfoRow(label: 'Status', value: humanize(student.status)),
      ]),
    );

    final personal = SectionCard(
      title: 'Personal',
      icon: Icons.person_outline,
      child: Column(children: [
        InfoRow(label: 'Full name', value: student.fullName),
        InfoRow(label: 'Date of birth', value: student.dateOfBirth == null ? null : formatDate(student.dateOfBirth)),
        InfoRow(label: 'Gender', value: student.gender == null ? null : humanize(student.gender)),
        InfoRow(label: 'Email on record', value: student.email),
        InfoRow(label: 'Phone on record', value: student.phone),
        InfoRow(label: 'Address', value: student.address),
        const SizedBox(height: 4),
        Text(
          'These details come from your school record. Ask the school office to correct anything that\'s wrong.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ]),
    );

    final account = SectionCard(
      title: 'Account',
      icon: Icons.manage_accounts_outlined,
      child: Column(children: [
        InfoRow(label: 'Sign-in email', value: user.email),
        Row(children: [
          Expanded(child: InfoRow(label: 'Account phone', value: user.phone)),
          IconButton(
            tooltip: 'Edit phone number',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => showDialog<void>(context: context, builder: (_) => _PhoneDialog(initial: user.phone ?? '')),
          ),
        ]),
        if (user.lastLogin != null) InfoRow(label: 'Last sign-in', value: formatDateTime(user.lastLogin)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => showDialog<void>(context: context, builder: (_) => const _PasswordDialog()),
              icon: const Icon(Icons.password_outlined),
              label: const Text('Change password'),
            ),
          ),
        ]),
      ]),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await ref.read(authControllerProvider.notifier).reload();
          } catch (e) {
            if (context.mounted) showError(context, e);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: pagePadding(context),
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(children: [
                      StudentAvatar(initials: student.initials, radius: 34),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student.fullName, style: theme.textTheme.titleLarge),
                            const SizedBox(height: 2),
                            Text('ID ${student.studentNumber}  ·  ${classLabel(e)}', style: theme.textTheme.bodyMedium),
                            if (e?.academicYearName != null) Text(e!.academicYearName!, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                ResponsiveColumns(children: [academic, personal, account]),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  onPressed: () => confirmSignOut(context, ref),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text('You\'ll need your email and password to sign in again.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
      ],
    ),
  );
  if (ok == true) await ref.read(authControllerProvider.notifier).logout();
}

class _PhoneDialog extends ConsumerStatefulWidget {
  const _PhoneDialog({required this.initial});
  final String initial;

  @override
  ConsumerState<_PhoneDialog> createState() => _PhoneDialogState();
}

class _PhoneDialogState extends ConsumerState<_PhoneDialog> {
  late final _phone = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).updatePhone(_phone.text);
      ref.read(authControllerProvider.notifier).setUser(user);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.fieldError('phone') ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Account phone'),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _phone,
          enabled: !_busy,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: InputDecoration(labelText: 'Phone number', errorText: _error),
          validator: (v) {
            final s = v?.trim() ?? '';
            if (s.isEmpty) return null;
            if (!RegExp(r'^\+?[0-9 ()-]{6,20}$').hasMatch(s)) return 'Enter a valid phone number.';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

class _PasswordDialog extends ConsumerStatefulWidget {
  const _PasswordDialog();

  @override
  ConsumerState<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<_PasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _currentError;
  String? _nextError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _currentError = _nextError = null;
    });
    try {
      await ref.read(authRepositoryProvider).changePassword(current: _current.text, next: _next.text);
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(context, 'Password changed.');
    } on ApiException catch (e) {
      setState(() {
        _currentError = e.fieldError('current_password');
        _nextError = e.fieldError('new_password') ?? (_currentError == null ? e.message : null);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _current,
              enabled: !_busy,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: 'Current password', errorText: _currentError),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              enabled: !_busy,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(labelText: 'New password', errorText: _nextError, errorMaxLines: 4),
              validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              enabled: !_busy,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => v != _next.text ? 'Passwords don\'t match.' : null,
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Change')),
      ],
    );
  }
}
