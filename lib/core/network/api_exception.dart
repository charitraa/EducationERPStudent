import 'package:dio/dio.dart';

enum ApiErrorKind { network, timeout, unauthorized, forbidden, notFound, validation, throttled, server, unknown }

/// Every failure the app shows, built from the backend's single error
/// envelope: `{"error": {"code": ..., "message": ..., "details": ...}}`.
class ApiException implements Exception {
  ApiException({required this.kind, required this.message, this.code, this.status, this.details});

  final ApiErrorKind kind;
  final String message;

  /// The backend's machine-readable code, e.g. `invalid_credentials`, `otp_required`.
  final String? code;
  final int? status;
  final Object? details;

  bool get isNetwork => kind == ApiErrorKind.network || kind == ApiErrorKind.timeout;

  /// First message for [field] in a validation error's details, if any.
  String? fieldError(String field) {
    final d = details;
    if (d is Map && d[field] != null) {
      final v = d[field];
      if (v is List && v.isNotEmpty) return v.first.toString();
      return v.toString();
    }
    return null;
  }

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) return _fromDio(error);
    return ApiException(kind: ApiErrorKind.unknown, message: 'Something went wrong. Please try again.');
  }

  static ApiException _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
            kind: ApiErrorKind.timeout, message: 'The server is taking too long to respond. Please try again.');
      case DioExceptionType.connectionError:
        return ApiException(
            kind: ApiErrorKind.network, message: 'Can\'t reach the server. Check your internet connection.');
      case DioExceptionType.badCertificate:
        return ApiException(kind: ApiErrorKind.network, message: 'The server\'s security certificate is not valid.');
      case DioExceptionType.cancel:
        return ApiException(kind: ApiErrorKind.unknown, message: 'The request was cancelled.');
      default:
        break;
    }
    final response = e.response;
    if (response == null) {
      return ApiException(kind: ApiErrorKind.network, message: 'Can\'t reach the server. Check your internet connection.');
    }
    final status = response.statusCode ?? 0;
    String? code;
    String? message;
    Object? details;
    final data = response.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      code = err['code']?.toString();
      message = err['message']?.toString();
      details = err['details'];
      // "Invalid input." alone tells the student nothing; surface the first field message.
      if (message == 'Invalid input.' && details is Map && details.isNotEmpty) {
        final first = details.values.first;
        message = first is List && first.isNotEmpty ? first.first.toString() : first.toString();
      }
    }
    final kind = switch (status) {
      400 => ApiErrorKind.validation,
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      429 => ApiErrorKind.throttled,
      >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.unknown,
    };
    final fallback = switch (kind) {
      ApiErrorKind.unauthorized => 'Your session has ended. Please sign in again.',
      ApiErrorKind.forbidden => 'You don\'t have access to this.',
      ApiErrorKind.notFound => 'Not found.',
      ApiErrorKind.throttled => 'Too many attempts. Please wait a moment and try again.',
      ApiErrorKind.server => 'The server had a problem. Please try again later.',
      _ => 'Something went wrong. Please try again.',
    };
    return ApiException(
      kind: kind,
      // Server errors never show raw internals.
      message: kind == ApiErrorKind.server ? fallback : (message ?? fallback),
      code: code,
      status: status,
      details: details,
    );
  }

  @override
  String toString() => 'ApiException($kind, $status, $code)';
}
