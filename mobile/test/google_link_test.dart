import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/core/routing/app_router.dart';
import 'package:netpusula/features/auth/domain/auth_issue.dart';
import 'support/auth_fakes.dart';
import 'google_auth_test.dart' show FakeGoogle, mountGoogle;
import 'widget_test.dart' show tapVisible;

void main() {
  testWidgets(
    'Account links with password and authenticated API, then shows linked',
    (t) async {
      Map? submitted;
      String? authorization;
      final h = Harness(
        protectedReply: (o) {
          if (o.path == '/api/auth/google/link') {
            submitted = Map.from(o.data as Map);
            authorization = o.headers['Authorization'] as String?;
            return jsonReply({...testUser, 'googleLinked': true});
          }
          if (o.path == '/api/user-exams/active') {
            return jsonReply(preparationPayload());
          }
          return jsonReply(testUser);
        },
      );
      h.storage.value = session();
      await mountGoogle(t, h, FakeGoogle(), route: '/account');
      expect(find.text('Hesap Ayarları'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'test-password');
      await tapVisible(
        t,
        find.widgetWithText(FilledButton, 'Google Hesabını Bağla'),
      );
      expect(submitted?['currentPassword'], 'test-password');
      expect(submitted?['idToken'], 'google-id-token-test-only');
      expect(authorization, 'Bearer access-1');
      expect(find.text('Google hesabı bağlı'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(h.storage.value!.accessToken, 'access-1');
    },
  );
  for (final code in ['reauth_required', 'google_link_conflict']) {
    testWidgets('Account shows friendly $code without losing session', (
      t,
    ) async {
      final h = Harness(
        protectedReply:
            (o) =>
                o.path == '/api/auth/google/link'
                    ? jsonReply({
                      'code': code,
                      'detail': 'RAW-SENSITIVE-DETAIL',
                    }, code == 'reauth_required' ? 400 : 409)
                    : o.path == '/api/user-exams/active'
                    ? jsonReply(preparationPayload())
                    : jsonReply(testUser),
      );
      h.storage.value = session();
      final c = await mountGoogle(t, h, FakeGoogle(), route: '/account');
      await t.enterText(find.byType(TextField), 'test-password');
      await tapVisible(
        t,
        find.widgetWithText(FilledButton, 'Google Hesabını Bağla'),
      );
      expect(
        find.textContaining(
          code == 'reauth_required'
              ? 'şifren doğrulanamadı'
              : 'başka bir hesaba bağlı',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('RAW-SENSITIVE'), findsNothing);
      expect(
        c.read(appRouterProvider).routeInformationProvider.value.uri.path,
        '/account',
      );
      expect(h.storage.value, isNotNull);
    });
  }
  testWidgets(
    'Cancel does not call link; account supports large text and keyboard',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      t.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(t.view.reset);
      var links = 0;
      final h = Harness(
        protectedReply: (o) {
          if (o.path == '/api/auth/google/link') links++;
          return o.path == '/api/user-exams/active'
              ? jsonReply(preparationPayload())
              : jsonReply(testUser);
        },
      );
      h.storage.value = session();
      await mountGoogle(
        t,
        h,
        FakeGoogle()..token = null,
        route: '/account',
        wrap:
            (w) => MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: w,
            ),
      );
      await t.enterText(find.byType(TextField), 'test-password');
      await tapVisible(
        t,
        find.widgetWithText(FilledButton, 'Google Hesabını Bağla'),
      );
      expect(links, 0);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Unauthenticated account route is guarded', (t) async {
    final h = Harness();
    final c = await mountGoogle(t, h, FakeGoogle(), route: '/account');
    expect(
      c.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/welcome',
    );
  });
  test('Late link response after logout cannot restore session', () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    final h = Harness(
      protectedReply: (o) async {
        if (o.path == '/api/auth/google/link') {
          started.complete();
          await gate.future;
        }
        return jsonReply({...testUser, 'googleLinked': true});
      },
    );
    addTearDown(h.dispose);
    await h.repository.login('local@example.test', 'test-password');
    final pending = h.repository.linkGoogle('test-id-token', 'test-password');
    final check = expectLater(
      pending,
      throwsA(
        predicate((error) => mapAuthIssue(error!) == AuthIssue.sessionExpired),
      ),
    );
    await started.future;
    await h.repository.logout();
    gate.complete();
    await check;
    expect(h.storage.value, isNull);
  });
}
