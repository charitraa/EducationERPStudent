import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/json.dart';
import '../profile/student.dart';
import 'current_user.dart';

class LoginResult {
  const LoginResult(this.tokens, this.user);
  final TokenPair tokens;
  final CurrentUser user;
}

/// The backend's SimpleJWT auth endpoints (`/auth/...`).
class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  /// `POST /auth/login/`. Throws `otp_required` when the account has
  /// two-factor login on and no [otp] was given.
  Future<LoginResult> login({required String email, required String password, String? otp}) => guard(() async {
        final res = await _dio.post<Map<String, dynamic>>('/auth/login/', data: {
          'email': email.trim(),
          'password': password,
          if (otp != null && otp.isNotEmpty) 'otp': otp.trim(),
        });
        final d = res.data!;
        return LoginResult(
          TokenPair(access: d['access'] as String, refresh: d['refresh'] as String),
          CurrentUser.fromJson(asMap(d['user'])),
        );
      });

  Future<CurrentUser> me() => guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/auth/me/');
        return CurrentUser.fromJson(res.data!);
      });

  /// The student record linked to this account. 404 when there is none
  /// (a teacher's, parent's or admin's account).
  Future<Student> student() => guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/students/me/');
        return Student.fromJson(res.data!);
      });

  /// `PATCH /auth/me/`: only the account's own phone number is offered to
  /// students; names and academic details belong to the school office.
  Future<CurrentUser> updatePhone(String phone) => guard(() async {
        final res = await _dio.patch<Map<String, dynamic>>('/auth/me/', data: {'phone': phone.trim()});
        return CurrentUser.fromJson(res.data!);
      });

  Future<void> changePassword({required String current, required String next}) => guard(() async {
        await _dio.post<void>('/auth/change-password/', data: {'current_password': current, 'new_password': next});
      });

  /// Emails a reset link. The backend answers 202 whether or not the
  /// address has an account, so this never reveals who is registered.
  Future<void> requestPasswordReset(String email) => guard(() async {
        await _dio.post<void>('/auth/password-reset/', data: {'email': email.trim()});
      });

  /// Blacklists the refresh token server-side.
  Future<void> logout(String refresh) => guard(() async {
        await _dio.post<void>('/auth/logout/', data: {'refresh': refresh});
      });
}
