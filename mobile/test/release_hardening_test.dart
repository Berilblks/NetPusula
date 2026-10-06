import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/features/auth/domain/auth_issue.dart';
import 'support/auth_fakes.dart';

void main() {
  for (final status in [200, 500]) {
    test(
      'Late protected $status cannot cross logout/new-session boundary',
      () async {
        final entered = Completer<void>();
        final release = Completer<ResponseBody>();
        final h = Harness(
          protectedReply: (_) {
            entered.complete();
            return release.future;
          },
        );
        addTearDown(h.dispose);
        await h.repository.login('deniz@example.com', 'Password1');
        final pending = h.client.get<dynamic>('/api/mock-exams');
        final rejected = expectLater(
          pending,
          throwsA(
            isA<DioException>().having(
              (e) => (e.error as AuthException).issue,
              'session boundary',
              AuthIssue.sessionExpired,
            ),
          ),
        );
        await entered.future;
        await h.repository.logout();
        await h.repository.login('other@example.com', 'Password1');
        release.complete(jsonReply({'private': 'old-user-data'}, status));
        await rejected;
      },
    );
  }
  for (final status in [400, 403, 409, 429, 500]) {
    test('Protected $status never triggers refresh or retry', () async {
      final h = Harness(protectedReply: (_) => jsonReply({}, status));
      addTearDown(h.dispose);
      await h.repository.login('deniz@example.com', 'Password1');
      await expectLater(
        h.client.get<dynamic>('/api/mock-exams'),
        throwsA(isA<DioException>()),
      );
      expect(h.protectedCalls, 1);
      expect(h.publicPaths.where((p) => p.endsWith('/refresh')), isEmpty);
    });
  }
}
