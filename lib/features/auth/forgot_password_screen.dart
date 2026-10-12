import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import 'auth_controller.dart';

/// Requests a reset email (`POST /auth/password-reset/`). The link in the
/// email opens the school's web portal, where the new password is set.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _sent
                  ? Column(
                      children: [
                        Icon(Icons.mark_email_read_outlined, size: 56, color: theme.colorScheme.primary),
                        const SizedBox(height: 16),
                        Text('Check your email', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          'If an account uses ${_email.text.trim()}, a link to reset the password is on its way. '
                          'Open it to choose a new password, then sign in here.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to sign in')),
                      ],
                    )
                  : Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Enter the email you sign in with. We\'ll send you a link to set a new password.',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 20),
                          if (_error != null) ...[
                            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: _email,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                            validator: (v) {
                              final s = v?.trim() ?? '';
                              if (s.isEmpty) return 'Enter your email address.';
                              if (!s.contains('@')) return 'Enter a valid email address.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                                : const Text('Send reset link'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
