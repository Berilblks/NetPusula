import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/app/app.dart';
import 'package:netpusula/features/auth/application/auth_controller.dart';
import 'package:netpusula/features/dashboard/application/dashboard_provider.dart';
import 'package:netpusula/features/dashboard/domain/dashboard.dart';
import 'package:netpusula/features/dashboard/presentation/net_trend_chart.dart';
import 'package:netpusula/features/mock_exams/application/mock_exam_controller.dart';
import 'package:netpusula/features/mock_exams/domain/mock_exam.dart';
import 'package:netpusula/features/preparation/application/preparation_controller.dart';
import 'support/auth_fakes.dart';
import 'mock_exam_test.dart' show MockHarness;
import 'widget_test.dart' show tapVisible;

Map<String, dynamic> populated({
  String difference = '11.5',
  String? change = '4.25',
  int points = 6,
}) {
  final j = dashboardPayload(target: '90');
  j['summary'] = {
    'mockExamCount': points,
    'latestNet': '78.5',
    'averageNet': '74.25',
    'bestNet': '81',
    'targetDifference': difference,
  };
  final trend = List.generate(
    points,
    (i) => {
      'mockExamId': i == points - 1 ? 'mock-1' : 'm$i',
      'name': 'Recent $i',
      'takenAt': '2026-09-${(20 + i).toString().padLeft(2, '0')}',
      'totalNet': '${70 + i}.25',
    },
  );
  j['trend'] = trend;
  j['recentMocks'] = trend.reversed.take(3).toList();
  j['sections'] = [
    {
      'examSectionId': 's1',
      'sectionName': 'Sayısal bölüm',
      'groupCode': 'G',
      'groupName': 'Grup başlığı',
      'isActive': true,
      'questionCount': 50,
      'attemptCount': points,
      'latestNet': '40.5',
      'averageNet': '38.2',
      'bestNet': '42',
    },
    {
      'examSectionId': 's2',
      'sectionName': 'Yeni bölüm',
      'groupCode': 'G',
      'groupName': 'Grup başlığı',
      'isActive': true,
      'questionCount': 50,
      'attemptCount': 0,
      'latestNet': null,
      'averageNet': null,
      'bestNet': null,
    },
  ];
  j['improvement'] = {
    'hasEnoughData': change != null,
    'recentAverage': change != null ? '75' : null,
    'previousAverage': change != null ? '70.75' : null,
    'change': change,
  };
  return j;
}

class FakeDashboard extends DashboardRepository {
  FakeDashboard() : super(Dio());
  Map<String, dynamic> payload = populated();
  Object? error;
  Completer<void>? gate;
  int calls = 0;
  @override
  Future<Dashboard> get() async {
    calls++;
    await gate?.future;
    if (error != null) throw error!;
    return Dashboard(payload);
  }
}

Future<ProviderContainer> mountDashboard(
  WidgetTester t,
  FakeDashboard fake, {
  MockHarness? harness,
  bool settle = true,
}) async {
  final h = harness ?? MockHarness();
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(h.h.repository),
      dashboardRepositoryProvider.overrideWithValue(fake),
      localNowProvider.overrideWithValue(() => DateTime(2026, 9, 30)),
    ],
  );
  addTearDown(c.dispose);
  addTearDown(h.h.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(container: c, child: const NetPusulaApp()),
  );
  if (settle) {
    await t.pumpAndSettle();
  } else {
    for (var i = 0; i < 10; i++) {
      await t.pump();
    }
  }
  return c;
}

