import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/states.dart';
import 'auth_controller.dart';
import 'brand_mark.dart';

/// Shown while a saved session is checked, or when the server can't be
/// reached to confirm it.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final offline = auth.status == AuthStatus.offline;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 72),
                const SizedBox(height: 24),
                if (!offline)
                  const LoadingView(compact: true)
                else ...[
                  ErrorView(error: auth.error!, onRetry: () => ref.read(authControllerProvider.notifier).restore()),
                  TextButton(
                    onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                    child: const Text('Sign out'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
