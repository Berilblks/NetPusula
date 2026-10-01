import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:netpusula/core/config/api_config.dart';
import 'package:netpusula/core/network/api_client.dart';
import 'package:netpusula/core/storage/session_storage.dart';
import 'package:netpusula/features/auth/data/auth_repository.dart';
import 'package:netpusula/features/auth/domain/auth_models.dart';

final testNow = DateTime.utc(2026, 9, 30);
const testUser = {
  'id': 'user-id',
  'displayName': 'Deniz',
  'email': 'deniz@example.com',
};
Map<String, dynamic> authPayload([String suffix = '1']) => {
  'accessToken': 'access-$suffix',
  'refreshToken': 'refresh-$suffix',
  'accessTokenExpiresAtUtc':
      testNow.add(const Duration(minutes: 15)).toIso8601String(),
  'refreshTokenExpiresAtUtc':
      testNow.add(const Duration(days: 30)).toIso8601String(),
  'tokenType': 'Bearer',
  'user': testUser,
};
SessionTokens session({bool expired = false}) {
  final json = authPayload();
  if (expired) {
    json['accessTokenExpiresAtUtc'] =
        testNow.subtract(const Duration(minutes: 1)).toIso8601String();
  }
  return SessionTokens.fromJson(json);
}

class MemoryStorage implements SessionStorage {
  SessionTokens? value;
  int writes = 0;
  bool failWrite = false;
  bool failRead = false;
  bool failClear = false;
  Completer<void>? readGate;
  @override
  Future<SessionTokens?> read() async {
    await readGate?.future;
    if (failRead) throw StateError('storage unavailable');
    return value;
  }

  @override
  Future<void> write(SessionTokens tokens) async {
    writes++;
    if (failWrite) throw StateError('storage unavailable');
    value = tokens;
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('storage unavailable');
    value = null;
  }
}

typedef Reply = FutureOr<ResponseBody> Function(RequestOptions options);
ResponseBody jsonReply(Object? data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.reply);
  final Reply reply;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => reply(options);
  @override
  void close({bool force = false}) {}
}

class Harness {
  Harness({Reply? publicReply, Reply? protectedReply}) {
    public.httpClientAdapter = FakeAdapter((o) {
      publicPaths.add(o.path);
      return publicReply?.call(o) ?? jsonReply(authPayload());
    });
    client.httpClientAdapter = FakeAdapter((o) {
      protectedCalls++;
      return protectedReply?.call(o) ??
          jsonReply(
            o.path == '/api/user-exams/active'
                ? preparationPayload()
                : testUser,
          );
    });
    repository = AuthRepository(
      publicClient: public,
      client: client,
      storage: storage,
      now: () => testNow,
    );
  }
  final storage = MemoryStorage();
  final public = createApiClient(const ApiConfig('https://api.example.test'));
  final client = createApiClient(const ApiConfig('https://api.example.test'));
  final publicPaths = <String>[];
  int protectedCalls = 0;
  late final AuthRepository repository;
  void dispose() => repository.dispose();
}

Map<String, dynamic> preparationPayload({
  String id = 'prep-id',
  num target = 80,
  String date = '2027-01-01',
}) => {
  'id': id,
  'exam': {
    'id': 'exam-id',
    'code': 'ALES',
    'name': 'Test ALES',
    'maximumTargetNet': 100,
  },
  'targetNet': target,
  'examDate': date,
  'createdAtUtc': '2026-09-30T00:00:00Z',
  'updatedAtUtc': null,
};
