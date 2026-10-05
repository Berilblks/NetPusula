import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/app/app.dart';
import 'package:netpusula/core/routing/app_router.dart';
import 'package:netpusula/features/auth/application/auth_controller.dart';
import 'package:netpusula/features/statistics/application/statistics_provider.dart';
import 'package:netpusula/features/statistics/domain/statistics.dart';
import 'package:netpusula/features/statistics/presentation/statistics_screen.dart';
import 'package:netpusula/features/dashboard/presentation/net_trend_chart.dart';
import 'package:netpusula/features/dashboard/domain/dashboard.dart';
import 'package:netpusula/features/mock_exams/application/mock_exam_controller.dart';
import 'package:netpusula/features/mock_exams/domain/mock_exam.dart';
import 'package:netpusula/features/preparation/application/preparation_controller.dart';
import 'mock_exam_test.dart' show MockHarness;
import 'support/auth_fakes.dart';
import 'widget_test.dart' show tapVisible;

Map<String, dynamic> statsPayload({
  int count = 6,
  String? change = '4.25',
  String range = '20',
}) {
  Map<String, dynamic> metrics(int n) => {
    'attemptCount': n,
    'latestNet': n == 0 ? null : '78.5',
    'averageNet': n == 0 ? null : '74.25',
    'bestNet': n == 0 ? null : '81.125',
    'worstNet': n == 0 ? null : '-0.125',
  };
  Map<String, dynamic> comparison(int n) => {
    'sufficientData': n >= 6 && change != null,
    'recentAverage': n >= 6 && change != null ? '75' : null,
    'previousAverage': n >= 6 && change != null ? '70.75' : null,
    'change': n >= 6 ? change : null,
  };
  final series = List.generate(
    count,
    (i) => {
      'mockExamId': i == count - 1 ? 'mock-1' : 'm$i',
      'name': 'Attempt $i',
      'takenAt': '2026-09-${(20 + i).toString().padLeft(2, '0')}',
      'totalNet': i == 0 ? '-0.125' : '78.5',
    },
  );
  return {
    'targetNet': '80',
    'range': {
      'selection': range,
      'limit': range == 'all' ? 500 : int.parse(range),
      'availableAttemptCount': count,
      'isCapped': false,
    },
    'summary': metrics(count),
    'improvement': comparison(count),
    'series': series,
    'bestMock': count == 0 ? null : series.last,
    'sections': [
      for (final id in ['s1', 's2'])
        {
          'examSectionId': id,
          'sectionName': id == 's1' ? 'Sayısal bölüm' : 'Yeni bölüm',
          'groupCode': 'G',
          'groupName': 'Grup başlığı',
          'isActive': true,
          ...metrics(id == 's1' ? count : 0),
          'improvement': comparison(id == 's1' ? count : 0),
          'answers': {
            'correct': id == 's1' && count > 0 ? '38.5' : null,
            'wrong': id == 's1' && count > 0 ? '6.25' : null,
            'blank': id == 's1' && count > 0 ? '5.25' : null,
          },
          'series':
              id == 's2'
                  ? []
                  : series
                      .map(
                        (p) => {
                          'mockExamId': p['mockExamId'],
                          'takenAt': p['takenAt'],
                          'net': p['totalNet'],
                          'correctCount': 38,
                          'wrongCount': 6,
                          'blankCount': 6,
                        },
                      )
                      .toList(),
        },
    ],
    'activity': {
      'firstMockDate': count == 0 ? null : '2026-09-20',
      'lastMockDate': count == 0 ? null : '2026-09-25',
      'attemptCount': count,
      'averageDaysBetweenMocks': count < 2 ? null : '1.25',
    },
  };
}

class FakeStatistics extends StatisticsRepository {
  FakeStatistics() : super(Dio());
  Map<String, dynamic> payload = statsPayload();
  Object? error;
  final calls = <String>[];
  final gates = <String, Completer<Statistics>>{};
  @override
  Future<Statistics> get(String range) async {
    calls.add(range);
    if (gates.containsKey(range)) return gates[range]!.future;
    if (error != null) throw error!;
    return Statistics({
      ...payload,
      'range': {...payload['range'] as Map, 'selection': range},
    });
  }
}

