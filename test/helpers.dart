import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:education_erp_student/core/storage/token_storage.dart';

/// Token storage that never touches the platform keystore.
class MemoryTokenStorage extends TokenStorage {
  MemoryTokenStorage({String? access, String? refresh}) : _a = access, _r = refresh;
  String? _a;
  String? _r;
  int clears = 0;

  @override
  String? get access => _a;
  @override
  String? get refresh => _r;
  @override
  Future<void> load() async {}
  @override
  Future<void> save(TokenPair pair) async {
    _a = pair.access;
    _r = pair.refresh;
  }

  @override
  Future<void> clear() async {
    clears++;
    _a = null;
    _r = null;
  }
}

typedef Handler = Future<(int, Object?)> Function(RequestOptions options);

/// A scripted backend: [handler] answers each request with (status, json body).
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final Handler handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final (status, body) = await handler(options);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> errorBody(String code, String message, [Object? details]) => {
      'error': {'code': code, 'message': message, 'details': details},
    };
