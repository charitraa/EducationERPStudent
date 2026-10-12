import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Builds the shared Dio instance: bearer token on every request, one
/// refresh shared by all concurrent 401s, and errors turned into
/// [ApiException]s.
Dio createApiClient({
  required TokenStorage tokens,
  required void Function() onSessionExpired,
  String? baseUrl,
  HttpClientAdapterFactory? adapter,
}) {
  final options = BaseOptions(
    baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    headers: {'Accept': 'application/json'},
  );
  final dio = Dio(options);
  // Refresh goes through a bare instance so it never re-enters the 401 handler.
  final bare = Dio(options);
  if (adapter != null) {
    dio.httpClientAdapter = adapter();
    bare.httpClientAdapter = adapter();
  }
  dio.interceptors.add(AuthInterceptor(dio: dio, bare: bare, tokens: tokens, onSessionExpired: onSessionExpired));
  return dio;
}

typedef HttpClientAdapterFactory = HttpClientAdapter Function();

class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.dio, required this.bare, required this.tokens, required this.onSessionExpired});

  final Dio dio;
  final Dio bare;
  final TokenStorage tokens;
  final void Function() onSessionExpired;

  static const _authPaths = ['/auth/login/', '/auth/refresh/', '/auth/logout/', '/auth/password-reset/'];
  static const _retriedKey = '_retried';

  Future<String>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final access = tokens.access;
    final isAuthCall = _authPaths.any(options.path.endsWith) && !options.path.endsWith('/auth/logout/');
    if (access != null && !isAuthCall) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final isAuthCall = _authPaths.any(options.path.endsWith);
    final retried = options.extra[_retriedKey] == true;

    if (err.response?.statusCode == 401 && !isAuthCall && !retried && tokens.refresh != null) {
      try {
        final access = await refreshSession();
        options.extra[_retriedKey] = true;
        options.headers['Authorization'] = 'Bearer $access';
        final response = await dio.fetch<dynamic>(options);
        return handler.resolve(response);
      } on DioException catch (refreshError) {
        if (_isSessionRejected(refreshError)) {
          await tokens.clear();
          onSessionExpired();
          return handler.reject(_wrap(err, ApiException.from(err)));
        }
        // Network trouble while refreshing: keep the session, report the failure.
        return handler.reject(_wrap(refreshError, ApiException.from(refreshError)));
      } on ApiException catch (e) {
        return handler.reject(_wrap(err, e));
      }
    }
    handler.next(_wrap(err, ApiException.from(err)));
  }

  /// Trades the refresh token for a new pair. The backend rotates refresh
  /// tokens and blacklists the old one, so concurrent callers must share
  /// a single call: a second call with the old token would be refused.
  Future<String> refreshSession() {
    return _refreshing ??= _trade().whenComplete(() => _refreshing = null);
  }

  Future<String> _trade() async {
    final refresh = tokens.refresh;
    if (refresh == null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/auth/refresh/'),
        response: Response(requestOptions: RequestOptions(path: '/auth/refresh/'), statusCode: 401),
        type: DioExceptionType.badResponse,
      );
    }
    final response = await bare.post<Map<String, dynamic>>('/auth/refresh/', data: {'refresh': refresh});
    final data = response.data!;
    final access = data['access'] as String;
    await tokens.save(TokenPair(access: access, refresh: (data['refresh'] as String?) ?? refresh));
    return access;
  }

  /// Only a definite "no" from the server ends the session. Throttling,
  /// server errors and dropped connections are temporary.
  static bool _isSessionRejected(DioException e) {
    final status = e.response?.statusCode;
    return status == 400 || status == 401;
  }

  static DioException _wrap(DioException original, ApiException error) =>
      original.copyWith(error: error, message: error.message);
}

/// Unwraps the [ApiException] the interceptor attached to a Dio failure.
ApiException asApiException(Object error) {
  if (error is DioException && error.error is ApiException) return error.error as ApiException;
  return ApiException.from(error);
}

/// Runs [call] and rethrows any failure as an [ApiException], so screens
/// only ever deal with one error type.
Future<T> guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (e) {
    throw asApiException(e);
  }
}