void main() {
  testWidgets('Dashboard loading then populated', (t) async {
    final f = FakeDashboard()..gate = Completer<void>();
    await mountDashboard(t, f, settle: false);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    f.gate!.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('dashboard.latest')), findsOneWidget);
  });
  testWidgets('Preparation greeting target and date', (t) async {
    await mountDashboard(t, FakeDashboard());
    expect(find.text('Merhaba, Deniz'), findsOneWidget);
    expect(find.text('Test ALES'), findsOneWidget);
    expect(find.text('90 net'), findsOneWidget);
    expect(find.text('93 gün kaldı'), findsOneWidget);
  });
  for (final entry in [
    ('latest', '78,50'),
    ('average', '74,25'),
    ('best', '81,00'),
  ]) {
    testWidgets('Server metric ${entry.$1}', (t) async {
      await mountDashboard(t, FakeDashboard());
      expect(find.text(entry.$2), findsOneWidget);
    });
  }
  for (final pair in [
    ('11.5', 'Hedefe Kalan: 11,50 net'),
    ('0', 'Hedefe ulaştın'),
    ('-2.125', 'Hedefin üzerinde: 2,13 net'),
  ]) {
    testWidgets('Signed difference ${pair.$1}', (t) async {
      final f = FakeDashboard()..payload = populated(difference: pair.$1);
      await mountDashboard(t, f);
      expect(find.text(pair.$2), findsOneWidget);
    });
  }
  testWidgets('Empty shows CTA without fabricated metrics', (t) async {
    final f = FakeDashboard()..payload = dashboardPayload();
    await mountDashboard(t, f);
    expect(find.text('Henüz deneme eklemedin.'), findsOneWidget);
    expect(find.text('İlk Denemeni Ekle'), findsOneWidget);
    expect(find.byKey(const Key('dashboard.latest')), findsNothing);
    expect(find.byKey(const Key('dashboard.chart')), findsNothing);
  });
  for (final points in [1, 6]) {
    testWidgets('Chart safe with $points points', (t) async {
      final f =
          FakeDashboard()
            ..payload = populated(
              points: points,
              change: points < 6 ? null : '4.25',
            );
      await mountDashboard(t, f);
      final painter =
          t
                  .widget<CustomPaint>(find.byKey(const Key('dashboard.chart')))
                  .painter!
              as NetTrendPainter;
      expect(painter.values.length, points);
      expect(painter.target, 90);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Chart target reference and accessible point labels', (t) async {
    final semantics = t.ensureSemantics();

    await mountDashboard(t, FakeDashboard());
    expect(
      find.bySemanticsLabel(RegExp('Net Gelişimi.*Recent 0')),
      findsOneWidget,
    );
    expect(find.textContaining('kesikli çizgi'), findsOneWidget);
    semantics.dispose();
  });
  testWidgets('Chart negative and large values safe', (t) async {
    final f = FakeDashboard()..payload = populated();
    (f.payload['trend'] as List)[0]['totalNet'] = '-12.5';
    (f.payload['trend'] as List)[1]['totalNet'] = '99999999999.9999';
    await mountDashboard(t, f);
    await t.ensureVisible(find.byKey(const Key('dashboard.chart')));
    await t.pump();
    expect(t.takeException(), isNull);
  });
  testWidgets('Section cards use server data and dynamic group', (t) async {
    await mountDashboard(t, FakeDashboard());
    expect(find.text('Grup başlığı'), findsOneWidget);
    expect(find.text('Sayısal bölüm'), findsOneWidget);
    expect(find.text('40,50'), findsOneWidget);
    expect(find.text('38,20'), findsOneWidget);
    expect(find.text('42,00'), findsOneWidget);
  });
  testWidgets('No-data section distinct from real zero', (t) async {
    final f = FakeDashboard();
    (f.payload['sections'] as List)[0]['latestNet'] = '0';
    await mountDashboard(t, f);
    expect(find.text('Henüz veri yok'), findsOneWidget);
    expect(find.text('0,00'), findsOneWidget);
  });
  for (final change in ['4.25', '-1.5', null]) {
    testWidgets('Neutral improvement $change', (t) async {
      final f = FakeDashboard()..payload = populated(change: change);
      await mountDashboard(t, f);
      expect(
        find.text(
          change == null
              ? 'Gelişim karşılaştırması için en az 6 deneme gerekli.'
              : 'Son 3 deneme ortalaman önceki 3 denemeye göre ${change == '4.25' ? '+4,25' : '-1,50'} net.',
        ),
        findsOneWidget,
      );
    });
  }
  testWidgets('Recent bounded cards navigate existing detail', (t) async {
    await mountDashboard(t, FakeDashboard());
    expect(find.text('Recent 5'), findsOneWidget);
    expect(find.text('Recent 2'), findsNothing);
    await tapVisible(t, find.byKey(const Key('dashboard.recent.mock-1')));
    expect(find.text('81,13 net'), findsOneWidget);
  });
  testWidgets('History access reuses existing route', (t) async {
    await mountDashboard(t, FakeDashboard());
    await tapVisible(t, find.text('Deneme Geçmişi'));
    expect(find.text('Deneme 1'), findsOneWidget);
  });
  testWidgets('Add CTA uses existing form', (t) async {
    await mountDashboard(t, FakeDashboard());
    await tapVisible(t, find.text('Deneme Ekle'));
    expect(find.text('Yeni Deneme'), findsOneWidget);
  });
  testWidgets('Pull to refresh fetches server again', (t) async {
    final f = FakeDashboard();
    await mountDashboard(t, f);
    final n = f.calls;
    (f.payload['summary'] as Map)['latestNet'] = '99';
    await t.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 450),
    );
    await t.pumpAndSettle();
    expect(f.calls, n + 1);
    expect(find.text('99,00'), findsOneWidget);
  });
  for (final type in ['network', 'server', 'noPreparation']) {
    testWidgets('Error $type is never empty statistics', (t) async {
      final f = FakeDashboard();
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
      final c = await mountDashboard(t, f);
      expect(find.text('Henüz deneme eklemedin.'), findsNothing);
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
        expect(find.text('78,50'), findsOneWidget);
      }
    });
  }
  for (final operation in ['create', 'edit', 'delete']) {
    testWidgets('$operation invalidates dashboard', (t) async {
      final f = FakeDashboard();
      final c = await mountDashboard(t, f);
      final subscription = c.listen(mockMutationProvider, (_, __) {});
      addTearDown(subscription.close);
      final before = f.calls;
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
      expect(f.calls, before + 1);
    });
  }
  testWidgets('Logout discards late dashboard response', (t) async {
    final f = FakeDashboard();
    final c = await mountDashboard(t, f);
    f.gate = Completer<void>();
    c.invalidate(dashboardProvider);
    await t.pump();
    final logout = c.read(authControllerProvider.notifier).logout();
    await t.pumpAndSettle();
    await logout;
    f.gate!.complete();
    await t.pumpAndSettle();
    expect(find.text('78,50'), findsNothing);
    expect(find.text('Merhaba, Deniz'), findsNothing);
  });
  testWidgets('Small screen large text has no overflow', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await mountDashboard(t, FakeDashboard());
    await t.ensureVisible(find.text('Son Denemeler'));
    await t.pump();
    expect(t.takeException(), isNull);
  });
  test('Decimal signs and formatting are deterministic', () {
    expect(Score('-0.000').isZero, isTrue);
    expect(Score('-0.125').display, '-0,13');
    expect(Score('99999999999.9999').display, '100000000000,00');
  });
  test('Malformed score is an error, not empty dashboard', () {
    final j = populated();
    (j['summary'] as Map)['latestNet'] = 0.1;
    expect(() => Dashboard(j), throwsA(isA<TypeError>()));
  });
}
