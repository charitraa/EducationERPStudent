import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenPair {
  const TokenPair({required this.access, required this.refresh});
  final String access;
  final String refresh;
}

/// Keeps the JWT pair in the platform keystore (Keychain / Android Keystore)
/// and mirrors it in memory so every request doesn't hit the keystore.
/// Passwords are never stored.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'auth.access';
  static const _refreshKey = 'auth.refresh';

  final FlutterSecureStorage _storage;
  String? _access;
  String? _refresh;
  bool _loaded = false;

  String? get access => _access;
  String? get refresh => _refresh;

  Future<void> load() async {
    if (_loaded) return;
    _access = await _storage.read(key: _accessKey);
    _refresh = await _storage.read(key: _refreshKey);
    _loaded = true;
  }

  Future<void> save(TokenPair pair) async {
    _access = pair.access;
    _refresh = pair.refresh;
    _loaded = true;
    await _storage.write(key: _accessKey, value: pair.access);
    await _storage.write(key: _refreshKey, value: pair.refresh);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _loaded = true;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
