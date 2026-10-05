import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/core/theme/app_theme.dart';
import 'package:netpusula/core/widgets/app_components.dart';
import 'package:netpusula/core/routing/app_router.dart';
import 'package:netpusula/features/dashboard/presentation/net_trend_chart.dart';
import 'package:netpusula/features/auth/presentation/auth_widgets.dart';
import 'package:netpusula/features/statistics/presentation/statistics_screen.dart';
import 'widget_test.dart' show mount, field, tapVisible;
import 'mock_exam_test.dart' show MockHarness, mountMock, newReview;
import 'preparation_widget_test.dart'
    show PreparationHarness, mountPreparation, toReview;
import 'dashboard_test.dart' show FakeDashboard, mountDashboard, populated;
import 'statistics_test.dart' show FakeStatistics, mountStats;
import 'support/auth_fakes.dart';

void narrow(WidgetTester t, double scale) {
  t.view.physicalSize = const Size(320, 640);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('Welcome 320px scale $scale actions remain reachable', (
      t,
    ) async {
      narrow(t, scale);
      await mount(t, Harness());
      await t.ensureVisible(find.text('Hesap Oluştur'));
      await t.pump();
      expect(
        find.text('Denemelerini takip et, gelişimini gör.'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });
    for (final register in [false, true]) {
      testWidgets(
        'Auth ${register ? 'register' : 'login'} 320px scale $scale',
        (t) async {
          narrow(t, scale);
          await mount(t, Harness());
          await tapVisible(
            t,
            find.text(register ? 'Hesap Oluştur' : 'Giriş Yap'),
          );
          final prefix = register ? 'register' : 'login';
          await tapVisible(t, find.byKey(Key('$prefix.submit')));
          expect(find.text('Geçerli bir e-posta adresi gir.'), findsOneWidget);
          expect(
            t
                .widget<TextField>(
                  find.descendant(
                    of: field('$prefix.email'),
                    matching: find.byType(TextField),
                  ),
                )
                .keyboardType,
            TextInputType.emailAddress,
          );
          expect(t.takeException(), isNull);
        },
      );
    }
    testWidgets('Onboarding target date review 320px scale $scale', (t) async {
      narrow(t, scale);
      await mountPreparation(t, PreparationHarness());
      await toReview(t);
      expect(find.text('Adım 5 / 5'), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('goal.save')));
      await t.pump();
      expect(find.text('80,25 net'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
    testWidgets('Dashboard 320px scale $scale hierarchy and target', (t) async {
      narrow(t, scale);
      await mountDashboard(t, FakeDashboard());
      expect(find.byKey(const Key('dashboard.latest')), findsOneWidget);
      expect(find.text('Hedefe Kalan: 11,50 net'), findsOneWidget);
      await t.ensureVisible(find.text('Son Denemeler'));
      await t.pump();
      expect(t.takeException(), isNull);
    });
    testWidgets('Statistics 320px scale $scale answer section and activity', (
      t,
    ) async {
      narrow(t, scale);
      await mountStats(t, FakeStatistics());
      await t.ensureVisible(find.byType(AnswerDistribution));
      await t.pump();
      expect(find.text('Ortalama Doğru: 38,50'), findsOneWidget);
      await t.ensureVisible(find.text('Deneme Düzeni'));
      await t.pump();
      expect(t.takeException(), isNull);
    });
    for (final route in ['/mock-exams', '/mock-exams/mock-1']) {
      testWidgets('$route 320px scale $scale', (t) async {
        narrow(t, scale);
        final c = await mountMock(t, MockHarness());
        c.read(appRouterProvider).go(route);
        await t.pumpAndSettle();
        expect(find.text('81,13 net'), findsOneWidget);
        if (route.endsWith('mock-1')) {
          await t.scrollUntilVisible(
            find.byKey(const Key('mock.delete')),
            180,
            scrollable: find.byType(Scrollable).last,
          );
          await t.pump();
        }
        expect(t.takeException(), isNull);
      });
    }
    testWidgets('Mock form review preserves draft at 320px scale $scale', (
      t,
    ) async {
      narrow(t, scale);
      await mountMock(t, MockHarness());
      await newReview(t);
      expect(find.text('Doğru: 42 · Yanlış: 6 · Boş: 2'), findsOneWidget);
      await tapVisible(t, find.byKey(const Key('mock.back')));
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('correct.section-1')))
            .initialValue,
        '42',
      );
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Selected exam has checked semantics and progress label', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await mountPreparation(t, PreparationHarness());
    await tapVisible(t, find.byKey(const Key('goal.next')));
    await tapVisible(t, find.byKey(const Key('exam.exam-id')));

    bool checked(SemanticsNode node) {
      if (node.hasFlag(SemanticsFlag.isChecked)) return true;
      var found = false;
      node.visitChildren((child) {
        found = checked(child) || found;
        return true;
      });
      return found;
    }

    expect(
      checked(t.getSemantics(find.byKey(const Key('exam.exam-id')))),
      isTrue,
    );
    expect(find.bySemanticsLabel('Adım 2 / 5'), findsOneWidget);
    semantics.dispose();
  });
  testWidgets(
    'Statistics selected range and section expose selected semantics',
    (t) async {
      final semantics = t.ensureSemantics();
      await mountStats(t, FakeStatistics());
      expect(
        t
            .getSemantics(find.byKey(const Key('statistics.range.20')))
            .hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      await t.ensureVisible(find.byKey(const Key('statistics.section.s1')));
      await t.pump();
      expect(
        t
            .getSemantics(find.byKey(const Key('statistics.section.s1')))
            .hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      semantics.dispose();
    },
  );
  testWidgets('Chart semantics include labels dates and signed values', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await mountStats(t, FakeStatistics());
    await t.ensureVisible(find.byType(NetTrendChart).first);
    await t.pump();
    expect(find.bySemanticsLabel(RegExp('Net Gelişimi.*-0,13')), findsWidgets);
    semantics.dispose();
  });
  testWidgets('Section answer bars retain individual accessible labels', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await mountStats(t, FakeStatistics());
    await t.ensureVisible(find.byType(AnswerDistribution));
    await t.pump();
    for (final label in [
      'Ortalama Doğru: 38,50',
      'Ortalama Yanlış: 6,25',
      'Ortalama Boş: 5,25',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    semantics.dispose();
  });
  testWidgets('Invalid counts announced near section and never saved', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    final h = MockHarness();
    await mountMock(t, h);
    await tapVisible(t, find.text('Deneme Ekle'));
    await t.enterText(find.byKey(const Key('mock.name')), 'Deneme');
    await tapVisible(t, find.byKey(const Key('mock.next')));
    await t.enterText(find.byKey(const Key('correct.section-1')), '51');
    await t.pump();
    expect(
      find.text('Doğru ve yanlış toplamı 50 soruyu aşamaz.'),
      findsOneWidget,
    );
    expect(find.byType(AppMessage), findsWidgets);
    await tapVisible(t, find.byKey(const Key('mock.next')));
    expect(h.saves, 0);
    expect(find.text('Boş: —'), findsOneWidget);
    semantics.dispose();
  });
  testWidgets('Keyboard-safe mock controls remain scrollable', (t) async {
    narrow(t, 1);
    await mountMock(t, MockHarness());
    await tapVisible(t, find.text('Deneme Ekle'));
    t.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(t.view.resetViewInsets);
    await t.pump();
    await t.scrollUntilVisible(
      find.byKey(const Key('mock.next')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await t.pump();
    expect(
      t.getBottomRight(find.byKey(const Key('mock.next'))).dy,
      lessThanOrEqualTo(360),
    );
    expect(
      t.widget<ListView>(find.byType(ListView)).keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
    expect(t.takeException(), isNull);
  });
  testWidgets('Edit prepopulates existing results under polished layout', (
    t,
  ) async {
    final c = await mountMock(t, MockHarness());
    c.read(appRouterProvider).go('/mock-exams/mock-1/edit');
    await t.pumpAndSettle();
    expect(
      t.widget<TextFormField>(find.byKey(const Key('mock.name'))).initialValue,
      'Deneme 1',
    );
    await tapVisible(t, find.byKey(const Key('mock.next')));
    expect(
      t
          .widget<TextFormField>(find.byKey(const Key('correct.section-1')))
          .initialValue,
      '42',
    );
    expect(
      t
          .widget<TextFormField>(find.byKey(const Key('wrong.section-1')))
          .initialValue,
      '6',
    );
  });
  testWidgets('Delete requires confirmation then gives one feedback message', (
    t,
  ) async {
    final h = MockHarness();
    final c = await mountMock(t, h);
    c.read(appRouterProvider).go('/mock-exams/mock-1');
    await t.pumpAndSettle();
    await tapVisible(t, find.byKey(const Key('mock.delete')));
    expect(h.deletes, 0);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tapVisible(t, find.byKey(const Key('mock.confirmDelete')));
    expect(h.deletes, 1);
    expect(find.text('Deneme silindi.'), findsOneWidget);
    expect(find.text('Henüz deneme eklemedin.'), findsOneWidget);
  });
  testWidgets('History empty uses shared message and add action', (t) async {
    final h = MockHarness()..rows = [];
    final c = await mountMock(t, h);
    c.read(appRouterProvider).go('/mock-exams');
    await t.pumpAndSettle();
    expect(find.byType(AppMessage), findsOneWidget);
    await tapVisible(t, find.text('İlk Denemeni Ekle'));
    expect(find.text('Yeni Deneme'), findsOneWidget);
  });
  for (final difference in ['11.5', '-2.125', '0']) {
    testWidgets('Target progress remains textual for $difference', (t) async {
      await mountDashboard(
        t,
        FakeDashboard()..payload = populated(difference: difference),
      );
      expect(
        find.text(
          difference == '0'
              ? 'Hedefe ulaştın'
              : difference.startsWith('-')
              ? 'Hedefin üzerinde: 2,13 net'
              : 'Hedefe Kalan: 11,50 net',
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Consistent server error has retry and no raw details', (
    t,
  ) async {
    final f =
        FakeStatistics()
          ..error = DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: RequestOptions(),
              statusCode: 500,
              data: 'private SQL',
            ),
          );
    await mountStats(t, f);
    expect(find.byType(AppMessage), findsOneWidget);
    expect(find.textContaining('private SQL'), findsNothing);
    f.error = null;
    await tapVisible(t, find.text('Tekrar Dene'));
    expect(find.text('Genel Bakış'), findsOneWidget);
  });
  testWidgets(
    'Busy submit preserves label disables action and announces wait',
    (t) async {
      final gate = Completer<ResponseBody>();
      final h = Harness(publicReply: (_) => gate.future);
      await mount(t, h);
      await tapVisible(t, find.text('Giriş Yap'));
      await t.enterText(field('login.email'), 'deniz@example.com');
      await t.enterText(field('login.password'), 'Password1');
      await t.ensureVisible(find.byKey(const Key('login.submit')));
      await t.tap(find.byKey(const Key('login.submit')));
      await t.pump();
      await t.pump();
      expect(
        t
            .widget<FilledButton>(
              find.descendant(
                of: find.byType(AuthSubmit),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.byType(SubmitContent), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete(jsonReply(authPayload()));
      await t.pumpAndSettle();
    },
  );
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    test('Theme ${theme.brightness} important text contrast', () {
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
      }

      final c = theme.colorScheme;
      for (final pair in [
        (c.onSurface, c.surface),
        (c.onPrimary, c.primary),
        (c.onPrimaryContainer, c.primaryContainer),
        (c.error, theme.scaffoldBackgroundColor),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
    });
  }
  testWidgets('System dark theme applies without losing readable content', (
    t,
  ) async {
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    await mount(t, Harness());
    expect(
      Theme.of(t.element(find.text('NetPusula'))).brightness,
      Brightness.dark,
    );
    expect(t.takeException(), isNull);
  });
}
