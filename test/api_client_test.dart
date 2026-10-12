import 'dart:async';

import 'package:dio/dio.dart';
import 'package:education_erp_student/core/network/api_client.dart';
import 'package:education_erp_student/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('AuthInterceptor', () {
    test('sends the bearer token', () async {
      final tokens = MemoryTokenStorage(access: 'A1', refresh: 'R1');
      final adapter = FakeAdapter((o) async => (200, {'ok': true}));
      final dio = createApiClient(tokens: tokens, onSessionExpired: () {}, baseUrl: 'http://api', adapter: () => adapter);

      await dio.get<dynamic>('/students/me/');
      expect(adapter.requests.single.headers['Authorization'], 'Bearer A1');
    });

    test('concurrent 401s share one refresh, then retry with the new token', () async {
      final tokens = MemoryTokenStorage(access: 'old', refresh: 'R1');
      var refreshCalls = 0;
      final gate = Completer<void>();
      final dio = createApiClient(
        tokens: tokens,
        onSessionExpired: () => fail('session should not expire'),
        baseUrl: 'http://api',
        adapter: () => FakeAdapter((o) async {
          if (o.path.endsWith('/auth/refresh/')) {
            refreshCalls++;
            expect(o.data, {'refresh': 'R1'});
            await gate.future; // hold the refresh so all requests queue on it
            return (200, {'access': 'new', 'refresh': 'R2'});
          }
          final auth = o.headers['Authorization'];
          return auth == 'Bearer new' ? (200, {'path': o.path}) : (401, errorBody('token_not_valid', 'expired'));
        }),
      );

      final calls = [
        dio.get<dynamic>('/students/me/'),
        dio.get<dynamic>('/exams/me/'),
        dio.get<dynamic>('/invoices/me/'),
      ];
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      final results = await Future.wait(calls);

      expect(refreshCalls, 1, reason: 'rotated refresh tokens may only be traded once');
      expect(results.map((r) => r.statusCode), everyElement(200));
      expect(tokens.access, 'new');
      expect(tokens.refresh, 'R2');
    });

    test('a refused refresh clears tokens and reports the session expired', () async {
      final tokens = MemoryTokenStorage(access: 'old', refresh: 'revoked');
      var expired = 0;
      final dio = createApiClient(
        tokens: tokens,
        onSessionExpired: () => expired++,
        baseUrl: 'http://api',
        adapter: () => FakeAdapter((o) async => o.path.endsWith('/auth/refresh/')
            ? (401, errorBody('token_not_valid', 'Token is blacklisted'))
            : (401, errorBody('not_authenticated', 'no'))),
      );

      final error = await dio.get<dynamic>('/students/me/').then<Object?>((_) => null, onError: (Object e) => e);
      expect(asApiException(error!).kind, ApiErrorKind.unauthorized);
      expect(expired, 1);
      expect(tokens.refresh, isNull);
      expect(tokens.access, isNull);
    });

    test('a network failure while refreshing keeps the session', () async {
      final tokens = MemoryTokenStorage(access: 'old', refresh: 'R1');
      var expired = 0;
      final dio = createApiClient(
        tokens: tokens,
        onSessionExpired: () => expired++,
        baseUrl: 'http://api',
        adapter: () => FakeAdapter((o) async {
          if (o.path.endsWith('/auth/refresh/')) {
            throw DioException.connectionError(requestOptions: o, reason: 'offline');
          }
          return (401, errorBody('not_authenticated', 'no'));
        }),
      );

      final error = await dio.get<dynamic>('/students/me/').then<Object?>((_) => null, onError: (Object e) => e);
      expect(asApiException(error!).isNetwork, isTrue);
      expect(expired, 0);
      expect(tokens.refresh, 'R1');
    });

    test('login failures are not retried through refresh', () async {
      final tokens = MemoryTokenStorage(refresh: 'R1');
      final adapter = FakeAdapter((o) async => (400, errorBody('invalid_credentials', 'Invalid credentials or inactive account.')));
      final dio = createApiClient(tokens: tokens, onSessionExpired: () {}, baseUrl: 'http://api', adapter: () => adapter);

      final error = await guard(() => dio.post<dynamic>('/auth/login/', data: {})).then<Object?>((_) => null, onError: (Object e) => e);
      expect(error, isA<ApiException>());
      expect((error as ApiException).code, 'invalid_credentials');
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('ApiException', () {
    DioException response(int status, Object? body) {
      final o = RequestOptions(path: '/x');
      return DioException(
        requestOptions: o,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: o, statusCode: status, data: body),
      );
    }

    test('reads the backend error envelope', () {
      final e = ApiException.from(response(400, errorBody('otp_required', 'Enter the code from your authenticator app.')));
      expect(e.kind, ApiErrorKind.validation);
      expect(e.code, 'otp_required');
      expect(e.message, 'Enter the code from your authenticator app.');
    });

    test('surfaces the first field error instead of "Invalid input."', () {
      final e = ApiException.from(response(400, errorBody('invalid', 'Invalid input.', {
        'new_password': ['This password is too common.'],
      })));
      expect(e.message, 'This password is too common.');
      expect(e.fieldError('new_password'), 'This password is too common.');
    });

    test('hides server internals on 5xx', () {
      final e = ApiException.from(response(500, '<html>Traceback…</html>'));
      expect(e.kind, ApiErrorKind.server);
      expect(e.message, isNot(contains('Traceback')));
    });

    test('maps throttling and timeouts', () {
      expect(ApiException.from(response(429, errorBody('throttled', 'Request was throttled.'))).kind, ApiErrorKind.throttled);
      final timeout = DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.receiveTimeout);
      expect(ApiException.from(timeout).isNetwork, isTrue);
    });
  });
}
