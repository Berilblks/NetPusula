import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/core/storage/session_storage.dart';
import 'support/auth_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, String> values;
  late bool failWrite;
  late bool failDelete;
  setUp(() {
    values = {};
    failWrite = false;
    failDelete = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String;
      switch (call.method) {
        case 'read':
          return values[key];
        case 'write':
          if (failWrite) throw PlatformException(code: 'locked');
          values[key] = args['value'] as String;
          return null;
        case 'delete':
          if (failDelete) throw PlatformException(code: 'locked');
          values.remove(key);
          return null;
      }
      throw UnimplementedError(call.method);
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'secure plugin receives single token envelope and only necessary metadata',
    () async {
      final storage = SecureSessionStorage();
      await storage.write(session());
      expect(values.keys, [SecureSessionStorage.key]);
      expect((jsonDecode(values.values.single) as Map).keys.toSet(), {
        'accessToken',
        'refreshToken',
        'accessTokenExpiresAtUtc',
        'refreshTokenExpiresAtUtc',
        'refreshPending',
      });
      expect((await storage.read())!.refreshToken, 'refresh-1');
      await storage.clear();
      expect(await storage.read(), isNull);
    },
  );
  test(
    'tombstone makes session unavailable even if native deletion fails',
    () async {
      final storage = SecureSessionStorage();
      await storage.write(session());
      failDelete = true;
      await storage.clear();
      expect(await storage.read(), isNull);
      expect(values.values.single, '{}');
    },
  );
  test(
    'native deletion clears session even if tombstone write fails',
    () async {
      final storage = SecureSessionStorage();
      await storage.write(session());
      failWrite = true;
      await storage.clear();
      expect(await storage.read(), isNull);
    },
  );
  test(
    'both native clear failures are reported instead of claiming logout success',
    () async {
      final storage = SecureSessionStorage();
      await storage.write(session());
      failWrite = true;
      failDelete = true;
      await expectLater(storage.clear(), throwsA(isA<PlatformException>()));
    },
  );
  test('corrupt secure envelope fails decoding', () async {
    values[SecureSessionStorage.key] = '{broken';
    await expectLater(SecureSessionStorage().read(), throwsFormatException);
  });
}
