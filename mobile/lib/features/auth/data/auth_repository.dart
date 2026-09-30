import 'dart:async';
import 'package:dio/dio.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/auth_issue.dart';
import '../domain/auth_models.dart';

class AuthRepository implements AuthSessionDelegate {
  AuthRepository({
    required this.publicClient,
    required this.client,
    required this.storage,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    client.interceptors.add(AuthInterceptor(client, this));
  }

  final Dio publicClient;
  final Dio client;
  final SessionStorage storage;
  final DateTime Function() now;
  final _invalidations = StreamController<AuthIssue>.broadcast(sync: true);
  Stream<AuthIssue> get invalidations => _invalidations.stream;
  SessionTokens? _tokens;
  Future<String>? _refreshFlight;
  Future<void> _storageTail = Future.value();
  int _generation = 0;
  bool _disposed = false;
  bool _mustClear = false;
  @override
  int get generation => _generation;

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final task = _storageTail.then((_) => operation());
    _storageTail = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return task;
  }

  Future<void> _write(SessionTokens tokens, int expected) async {
    try {
      await _serialized(() async {
        _check(expected);
        await storage.write(tokens);
      });
      _check(expected);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(AuthIssue.storage);
    }
  }

  void _check(int expected) {
    if (_disposed || expected != _generation) {
      throw const AuthException(AuthIssue.sessionExpired);
    }
  }

  Future<AuthUser?> restore() async {
    final expected = _generation;
    try {
      if (_mustClear) {
        await _serialized(storage.clear);
        _check(expected);
        _mustClear = false;
        return null;
      }
      final restored = await _serialized(storage.read);
      _check(expected);
      _tokens = restored;
    } on FormatException {
      await invalidate(expected, AuthIssue.sessionExpired);
      return null;
    } on TypeError {
      await invalidate(expected, AuthIssue.sessionExpired);
      return null;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(AuthIssue.storage);
    }
    final tokens = _tokens;
    if (tokens == null) return null;
    if (tokens.refreshPending ||
        !tokens.refreshExpiresAt.isAfter(now().toUtc())) {
      await invalidate(expected, AuthIssue.sessionExpired);
      return null;
    }
    return currentUser();
  }

  Future<AuthUser> login(String email, String password) => _authenticate(
    '/api/auth/login',
    {'email': email.trim(), 'password': password},
  );
  Future<AuthUser> register(
    String displayName,
    String email,
    String password,
  ) => _authenticate('/api/auth/register', {
    'displayName': displayName.trim(),
    'email': email.trim(),
    'password': password,
  });

  Future<AuthUser> _authenticate(String path, Map<String, dynamic> data) async {
    final expected = ++_generation;
    _refreshFlight = null;
    try {
      final response = await publicClient.post<dynamic>(path, data: data);
      _check(expected);
      final json = response.data as Map<String, dynamic>;
      final tokens = _parseTokens(json);
      final user = AuthUser.fromJson(json['user'] as Map<String, dynamic>);
      try {
        await _write(tokens, expected);
      } catch (_) {
        try {
          if (expected == _generation) {
            await invalidate(expected, AuthIssue.storage);
          }
        } finally {
          await _bestEffortRevoke(tokens.refreshToken);
        }
        rethrow;
      }
      _tokens = tokens;
      return user; // Backend registration/login already returns an authenticated profile.
    } catch (error) {
      throw AuthException(mapAuthIssue(error));
    } finally {
      data.clear(); // Never retain credentials in application state or a request map.
    }
  }

  SessionTokens _parseTokens(Map<String, dynamic> json) {
    if (json['tokenType'] != 'Bearer') {
      throw const FormatException('Invalid token type');
    }
    final tokens = SessionTokens.fromJson(json);
    if (!tokens.accessExpiresAt.isAfter(now().toUtc()) ||
        !tokens.refreshExpiresAt.isAfter(now().toUtc())) {
      throw const FormatException('Invalid token expiration');
    }
    return tokens;
  }

  Future<AuthUser> currentUser() async {
    final expected = _generation;
    try {
      final response = await client.get<dynamic>('/api/auth/me');
      _check(expected);
      return AuthUser.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw AuthException(mapAuthIssue(error));
    }
  }

