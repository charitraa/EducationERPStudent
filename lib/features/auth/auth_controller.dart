import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../profile/student.dart';
import 'auth_repository.dart';
import 'current_user.dart';

enum AuthStatus {
  /// Checking for a saved session at start-up.
  unknown,

  /// A saved session exists but the server couldn't be reached to confirm it.
  offline,
  signedOut,
  signedIn,
}

class AuthState {
  const AuthState({required this.status, this.user, this.student, this.message, this.error});

  final AuthStatus status;
  final CurrentUser? user;
  final Student? student;

  /// Shown on the login screen, e.g. after the session expired.
  final String? message;
  final ApiException? error;

  static const unknown = AuthState(status: AuthStatus.unknown);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

const notStudentMessage =
    'This app is for students. Your account isn\'t linked to a student record — please contact your school office.';

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    Future.microtask(restore);
    return AuthState.unknown;
  }

  /// Restores a saved session: the stored refresh token is traded for a
  /// fresh access token by the interceptor if the old one has expired.
  Future<void> restore() async {
    state = AuthState.unknown;
    final tokens = ref.read(tokenStorageProvider);
    await tokens.load();
    if (tokens.refresh == null) {
      state = const AuthState(status: AuthStatus.signedOut);
      return;
    }
    try {
      final user = await _repo.me();
      final student = await _loadStudent();
      state = AuthState(status: AuthStatus.signedIn, user: user, student: student);
    } on ApiException catch (e) {
      if (e.isNetwork || e.kind == ApiErrorKind.server || e.kind == ApiErrorKind.throttled) {
        state = AuthState(status: AuthStatus.offline, error: e);
      } else if (e.kind == ApiErrorKind.notFound) {
        await _clearLocal();
        state = const AuthState(status: AuthStatus.signedOut, message: notStudentMessage);
      } else {
        await _clearLocal();
        state = const AuthState(status: AuthStatus.signedOut, message: 'Please sign in again.');
      }
    }
  }

  /// Signs in. Rethrows [ApiException]; `otp_required` means ask for the
  /// authenticator code and call again with [otp].
  Future<void> login({required String email, required String password, String? otp}) async {
    final result = await _repo.login(email: email, password: password, otp: otp);
    final tokens = ref.read(tokenStorageProvider);
    await tokens.save(result.tokens);
    final Student student;
    try {
      student = await _loadStudent();
    } on ApiException catch (e) {
      // Not a student (teacher, parent, admin): end the server session too.
      await _discard(result.tokens.refresh);
      if (e.kind == ApiErrorKind.notFound) {
        throw ApiException(kind: ApiErrorKind.forbidden, message: notStudentMessage, code: 'not_a_student');
      }
      rethrow;
    }
    state = AuthState(status: AuthStatus.signedIn, user: result.user, student: student);
  }

  Future<Student> _loadStudent() => _repo.student();

  /// Re-reads the account and student record (after a profile edit or pull-to-refresh).
  Future<void> reload() async {
    final user = await _repo.me();
    final student = await _loadStudent();
    state = AuthState(status: AuthStatus.signedIn, user: user, student: student);
  }

  void setUser(CurrentUser user) {
    state = AuthState(status: state.status, user: user, student: state.student);
  }

  Future<void> logout() async {
    final refresh = ref.read(tokenStorageProvider).refresh;
    if (refresh != null) await _discard(refresh);
    await _clearLocal();
    state = const AuthState(status: AuthStatus.signedOut);
  }

  /// Called by the API client when the refresh token is refused.
  void onSessionExpired() {
    if (state.status == AuthStatus.signedOut) return;
    state = const AuthState(status: AuthStatus.signedOut, message: 'Your session has expired. Please sign in again.');
  }

  Future<void> _discard(String refresh) async {
    try {
      await _repo.logout(refresh);
    } catch (_) {
      // Offline or already expired: the local copy is still removed below.
    }
    await _clearLocal();
  }

  Future<void> _clearLocal() => ref.read(tokenStorageProvider).clear();
}
