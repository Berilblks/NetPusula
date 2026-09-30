import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/domain/auth_models.dart';

abstract interface class SessionStorage {
  Future<SessionTokens?> read();
  Future<void> write(SessionTokens tokens);
  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
              synchronizable: false,
            ),
          );
  static const key = 'netpusula.auth.session.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<SessionTokens?> read() async {
    final value = await _storage.read(key: key);
    if (value == null || value == '{}') return null;
    return SessionTokens.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  @override
  Future<void> write(SessionTokens tokens) =>
      _storage.write(key: key, value: jsonEncode(tokens.toJson()));

  @override
  Future<void> clear() async {
    // A successful tombstone is enough even if deletion subsequently fails.
    // A successful delete is enough if the tombstone write failed.
    var overwritten = false;
    try {
      await _storage.write(key: key, value: '{}');
      overwritten = true;
    } catch (_) {
      /* Try deletion as the alternative. */
    }
    try {
      await _storage.delete(key: key);
    } catch (_) {
      if (!overwritten) rethrow;
    }
  }
}
