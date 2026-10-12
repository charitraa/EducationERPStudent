import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: SizedBox.square(
          dimension: compact ? 22 : 32,
          child: const CircularProgressIndicator(strokeWidth: 2.5, semanticsLabel: 'Loading'),
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.compact = false});
  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final e = asApiException(error);
    final scheme = Theme.of(context).colorScheme;
    final icon = e.isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: scheme.error, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(e.message, style: Theme.of(context).textTheme.bodyMedium)),
            if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(e.message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.message, this.compact = false});
  final IconData icon;
  final String title;
  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: muted, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: muted))),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders an [AsyncValue] with the app's loading and error states. While a
/// refresh is in flight the previous data stays on screen.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({super.key, required this.value, required this.data, this.onRetry, this.compact = false});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return data(value.value as T);
    if (value.hasError) return ErrorView(error: value.error!, onRetry: onRetry, compact: compact);
    return LoadingView(compact: compact);
  }
}

/// A full-page scrollable state (empty or error) that still supports pull-to-refresh.
class ScrollableFill extends StatelessWidget {
  const ScrollableFill({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(constraints: BoxConstraints(minHeight: constraints.maxHeight), child: child),
      ),
    );
  }
}

void showError(BuildContext context, Object error) {
  final e = error is ApiException ? error : asApiException(error);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating));
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}
