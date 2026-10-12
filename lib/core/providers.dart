import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import 'network/api_client.dart';
import 'storage/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<Dio>((ref) {
  return createApiClient(
    tokens: ref.watch(tokenStorageProvider),
    onSessionExpired: () => ref.read(authControllerProvider.notifier).onSessionExpired(),
  );
});

/// The signed-in user's id. Every data provider watches this, so signing
/// out (or in as someone else) drops all cached student data.
final sessionUserIdProvider = Provider<int?>((ref) {
  return ref.watch(authControllerProvider.select((s) => s.user?.id));
});

/// Use in data providers instead of `ref.watch(apiClientProvider)`: ties the
/// provider's lifetime to the current session.
Dio sessionDio(Ref ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiClientProvider);
}
