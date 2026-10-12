import 'package:flutter/foundation.dart';

/// Build-time configuration. Nothing secret lives here: the app only ever
/// holds the signed-in student's own tokens.
///
/// Set the API address when building:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
///   flutter build apk --dart-define=API_BASE_URL=https://erp.example.com/api/v1
class AppConfig {
  const AppConfig._();

  static const String _defined = String.fromEnvironment('API_BASE_URL');

  /// The backend's v1 API root, without a trailing slash.
  ///
  /// Debug builds fall back to the Android emulator's alias for the host's
  /// `localhost:8000` (the backend's `runserver` port). Release builds must
  /// name an HTTPS address.
  static String get apiBaseUrl {
    final url = _defined.isNotEmpty ? _defined : (kReleaseMode ? '' : 'http://10.0.2.2:8000/api/v1');
    if (url.isEmpty) {
      throw StateError('API_BASE_URL must be set with --dart-define for release builds.');
    }
    if (kReleaseMode && !url.startsWith('https://')) {
      throw StateError('Release builds must use an https:// API_BASE_URL.');
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
