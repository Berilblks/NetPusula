import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/features/auth/application/auth_controller.dart';
import 'package:netpusula/features/preparation/application/preparation_controller.dart';
import 'package:netpusula/features/preparation/data/preparation_repository.dart';
import 'package:netpusula/features/preparation/domain/preparation.dart';
import 'support/auth_fakes.dart';

void main() {
  test(
    'calendar difference uses dates, clamps past, and handles leap/month/year boundaries',
    () {
      expect(
        CalendarDate(
          2026,
          10,
          1,
        ).daysRemaining(const CalendarDate(2026, 9, 30)),
        1,
      );
      expect(
        CalendarDate(
          2026,
          9,
          30,
        ).daysRemaining(const CalendarDate(2026, 9, 30)),
        0,
      );
      expect(
        CalendarDate(
          2026,
          9,
          29,
        ).daysRemaining(const CalendarDate(2026, 9, 30)),
        0,
      );
      expect(
        CalendarDate(2028, 3, 1).daysRemaining(const CalendarDate(2028, 2, 28)),
        2,
      );
      expect(
        CalendarDate(
          2027,
          1,
          1,
        ).daysRemaining(const CalendarDate(2026, 12, 31)),
        1,
      );
      expect(
        CalendarDate.local(DateTime(2026, 9, 30, 23, 59)).iso,
        '2026-09-30',
      );
      expect(() => CalendarDate.parse('2026-02-30'), throwsFormatException);
    },
  );
  test('Turkish target decimals preserve exact four-place representation', () {
    expect(NetTarget.parse('80,125')!.units, 801250);
    expect(NetTarget.parse('80.125')!.turkish, '80,125');
    expect(NetTarget.fromJson(80.125).decimal, '80.125');
    expect(NetTarget.parse('0,0001')!.jsonNumber, 0.0001);
    expect(NetTarget.parse('99999999,9999'), isNotNull);
    for (final invalid in [
      '0',
      '-1',
      'abc',
      '1e2',
      'NaN',
      '80,12345',
      '100000000',
      '1.2.3',
      '',
    ]) {
      expect(NetTarget.parse(invalid), isNull, reason: invalid);
    }
  });
  test('204 alone means no preparation; malformed success does not', () async {
    final h = Harness(protectedReply: (_) => jsonReply(null, 204));
    addTearDown(h.dispose);
    await h.repository.login('deniz@example.com', 'Password1');
    final repo = PreparationRepository(h.client, h.public);
    expect(await repo.active(), isNull);
    h.client.httpClientAdapter = FakeAdapter((_) => jsonReply(null));
    await expectLater(repo.active(), throwsA(isA<TypeError>()));
  });
  test(
    'create and edit send exact contracts without ownership or exam mutation',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final paths = <String>[];
      final h = Harness(
        protectedReply: (o) {
          bodies.add(Map<String, dynamic>.from(o.data as Map));
          paths.add('${o.method} ${o.path}');
          return jsonReply(preparationPayload());
        },
      );
      addTearDown(h.dispose);
      await h.repository.login('deniz@example.com', 'Password1');
      final repo = PreparationRepository(h.client, h.public);
      final exam = Preparation.fromJson(preparationPayload()).exam;
      await repo.save(
        exam: exam,
        target: NetTarget.parse('80,125')!,
        date: const CalendarDate(2027, 1, 1),
      );
      await repo.save(
        id: 'prep-id',
        exam: exam,
        target: NetTarget.parse('81')!,
        date: const CalendarDate(2027, 1, 2),
      );
      expect(bodies[0], {
        'examId': 'exam-id',
        'targetNet': 80.125,
        'examDate': '2027-01-01',
      });
      expect(bodies[1], {'targetNet': 81, 'examDate': '2027-01-02'});
      expect(paths, ['POST /api/user-exams', 'PUT /api/user-exams/prep-id']);
    },
  );
  for (final entry
      in {
        400: PreparationIssue.validation,
        404: PreparationIssue.missing,
        409: PreparationIssue.conflict,
        429: PreparationIssue.rateLimited,
        500: PreparationIssue.unexpected,
      }.entries) {
    test('preparation HTTP ${entry.key} uses stable status not raw text', () {
      final request = RequestOptions(path: '/api/user-exams');
      expect(
        preparationIssue(
          DioException(
            requestOptions: request,
            response: Response(
              requestOptions: request,
              statusCode: entry.key,
              data: {'detail': 'private database content'},
            ),
          ),
        ),
        entry.value,
      );
    });
  }
  test(
    'controller prevents duplicate writes and ignores save completion after logout',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final h = Harness(
        protectedReply: (o) async {
          if (o.path == '/api/auth/me') return jsonReply(testUser);
          if (o.method == 'POST') {
            started.complete();
            await release.future;
            return jsonReply(preparationPayload());
          }
          return jsonReply(null, 204);
        },
      );
      h.storage.value = session();
      final c = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(h.repository)],
      );
      addTearDown(h.dispose);
      addTearDown(c.dispose);
      final ready = Completer<void>();
      c.listen(preparationControllerProvider, (_, state) {
        if (state.status == PreparationStatus.none && !ready.isCompleted) {
          ready.complete();
        }
      });
      await ready.future;
      final controller = c.read(preparationControllerProvider.notifier);
      final active = Preparation.fromJson(preparationPayload());
      final first = controller.save(
        exam: active.exam,
        target: active.target,
        date: active.date,
      );
      await started.future;
      expect(
        await controller.save(
          exam: active.exam,
          target: active.target,
          date: active.date,
        ),
        isFalse,
      );
      await c.read(authControllerProvider.notifier).logout();
      release.complete();
      expect(await first, isFalse);
      expect(c.read(preparationControllerProvider).active, isNull);
    },
  );
}
