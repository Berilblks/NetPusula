import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/features/auth/domain/auth_issue.dart';
import 'package:netpusula/features/auth/domain/auth_models.dart';
import 'support/auth_fakes.dart';

void main() {
  test(
    'concurrent rejected refresh fails all waiters and rotates only once',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final h = Harness(
        publicReply: (o) async {
          if (o.path.endsWith('/refresh')) {
            entered.complete();
            await release.future;
            return jsonReply({}, 401);
          }
          return jsonReply(authPayload());
        },
      );
      addTearDown(h.dispose);
      await h.repository.login('deniz@example.com', 'Password1');
      final first = expectLater(
        h.repository.refreshAfterUnauthorized('access-1'),
        throwsA(isA<AuthException>()),
      );
      final second = expectLater(
        h.repository.refreshAfterUnauthorized('access-1'),
        throwsA(isA<AuthException>()),
      );
      await entered.future;
      release.complete();
      await Future.wait([first, second]);
      expect(h.publicPaths.where((p) => p.endsWith('/refresh')).length, 1);
      expect(h.storage.value, isNull);
    },
  );
  test('expired refresh clears without sending HTTP', () async {
    final h = Harness();
    addTearDown(h.dispose);
    final json = authPayload();
    json['refreshTokenExpiresAtUtc'] =
        testNow.subtract(const Duration(days: 1)).toIso8601String();
    h.storage.value = SessionTokens.fromJson(json);
    expect(await h.repository.restore(), isNull);
    expect(h.publicPaths, isEmpty);
    expect(h.storage.value, isNull);
  });
  test('failed local logout cannot restore old session on retry', () async {
    final h = Harness();
    addTearDown(h.dispose);
    h.storage.value = session();
    await h.repository.restore();
    h.storage.failClear = true;
    expect(await h.repository.logout(), AuthIssue.storage);
    await expectLater(h.repository.restore(), throwsA(isA<AuthException>()));
    h.storage.failClear = false;
    expect(await h.repository.restore(), isNull);
    expect(h.storage.value, isNull);
    expect(h.protectedCalls, 1);
  });
  test(
    'failure persisting rotated pair clears locally and revokes minted refresh',
    () async {
      late Harness h;
      h = Harness(
        publicReply: (o) {
          if (o.path.endsWith('/refresh')) {
            h.storage.failWrite = true;
            return jsonReply(authPayload('2'));
          }
          return jsonReply(null, 204);
        },
      );
      addTearDown(h.dispose);
      h.storage.value = session(expired: true);
      await expectLater(h.repository.restore(), throwsA(isA<AuthException>()));
      expect(h.storage.value, isNull);
      expect(h.publicPaths.last, '/api/auth/logout');
    },
  );
  test('logout during secure read cannot publish restored user', () async {
    final h = Harness();
    addTearDown(h.dispose);
    h.storage.value = session();
    h.storage.readGate = Completer<void>();
    final restoring = expectLater(
      h.repository.restore(),
      throwsA(isA<AuthException>()),
    );
    final logout = h.repository.logout();
    h.storage.readGate!.complete();
    await restoring;
    await logout;
    expect(h.storage.value, isNull);
    expect(h.protectedCalls, 0);
  });
}
