import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/features/auth/domain/auth_issue.dart';
import 'package:netpusula/features/auth/presentation/auth_text.dart';
import 'package:netpusula/core/config/api_config.dart';
import 'support/auth_fakes.dart';

void main() {
  test('empty storage restores anonymous without HTTP', () async {
    final h = Harness();
    addTearDown(h.dispose);
    expect(await h.repository.restore(), isNull);
    expect(h.protectedCalls, 0);
  });
  for (final register in [false, true]) {
    test(
      '${register ? "register" : "login"} persists complete pair and safe user',
      () async {
        final h = Harness(
          publicReply: (o) {
            expect(o.headers.containsKey('Authorization'), isFalse);
            expect(o.data['email'], 'deniz@example.com');
            expect(o.data['password'], 'Password1');
            if (register) expect(o.data['displayName'], 'Deniz');
            return jsonReply(authPayload(), register ? 201 : 200);
          },
        );
        addTearDown(h.dispose);
        final user =
            register
                ? await h.repository.register(
                  ' Deniz ',
                  ' deniz@example.com ',
                  'Password1',
                )
                : await h.repository.login(' deniz@example.com ', 'Password1');
        expect(user.displayName, 'Deniz');
        expect(h.storage.value!.accessToken, 'access-1');
        expect(h.storage.value!.refreshToken, 'refresh-1');
        expect(h.storage.value!.toJson().keys, isNot(contains('password')));
        expect(h.protectedCalls, 0);
      },
    );
  }
  test('existing session fetches me with bearer', () async {
    final h = Harness(
      protectedReply: (o) {
        expect(o.headers['Authorization'], 'Bearer access-1');
        return jsonReply(testUser);
      },
    );
    addTearDown(h.dispose);
    h.storage.value = session();
    expect((await h.repository.restore())!.email, 'deniz@example.com');
    expect(h.publicPaths, isEmpty);
  });
  test(
    'expired access refreshes before me and rotates persisted pair',
    () async {
      final h = Harness(
        publicReply: (o) {
          expect(o.path, '/api/auth/refresh');
          expect(o.data['refreshToken'], 'refresh-1');
          return jsonReply(authPayload('2'));
        },
        protectedReply: (o) {
          expect(o.headers['Authorization'], 'Bearer access-2');
          return jsonReply(testUser);
        },
      );
      addTearDown(h.dispose);
      h.storage.value = session(expired: true);
      expect(await h.repository.restore(), isNotNull);
      expect(h.storage.value!.refreshToken, 'refresh-2');
      expect(h.storage.value!.refreshPending, isFalse);
      expect(h.storage.writes, 2);
    },
  );
  test(
    'concurrent 401s share exactly one refresh and late 401 reuses rotation',
    () async {
      final gate = Completer<void>();
      final started = Completer<void>();
      var oldRequests = 0;
      final allOld = Completer<void>();
      final h = Harness(
        publicReply: (o) async {
          if (o.path.endsWith('/refresh')) {
            started.complete();
            await gate.future;
            return jsonReply(authPayload('2'));
          }
          return jsonReply(authPayload());
        },
        protectedReply: (o) async {
          if (o.headers['Authorization'] == 'Bearer access-1') {
            if (++oldRequests == 3) allOld.complete();
            await allOld.future;
            return jsonReply({}, 401);
          }
          return jsonReply(testUser);
        },
      );
      addTearDown(h.dispose);
      await h.repository.login('deniz@example.com', 'Password1');
      final requests = Future.wait(
        List.generate(3, (_) => h.repository.currentUser()),
      );
      await started.future;
      gate.complete();
      expect((await requests).length, 3);
      expect(h.publicPaths.where((p) => p.endsWith('/refresh')).length, 1);
      expect(
        await h.repository.refreshAfterUnauthorized('access-1'),
        'access-2',
      );
      expect(h.publicPaths.where((p) => p.endsWith('/refresh')).length, 1);
      expect(h.protectedCalls, 6);
    },
  );
  test('refresh rejection clears storage and emits invalidation', () async {
    final h = Harness(publicReply: (_) => jsonReply({}, 401));
    addTearDown(h.dispose);
    h.storage.value = session(expired: true);
    final issue = h.repository.invalidations.first;
    await expectLater(h.repository.restore(), throwsA(isA<AuthException>()));
    expect(await issue, AuthIssue.sessionExpired);
    expect(h.storage.value, isNull);
  });
  test('retried 401 stops after one retry and clears session', () async {
    final h = Harness(
      publicReply: (_) => jsonReply(authPayload('2')),
      protectedReply: (_) => jsonReply({}, 401),
    );
    addTearDown(h.dispose);
    h.storage.value = session();
    await expectLater(h.repository.restore(), throwsA(isA<AuthException>()));
    expect(h.protectedCalls, 2);
    expect(h.publicPaths.length, 1);
    expect(h.storage.value, isNull);
  });
  test('ambiguous refresh timeout clears pair to prevent replay', () async {
    final h = Harness(
      publicReply:
          (o) =>
              throw DioException(
                requestOptions: o,
                type: DioExceptionType.receiveTimeout,
              ),
    );
    addTearDown(h.dispose);
    h.storage.value = session(expired: true);
    await expectLater(
      h.repository.restore(),
      throwsA(
        isA<AuthException>().having((e) => e.issue, 'issue', AuthIssue.network),
      ),
    );
    expect(h.storage.value, isNull);
  });
  test(
    'interrupted rotation marker never replays refresh after restart',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      h.storage.value = session().pending();
      expect(await h.repository.restore(), isNull);
      expect(h.publicPaths, isEmpty);
      expect(h.storage.value, isNull);
    },
  );
  test('offline me retains session for retry and does not refresh', () async {
    final h = Harness(
      protectedReply:
          (o) =>
              throw DioException(
                requestOptions: o,
                type: DioExceptionType.connectionError,
              ),
    );
    addTearDown(h.dispose);
    h.storage.value = session();
    await expectLater(h.repository.restore(), throwsA(isA<AuthException>()));
    expect(h.storage.value, isNotNull);
    expect(h.publicPaths, isEmpty);
  });
  test('logout clears locally even when server is unavailable', () async {
    final h = Harness(
      publicReply:
          (o) =>
              throw DioException(
                requestOptions: o,
                type: DioExceptionType.connectionError,
              ),
    );
    addTearDown(h.dispose);
    h.storage.value = session();
    await h.repository.restore();
    expect(await h.repository.logout(), AuthIssue.localLogout);
    expect(h.storage.value, isNull);
    await expectLater(
      h.repository.accessToken(),
      throwsA(isA<AuthException>()),
    );
  });
  test('logout during refresh cannot resurrect session', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final h = Harness(
      publicReply: (o) async {
        if (o.path.endsWith('/refresh')) {
          started.complete();
          await release.future;
          return jsonReply(authPayload('2'));
        }
        return jsonReply(null, 204);
      },
    );
    addTearDown(h.dispose);
    h.storage.value = session(expired: true);
    final restore = expectLater(
      h.repository.restore(),
      throwsA(isA<AuthException>()),
    );
    await started.future;
    await h.repository.logout();
    release.complete();
    await restore;
    expect(h.storage.value, isNull);
    expect(h.publicPaths.where((p) => p.endsWith('/logout')).length, 2);
  });
  test(
    'storage write failure never authenticates and revokes minted token',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      h.storage.failWrite = true;
      await expectLater(
        h.repository.login('deniz@example.com', 'Password1'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.issue,
            'issue',
            AuthIssue.storage,
          ),
        ),
      );
      expect(h.storage.value, isNull);
      expect(h.publicPaths.last, '/api/auth/logout');
    },
  );
  test('foreign origin is rejected before sending a bearer token', () async {
    final h = Harness();
    addTearDown(h.dispose);
    h.storage.value = session();
    await h.repository.restore();
    await expectLater(
      h.client.get<dynamic>('https://foreign.example/me'),
      throwsA(isA<DioException>()),
    );
    expect(h.protectedCalls, 1);
  });
  test(
    'configuration rejects missing URL, insecure default and embedded credentials',
    () {
      expect(const ApiConfig('').isValid, isFalse);
      expect(const ApiConfig('http://localhost:5080').isValid, isFalse);
      expect(
        const ApiConfig('http://10.0.2.2:5080', allowHttp: true).isValid,
        isTrue,
      );
      expect(
        const ApiConfig('https://user:password@example.com').isValid,
        isFalse,
      );
      expect(const ApiConfig('https://example.com').isValid, isTrue);
    },
  );
  test(
    'backend password policy includes Turkish letters and rejects controls',
    () {
      expect(AuthValidation.password('şifrem123'), isTrue);
      expect(AuthValidation.password('password'), isFalse);
      expect(AuthValidation.password('12345678'), isFalse);
      expect(AuthValidation.password('Pass12\n34'), isFalse);
      expect(AuthValidation.password('a1' * 65), isFalse);
    },
  );
  for (final entry
      in {
        400: AuthIssue.validation,
        401: AuthIssue.invalidCredentials,
        409: AuthIssue.duplicateEmail,
        429: AuthIssue.rateLimited,
        500: AuthIssue.unexpected,
      }.entries) {
    test('HTTP ${entry.key} maps without raw backend content', () {
      final request = RequestOptions(path: '/api/auth/login');
      expect(
        mapAuthIssue(
          DioException(
            requestOptions: request,
            response: Response(
              requestOptions: request,
              statusCode: entry.key,
              data: {'detail': 'SECRET database stack trace'},
            ),
          ),
        ),
        entry.value,
      );
    });
  }
}