Future<ProviderContainer> mountStats(
  WidgetTester t,
  FakeStatistics f, {
  bool settle = true,
  bool navigate = true,
  MockHarness? harness,
}) async {
  final h = harness ?? MockHarness();
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(h.h.repository),
      statisticsRepositoryProvider.overrideWithValue(f),
      localNowProvider.overrideWithValue(() => DateTime(2026, 9, 30)),
    ],
  );
  addTearDown(c.dispose);
  addTearDown(h.h.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(container: c, child: const NetPusulaApp()),
  );
  await t.pumpAndSettle();
  if (navigate) {
    await t.ensureVisible(find.text('Detaylı İstatistikler'));
    await t.pump();
    await t.tap(find.text('Detaylı İstatistikler'));
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump();
      await t.pump();
    }
  }
  return c;
}

void main() {
  testWidgets('Dashboard entry opens dedicated statistics', (t) async {
    await mountStats(t, FakeStatistics());
    expect(find.byType(StatisticsScreen), findsOneWidget);
    expect(find.text('İstatistikler'), findsOneWidget);
  });
  testWidgets('Loading then server data', (t) async {
    final f = FakeStatistics();
    final gate = Completer<Statistics>();
    f.gates['20'] = gate;
    await mountStats(t, f, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete(Statistics(statsPayload()));
    await t.pumpAndSettle();
    expect(find.text('Genel Bakış'), findsOneWidget);
  });
  testWidgets('Zero attempts and add CTA', (t) async {
    await mountStats(t, FakeStatistics()..payload = statsPayload(count: 0));
    expect(
      find.text('Henüz istatistik oluşturacak denemen yok.'),
      findsOneWidget,
    );
    expect(find.byType(NetTrendChart), findsNothing);
    await tapVisible(t, find.text('İlk Denemeni Ekle'));
    expect(find.text('Yeni Deneme'), findsOneWidget);
  });
  testWidgets('One attempt has no fabricated comparison', (t) async {
    await mountStats(t, FakeStatistics()..payload = statsPayload(count: 1));
    expect(
      find.text('Karşılaştırma için en az 6 deneme gerekli.'),
      findsNWidgets(2),
    );
    expect(find.text('78,50'), findsWidgets);
    expect(t.takeException(), isNull);
  });
  for (final type in ['network', 'server', 'noPreparation']) {
    testWidgets('Safe $type error and retry', (t) async {
      final f = FakeStatistics();
      final options = RequestOptions();
      f.error = DioException(
        requestOptions: options,
        type:
            type == 'network'
                ? DioExceptionType.connectionError
                : DioExceptionType.badResponse,
        response:
            type == 'network'
                ? null
                : Response(
                  requestOptions: options,
                  statusCode: type == 'server' ? 500 : 409,
                  data: {'code': 'active_preparation_required'},
                ),
      );
      final c = await mountStats(t, f);
      expect(
        find.text('Henüz istatistik oluşturacak denemen yok.'),
        findsNothing,
      );
      expect(
        c.read(preparationControllerProvider).status,
        PreparationStatus.ready,
      );
      expect(
        find.text(
          type == 'noPreparation' ? 'Hazırlığı Kontrol Et' : 'Tekrar Dene',
        ),
        findsOneWidget,
      );
      if (type != 'noPreparation') {
        f.error = null;
        await tapVisible(t, find.text('Tekrar Dene'));
        expect(find.text('Genel Bakış'), findsOneWidget);
      }
    });
  }
  for (final range in ['5', '10', '20', 'all']) {
    testWidgets('Select range $range sends range only', (t) async {
      final f = FakeStatistics();
      await mountStats(t, f);
      await t.tap(find.byKey(Key('statistics.range.$range')));
      await t.pumpAndSettle();
      expect(f.calls.last, range);
      expect(
        t
            .widget<ChoiceChip>(find.byKey(Key('statistics.range.$range')))
            .selected,
        isTrue,
      );
    });
  }
  testWidgets('Rapid range switching ignores late older response', (t) async {
    final f = FakeStatistics();
    await mountStats(t, f);
    final old = Completer<Statistics>();
    f.gates['5'] = old;
    await t.tap(find.byKey(const Key('statistics.range.5')));
    await t.pump();
    await t.tap(find.byKey(const Key('statistics.range.10')));
    await t.pumpAndSettle();
    final stale = statsPayload(range: '5');
    stale['summary']['latestNet'] = '999';
    old.complete(Statistics(stale));
    await t.pumpAndSettle();
    expect(find.text('999,00'), findsNothing);
    expect(
      t
          .widget<ChoiceChip>(find.byKey(const Key('statistics.range.10')))
          .selected,
      isTrue,
    );
  });
  for (final pair in [
    ('average', '74,25'),
    ('latest', '78,50'),
    ('best', '81,13'),
    ('worst', '-0,13'),
  ]) {
    testWidgets('General and section ${pair.$1} render backend values', (
      t,
    ) async {
      await mountStats(t, FakeStatistics());
      expect(find.text(pair.$2), findsNWidgets(2));
    });
  }
  testWidgets('Best mock uses existing detail route', (t) async {
    await mountStats(t, FakeStatistics());
    expect(find.text('Attempt 5'), findsOneWidget);
    await tapVisible(t, find.byKey(const Key('statistics.best')));
    expect(find.text('81,13 net'), findsOneWidget);
  });
  for (final count in [0, 1, 3]) {
    testWidgets('Chart handles $count points and negatives', (t) async {
      await mountStats(
        t,
        FakeStatistics()..payload = statsPayload(count: count),
      );
      final charts = t.widgetList<NetTrendChart>(find.byType(NetTrendChart));
      expect(charts.length, count == 0 ? 0 : 2);
      if (count > 0) {
        expect(charts.first.points.length, count);
        expect(charts.first.points.first.net.negative, isTrue);
        expect(charts.last.target, isNull);
      }
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Grouped selector missing section is null not zero', (t) async {
    await mountStats(t, FakeStatistics());
    expect(find.text('Grup başlığı'), findsOneWidget);
    await tapVisible(t, find.byKey(const Key('statistics.section.s2')));
    expect(find.text('Bu bölüm için henüz veri yok.'), findsOneWidget);
    expect(find.byType(AnswerDistribution), findsNothing);
    expect(find.byType(NetTrendChart), findsOneWidget);
  });
  testWidgets('Section graph and answer averages have accessible readouts', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await mountStats(t, FakeStatistics());
    expect(find.byType(NetTrendChart), findsNWidgets(2));
    await t.ensureVisible(find.byType(AnswerDistribution));
    await t.pump();
    expect(find.text('Ortalama Doğru: 38,50'), findsOneWidget);
    expect(find.text('Ortalama Yanlış: 6,25'), findsOneWidget);
    expect(find.text('Ortalama Boş: 5,25'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    expect(find.bySemanticsLabel('Ortalama Doğru: 38,50'), findsOneWidget);
    semantics.dispose();
  });
  testWidgets('Answer history shows per-attempt evolution', (t) async {
    await mountStats(t, FakeStatistics());
    await tapVisible(t, find.text('Denemelere göre doğru / yanlış / boş'));
    expect(find.textContaining('38').evaluate().length, greaterThan(1));
  });
  for (final change in ['4.25', '-1.5', null]) {
    testWidgets('Neutral change $change', (t) async {
      await mountStats(
        t,
        FakeStatistics()..payload = statsPayload(change: change),
      );
      expect(
        find.textContaining(
          change == null
              ? 'en az 6'
              : change == '4.25'
              ? '+4,25 net'
              : '-1,50 net',
        ),
        findsNWidgets(2),
      );
    });
  }
  testWidgets('Activity includes dates and decimal interval', (t) async {
    await mountStats(t, FakeStatistics());
    expect(find.text('1,25'), findsOneWidget);
    expect(find.text('İlk deneme'), findsOneWidget);
    expect(find.text('Son deneme'), findsOneWidget);
  });
  testWidgets('Same-day interval is displayed as zero', (t) async {
    final p = statsPayload();
    p['activity']['averageDaysBetweenMocks'] = '0';
    await mountStats(t, FakeStatistics()..payload = p);
    expect(find.text('0,00'), findsOneWidget);
  });
  testWidgets('All cap is visible', (t) async {
    final p = statsPayload(range: 'all');
    p['range']['isCapped'] = true;
    p['range']['availableAttemptCount'] = 600;
    await mountStats(t, FakeStatistics()..payload = p);
    expect(find.textContaining('son 500'), findsOneWidget);
  });
  testWidgets('Pull refresh retains selected filter', (t) async {
    final f = FakeStatistics();
    await mountStats(t, f);
    await t.tap(find.byKey(const Key('statistics.range.5')));
    await t.pumpAndSettle();
    final before = f.calls.length;
    await t.drag(find.byType(SingleChildScrollView).last, const Offset(0, 450));
    await t.pumpAndSettle();
    expect(f.calls.length, before + 1);
    expect(f.calls.last, '5');
  });
  for (final operation in ['create', 'edit', 'delete']) {
    testWidgets('$operation invalidates statistics', (t) async {
      final f = FakeStatistics();
      final c = await mountStats(t, f);
      final sub = c.listen(mockMutationProvider, (_, __) {});
      addTearDown(sub.close);
      final before = f.calls.length;
      final controller = c.read(mockMutationProvider.notifier);
      late Future<Object?> pending;
      if (operation == 'delete') {
        pending = controller.delete('mock-1');
      } else {
        final draft = MockDraft.edit(
          MockExam.fromJson({
            'id': 'mock-1',
            'name': 'Changed',
            'takenAt': '2026-09-29',
            'totalNet': '1',
            'results': [],
          }),
        );
        pending = controller.save(
          operation == 'edit'
              ? draft
              : MockDraft(draft.date, name: draft.name, answers: []),
        );
      }
      await t.pumpAndSettle();
      await pending;
      await t.pumpAndSettle();
      expect(f.calls.length, before + 1);
    });
  }
  testWidgets('Logout discards late statistics', (t) async {
    final f = FakeStatistics();
    final c = await mountStats(t, f);
    final gate = Completer<Statistics>();
    f.gates['20'] = gate;
    c.invalidate(statisticsProvider);
    await t.pump();
    final logout = c.read(authControllerProvider.notifier).logout();
    await t.pumpAndSettle();
    await logout;
    gate.complete(Statistics(statsPayload()));
    await t.pumpAndSettle();
    expect(find.byType(StatisticsScreen), findsNothing);
    expect(find.text('74,25'), findsNothing);
  });
  testWidgets('Back from detail retains range selection', (t) async {
    final f = FakeStatistics();
    final c = await mountStats(t, f);
    await t.tap(find.byKey(const Key('statistics.range.10')));
    await t.pumpAndSettle();
    await tapVisible(t, find.byKey(const Key('statistics.best')));
    c.read(appRouterProvider).pop();
    await t.pumpAndSettle();
    expect(
      t
          .widget<ChoiceChip>(find.byKey(const Key('statistics.range.10')))
          .selected,
      isTrue,
    );
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('Small screen at text scale $scale', (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await mountStats(t, FakeStatistics());
      await t.ensureVisible(find.text('Deneme Düzeni'));
      await t.pump();
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('New user cannot receive previous user pending analytics', (
    t,
  ) async {
    final h = MockHarness();
    final f = FakeStatistics();
    final c = await mountStats(t, f, harness: h);
    final old = Completer<Statistics>();
    f.gates['20'] = old;
    c.invalidate(statisticsProvider);
    await t.pump();
    final logout = c.read(authControllerProvider.notifier).logout();
    await t.pumpAndSettle();
    await logout;
    h.h.public.httpClientAdapter = FakeAdapter(
      (_) => jsonReply({
        ...authPayload('new'),
        'user': {
          'id': 'new-user',
          'displayName': 'Yeni',
          'email': 'new@example.test',
        },
      }),
    );
    f.gates.clear();
    f.payload = statsPayload(count: 0);
    final login = c
        .read(authControllerProvider.notifier)
        .login('new@example.test', 'Example password 42');
    await t.pumpAndSettle();
    expect(await login, isTrue);
    await tapVisible(t, find.text('Detaylı İstatistikler'));
    old.complete(Statistics(statsPayload()));
    await t.pumpAndSettle();
    expect(c.read(authControllerProvider).user!.id, 'new-user');
    expect(
      find.text('Henüz istatistik oluşturacak denemen yok.'),
      findsOneWidget,
    );
    expect(find.text('74,25'), findsNothing);
  });
  test('Strict decimal string parsing and exact formatting', () {
    expect(Score('-0.125').display, '-0,13');
    final p = statsPayload();
    p['summary']['averageNet'] = 0.1;
    expect(() => Statistics(p), throwsA(isA<TypeError>()));
  });
  test('Malformed aggregate is error instead of empty', () {
    final p = statsPayload(count: 0);
    p['summary']['averageNet'] = '0';
    expect(() => Statistics(p), throwsFormatException);
  });
}
