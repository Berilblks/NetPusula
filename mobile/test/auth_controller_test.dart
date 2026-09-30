import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/features/auth/application/auth_controller.dart';
import 'package:netpusula/features/auth/domain/auth_issue.dart';
import 'support/auth_fakes.dart';

void main() {
  test(
    'controller prevents duplicate login and exposes safe busy/auth states',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final h = Harness(
        publicReply: (_) async {
          started.complete();
          await release.future;
          return jsonReply(authPayload());
        },
      );
      final c = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(h.repository)],
      );
      addTearDown(h.dispose);
      addTearDown(c.dispose);
      final ready = Completer<void>();
      c.listen(authControllerProvider, (_, state) {
        if (state.status == AuthStatus.unauthenticated && !ready.isCompleted) {
          ready.complete();
        }
      });
      await ready.future;
      final controller = c.read(authControllerProvider.notifier);
      final first = controller.login('deniz@example.com', 'Password1');
      await started.future;
      expect(c.read(authControllerProvider).busy, isTrue);
      expect(await controller.login('deniz@example.com', 'Password1'), isFalse);
      expect(h.publicPaths.length, 1);
      release.complete();
      expect(await first, isTrue);
      expect(c.read(authControllerProvider).user!.displayName, 'Deniz');
      expect(c.read(authControllerProvider).busy, isFalse);
    },
  );
  test('failed refresh clears authenticated controller state', () async {
    final h = Harness(
      publicReply:
          (o) =>
              o.path.endsWith('/refresh')
                  ? jsonReply({}, 401)
                  : jsonReply(authPayload()),
    );
    final c = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(h.repository)],
    );
    addTearDown(h.dispose);
    addTearDown(c.dispose);
    final ready = Completer<void>();
    c.listen(authControllerProvider, (_, state) {
      if (state.status == AuthStatus.unauthenticated && !ready.isCompleted) {
        ready.complete();
      }
    });
    await ready.future;
    await c
        .read(authControllerProvider.notifier)
        .login('deniz@example.com', 'Password1');
    await expectLater(
      h.repository.refreshAfterUnauthorized('access-1'),
      throwsA(isA<AuthException>()),
    );
    expect(c.read(authControllerProvider).status, AuthStatus.unauthenticated);
    expect(c.read(authControllerProvider).user, isNull);
    expect(c.read(authControllerProvider).issue, AuthIssue.sessionExpired);
  });
}
