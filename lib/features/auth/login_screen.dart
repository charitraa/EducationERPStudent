import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'brand_mark.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _needsOtp = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(
            email: _email.text,
            password: _password.text,
            otp: _needsOtp ? _otp.text : null,
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'otp_required') {
          _needsOtp = true;
          _error = null;
        } else {
          _error = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notice = ref.watch(authControllerProvider.select((s) => s.message));
    final banner = _error ?? notice;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandMark(size: 72)),
                      const SizedBox(height: 24),
                      Text('Student Portal', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in with the account your school or college gave you.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 28),
                      if (banner != null) ...[
                        _Banner(message: banner, isError: _error != null),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _email,
                        enabled: !_busy && !_needsOtp,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email, AutofillHints.username],
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return 'Enter your email address.';
                          if (!s.contains('@') || !s.contains('.')) return 'Enter a valid email address.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy && !_needsOtp,
                        obscureText: _obscure,
                        textInputAction: _needsOtp ? TextInputAction.next : TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _needsOtp ? null : _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Enter your password.' : null,
                      ),
                      if (_needsOtp) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Two-step sign-in is on for this account. Enter the code from your authenticator app, or a recovery code.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _otp,
                          enabled: !_busy,
                          autofocus: true,
                          keyboardType: TextInputType.visiblePassword,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(labelText: 'Verification code', prefixIcon: Icon(Icons.pin_outlined)),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the code.' : null,
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : () => context.push('/forgot-password'),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : Text(_needsOtp ? 'Verify and sign in' : 'Sign in'),
                      ),
                      if (_needsOtp)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _needsOtp = false;
                                    _otp.clear();
                                  }),
                          child: const Text('Use a different account'),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Don\'t have an account? Your school office creates student accounts.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.isError});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.info;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.info_outline, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
