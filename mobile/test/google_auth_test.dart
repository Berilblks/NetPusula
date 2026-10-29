import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/app/app.dart';
import 'package:netpusula/core/routing/app_router.dart';
import 'package:netpusula/features/auth/application/auth_controller.dart';
import 'package:netpusula/features/auth/data/google_identity_client.dart';
import 'package:netpusula/features/auth/domain/auth_issue.dart';
import 'support/auth_fakes.dart';
import 'widget_test.dart' show tapVisible;

class FakeGoogle implements GoogleIdentityClient {
  String? token = 'google-id-token-test-only';
  Object? error;
  Completer<void>? gate;
  int calls = 0;
  @override
  Future<String?> selectIdToken() async {
    calls++;
    await gate?.future;
    if (error != null) throw error!;
    return token;
  }
}

Future<ProviderContainer> mountGoogle(
  WidgetTester t,
  Harness h,
  FakeGoogle google, {
  String route = '/login',
  Widget Function(Widget)? wrap,
}) async {
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(h.repository),
      googleIdentityClientProvider.overrideWithValue(google),
    ],
  );
  addTearDown(c.dispose);
  addTearDown(h.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: wrap?.call(const NetPusulaApp()) ?? const NetPusulaApp(),
    ),
  );
  await t.pumpAndSettle();
  c.read(appRouterProvider).go(route);
  await t.pumpAndSettle();
  return c;
}

void main() {
  for (final route in ['/login', '/register']) {
    testWidgets(
      '$route Google exchanges only ID token and stores application session',
      (t) async {
        Map<String, dynamic>? submitted;
        final h = Harness(
          publicReply: (o) {
            submitted = Map<String, dynamic>.from(o.data as Map);
            return jsonReply(authPayload());
          },
        );
        final c = await mountGoogle(t, h, FakeGoogle(), route: route);
        expect(find.text('NetPusula'), findsOneWidget);
        expect(find.text('Sınav yolculuğunda yanında.'), findsOneWidget);
        await tapVisible(t, find.byKey(const Key('auth.google')));
        expect(submitted, {'idToken': 'google-id-token-test-only'});
        expect(h.publicPaths, ['/api/auth/google']);
        expect(h.storage.value!.accessToken, 'access-1');
        expect(h.storage.value!.refreshToken, 'refresh-1');
        expect(c.read(authControllerProvider).status, AuthStatus.authenticated);
        expect(find.text('Merhaba, Deniz'), findsOneWidget);
      },
    );
  }
  testWidgets('Google cancellation is silent and makes no backend request', (
    t,
  ) async {
    final h = Harness();
    final c = await mountGoogle(t, h, FakeGoogle()..token = null);
    await tapVisible(t, find.byKey(const Key('auth.google')));
    expect(c.read(authControllerProvider).busy, isFalse);
    expect(c.read(authControllerProvider).issue, isNull);
    expect(h.storage.value, isNull);
    expect(h.publicPaths, isEmpty);
  });
  for (final entry
      in {
        'google_rejected': 401,
        'google_conflict': 409,
        'google_unavailable': 503,
      }.entries) {
    testWidgets('Google ${entry.key} is friendly and does not authenticate', (
      t,
    ) async {
      final h = Harness(
        publicReply:
            (_) => jsonReply({
              'code': entry.key,
              'detail': 'raw internal secret',
            }, entry.value),
      );
      final c = await mountGoogle(t, h, FakeGoogle());
      await tapVisible(t, find.byKey(const Key('auth.google')));
      expect(c.read(authControllerProvider).status, AuthStatus.unauthenticated);
      expect(c.read(authControllerProvider).issue, isNotNull);
      expect(find.textContaining('raw internal secret'), findsNothing);
      expect(h.storage.value, isNull);
    });
  }
  testWidgets('Google backend network failure and retry', (t) async {
    var fail = true;
    final h = Harness(
      publicReply: (o) {
        if (fail) {
          throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          );
        }
        return jsonReply(authPayload());
      },
    );
    final c = await mountGoogle(t, h, FakeGoogle());
    await tapVisible(t, find.byKey(const Key('auth.google')));
    expect(c.read(authControllerProvider).issue, AuthIssue.network);
    fail = false;
    await tapVisible(t, find.byKey(const Key('auth.google')));
    expect(c.read(authControllerProvider).status, AuthStatus.authenticated);
  });
  testWidgets('Google SDK failure does not call backend', (t) async {
    final h = Harness();
    final c = await mountGoogle(
      t,
      h,
      FakeGoogle()..error = const AuthException(AuthIssue.googleRejected),
    );
    await tapVisible(t, find.byKey(const Key('auth.google')));
    expect(c.read(authControllerProvider).issue, AuthIssue.googleRejected);
    expect(h.publicPaths, isEmpty);
  });
  test(
    'Google selection blocks duplicate submit and disposed results',
    () async {
      final google = FakeGoogle()..gate = Completer<void>();
      final h = Harness();
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(h.repository),
          googleIdentityClientProvider.overrideWithValue(google),
        ],
      );
      final ready = Completer<void>();
      c.listen(authControllerProvider, (_, next) {
        if (next.status == AuthStatus.unauthenticated &&
            !next.busy &&
            !ready.isCompleted) {
          ready.complete();
        }
      }, fireImmediately: true);
      await ready.future;
      final controller = c.read(authControllerProvider.notifier);
      final pending = controller.google();
      expect(await controller.google(), isFalse);
      expect(google.calls, 1);
      c.dispose();
      google.gate!.complete();
      expect(await pending, isFalse);
      expect(h.publicPaths, isEmpty);
      expect(h.storage.value, isNull);
      h.dispose();
    },
  );
  testWidgets('First Google account follows existing preparation guard', (
    t,
  ) async {
    final h = Harness(
      protectedReply: (_) => jsonReply(null, 204),
      publicReply:
          (o) =>
              o.path == '/api/exams' ? jsonReply([]) : jsonReply(authPayload()),
    );
    final c = await mountGoogle(t, h, FakeGoogle());
    await tapVisible(t, find.byKey(const Key('auth.google')));
    expect(
      c.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/onboarding',
    );
  });
  test('Unconfigured platform never starts native Google flow', () async {
    await expectLater(
      SdkGoogleIdentityClient().selectIdToken(),
      throwsA(
        isA<AuthException>().having(
          (e) => e.issue,
          'issue',
          AuthIssue.googleUnavailable,
        ),
      ),
    );
  });
}