  @override
  Future<String> accessToken() async {
    final tokens = _tokens;
    if (tokens == null) throw const AuthException(AuthIssue.sessionExpired);
    if (!tokens.accessExpiresAt.isAfter(
      now().toUtc().add(const Duration(seconds: 30)),
    )) {
      return _refresh();
    }
    return tokens.accessToken;
  }

  @override
  Future<String> refreshAfterUnauthorized(String rejectedToken) {
    final tokens = _tokens;
    if (tokens == null) throw const AuthException(AuthIssue.sessionExpired);
    // A late 401 for the previous JWT must reuse the already rotated pair.
    if (tokens.accessToken != rejectedToken) {
      return Future.value(tokens.accessToken);
    }
    return _refresh();
  }

  Future<String> _refresh() {
    if (_refreshFlight != null) return _refreshFlight!;
    final expected = _generation;
    final future = _performRefresh(expected);
    _refreshFlight = future;
    // Do not return an unobserved error-producing whenComplete chain.
    void release() {
      if (identical(_refreshFlight, future)) _refreshFlight = null;
    }

    future.then<void>(
      (_) => release(),
      onError: (Object _, StackTrace __) => release(),
    );
    return future;
  }

  Future<String> _performRefresh(int expected) async {
    final old = _tokens;
    String? rotatedToken;
    try {
      if (old == null || !old.refreshExpiresAt.isAfter(now().toUtc())) {
        throw const AuthException(AuthIssue.sessionExpired);
      }
      // Crash/network ambiguity must never lead to replaying an already rotated token on restart.
      await _write(old.pending(), expected);
      final response = await publicClient.post<dynamic>(
        '/api/auth/refresh',
        data: {'refreshToken': old.refreshToken},
      );
      final next = _parseTokens(response.data as Map<String, dynamic>);
      rotatedToken = next.refreshToken;
      if (expected != _generation || _disposed) {
        throw const AuthException(AuthIssue.sessionExpired);
      }
      await _write(next, expected);
      _tokens = next;
      return next.accessToken;
    } catch (error) {
      if (rotatedToken != null) await _bestEffortRevoke(rotatedToken);
      final mapped = mapAuthIssue(error);
      final issue =
          mapped == AuthIssue.invalidCredentials
              ? AuthIssue.sessionExpired
              : mapped;
      if (expected == _generation) await invalidate(expected, issue);
      throw AuthException(issue);
    }
  }

  @override
  Future<void> invalidate(int expectedGeneration, AuthIssue issue) async {
    if (expectedGeneration != _generation) return;
    final clearedGeneration = ++_generation;
    _refreshFlight = null;
    _tokens = null;
    _mustClear = true;
    var effectiveIssue = issue;
    try {
      await _serialized(() async {
        if (_generation == clearedGeneration) {
          await storage.clear();
          _mustClear = false;
        }
      });
    } catch (_) {
      effectiveIssue = AuthIssue.storage;
    }
    if (!_disposed && _generation == clearedGeneration) {
      _invalidations.add(effectiveIssue);
    }
    if (effectiveIssue == AuthIssue.storage) {
      throw const AuthException(AuthIssue.storage);
    }
  }

  Future<AuthIssue?> logout() async {
    final token = _tokens?.refreshToken;
    final expected = ++_generation;
    _refreshFlight = null;
    _mustClear = true;
    _tokens =
        null; // Protected content and in-flight results lose authority immediately.
    var issue = AuthIssue.localLogout;
    var cleared = true;
    try {
      await _serialized(() async {
        if (_generation == expected) {
          await storage.clear();
          _mustClear = false;
        }
      });
    } catch (_) {
      cleared = false;
    }
    final revoked = token == null || await _bestEffortRevoke(token);
    if (!cleared) issue = AuthIssue.storage;
    return !cleared || !revoked ? issue : null;
  }

  Future<bool> _bestEffortRevoke(String token) async {
    try {
      await publicClient.post<dynamic>(
        '/api/auth/logout',
        data: {'refreshToken': token},
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _disposed = true;
    ++_generation;
    publicClient.close(force: true);
    client.close(force: true);
    unawaited(_invalidations.close());
  }
}
