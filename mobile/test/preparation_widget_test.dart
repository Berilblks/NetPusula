import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/app/app.dart';
import 'package:netpusula/core/routing/app_router.dart';
import 'package:netpusula/features/auth/application/auth_controller.dart';
import 'package:netpusula/features/preparation/application/preparation_controller.dart';
import 'support/auth_fakes.dart';
import 'widget_test.dart' show tapVisible;

class PreparationHarness {
  PreparationHarness({this.hasActive = false}) {
    h = Harness(
      publicReply: (o) {
        if (o.path == '/api/exams') {
          catalogueCalls++;
          return jsonReply(
            emptyCatalogue ? [] : [preparationPayload()['exam']],
          );
        }
        return jsonReply(authPayload());
      },
      protectedReply: (o) async {
        if (o.path == '/api/auth/me') return jsonReply(testUser);
        if (o.path == '/api/user-exams/active') {
          await lookupGate?.future;
          if (offline) {
            throw DioException(
              requestOptions: o,
              type: DioExceptionType.connectionError,
            );
          }
          return hasActive
              ? jsonReply(preparationPayload(target: target, date: date))
              : jsonReply(null, 204);
        }
        saves++;
        await saveGate?.future;
        if (failSave) return jsonReply({'detail': 'do not show'}, 500);
        hasActive = true;
        target = o.data['targetNet'] as num;
        date = o.data['examDate'] as String;
        return jsonReply(
          preparationPayload(target: target, date: date),
          o.method == 'POST' ? 201 : 200,
        );
      },
    );
    h.storage.value = session();
  }
  late final Harness h;
  bool hasActive, offline = false, failSave = false, emptyCatalogue = false;
  int catalogueCalls = 0, saves = 0;
  num target = 80;
  String date = '2026-10-01';
  Completer<void>? lookupGate, saveGate;
}

Future<ProviderContainer> mountPreparation(
  WidgetTester tester,
  PreparationHarness p, {
  bool settle = true,
}) async {
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(p.h.repository),
      localNowProvider.overrideWithValue(() => DateTime(2026, 9, 30, 23, 59)),
    ],
  );
  addTearDown(c.dispose);
  addTearDown(p.h.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const NetPusulaApp()),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return c;
}

Future<void> toTarget(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const Key('goal.next')));
  expect(
    tester.widget<FilledButton>(find.byKey(const Key('goal.next'))).onPressed,
    isNull,
  );
  await tapVisible(tester, find.byKey(const Key('exam.exam-id')));
  await tapVisible(tester, find.byKey(const Key('goal.next')));
}

Future<void> toReview(WidgetTester tester) async {
  await toTarget(tester);
  await tester.enterText(find.byKey(const Key('goal.target')), '80,25');
  await tapVisible(tester, find.byKey(const Key('goal.next')));
  await tapVisible(tester, find.byKey(const Key('goal.date')));
  final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
  expect(picker.firstDate, DateTime(2026, 9, 30));
  final confirmLabel =
      MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      ).okButtonLabel;
  await tapVisible(tester, find.text(confirmLabel));
  await tapVisible(tester, find.byKey(const Key('goal.next')));
}

void main() {
  testWidgets('No active preparation enters onboarding and cannot bypass it', (
    tester,
  ) async {
    final c = await mountPreparation(tester, PreparationHarness());
    expect(find.text('Şimdi hedefini birlikte belirleyelim.'), findsOneWidget);
    for (final path in ['/home', '/goal/edit']) {
      c.read(appRouterProvider).go(path);
      await tester.pumpAndSettle();
      expect(
        c.read(appRouterProvider).routeInformationProvider.value.uri.path,
        '/onboarding',
      );
    }
  });
  testWidgets(
    'Returning user skips onboarding and sees actual target and date-derived days',
    (tester) async {
      await mountPreparation(tester, PreparationHarness(hasActive: true));
      expect(find.text('Merhaba, Deniz'), findsOneWidget);
      expect(find.text('ALES'), findsOneWidget);
      expect(find.text('80 net'), findsOneWidget);
      expect(find.text('1 gün kaldı'), findsOneWidget);
      expect(find.text('1 Ekim 2026'), findsOneWidget);
    },
  );
  testWidgets('Today and elapsed date never show negative countdown', (
    tester,
  ) async {
    final p = PreparationHarness(hasActive: true)..date = '2026-09-30';
    final c = await mountPreparation(tester, p);
    expect(find.text('Bugün'), findsOneWidget);
    p.date = '2026-09-29';
    c.read(preparationControllerProvider.notifier).load();
    await tester.pumpAndSettle();
    expect(find.text('Sınav tarihi geçti'), findsOneWidget);
  });
  testWidgets('Loading preparation cannot flash home or onboarding', (
    tester,
  ) async {
    final p = PreparationHarness()..lookupGate = Completer<void>();
    await mountPreparation(tester, p, settle: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Merhaba, Deniz'), findsNothing);
    expect(find.text('Şimdi hedefini birlikte belirleyelim.'), findsNothing);
    p.lookupGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Şimdi hedefini birlikte belirleyelim.'), findsOneWidget);
  });
  testWidgets(
    'Offline lookup stays in protected retry state rather than onboarding',
    (tester) async {
      final p = PreparationHarness(hasActive: true)..offline = true;
      await mountPreparation(tester, p);
      expect(find.text('Şimdi hedefini birlikte belirleyelim.'), findsNothing);
      expect(find.text('Tekrar Dene'), findsOneWidget);
      p.offline = false;
      await tapVisible(tester, find.text('Tekrar Dene'));
      expect(find.text('Merhaba, Deniz'), findsOneWidget);
    },
  );
  testWidgets('Exam cards come from API and require selection', (tester) async {
    final p = PreparationHarness();
    await mountPreparation(tester, p);
    await toTarget(tester);
    expect(p.catalogueCalls, 1);
    expect(find.text('Hedef netin kaç?'), findsOneWidget);
  });
  testWidgets('Empty catalogue supports retry without a fabricated exam list', (
    tester,
  ) async {
    final p = PreparationHarness()..emptyCatalogue = true;
    await mountPreparation(tester, p);
    await tapVisible(tester, find.byKey(const Key('goal.next')));
    expect(find.byType(RadioListTile<String>), findsNothing);
    p.emptyCatalogue = false;
    await tapVisible(tester, find.text('Tekrar Dene'));
    expect(find.text('Test ALES'), findsOneWidget);
  });
  testWidgets('Target validates positive values and known maximum', (
    tester,
  ) async {
    await mountPreparation(tester, PreparationHarness());
    await toTarget(tester);
    await tester.enterText(find.byKey(const Key('goal.target')), '0');
    await tapVisible(tester, find.byKey(const Key('goal.next')));
    expect(find.textContaining('Sıfırdan büyük'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('goal.target')), '101');
    await tapVisible(tester, find.byKey(const Key('goal.next')));
    expect(find.text('Hedef netin kaç?'), findsOneWidget);
    expect(find.text('Bu yapılandırmada en fazla 100 net.'), findsWidgets);
  });
  testWidgets(
    'Review uses Turkish decimals and date; successful create reaches home',
    (tester) async {
      final p = PreparationHarness();
      await mountPreparation(tester, p);
      await toReview(tester);
      expect(find.text('80,25 net'), findsOneWidget);
      expect(find.text('30 Eylül 2026'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('goal.save')));
      expect(find.text('Merhaba, Deniz'), findsOneWidget);
      expect(find.text('80,25 net'), findsOneWidget);
      expect(find.text('Bugün'), findsOneWidget);
      expect(p.saves, 1);
    },
  );
  testWidgets('Failed save retains draft and retry succeeds', (tester) async {
    final p = PreparationHarness()..failSave = true;
    await mountPreparation(tester, p);
    await toReview(tester);
    await tapVisible(tester, find.byKey(const Key('goal.save')));
    expect(find.text('80,25 net'), findsOneWidget);
    expect(find.text('30 Eylül 2026'), findsOneWidget);
    expect(
      find.text('Bilgiler kaydedilemedi. Lütfen tekrar dene.'),
      findsOneWidget,
    );
    p.failSave = false;
    await tapVisible(tester, find.byKey(const Key('goal.save')));
    expect(find.text('Merhaba, Deniz'), findsOneWidget);
    expect(p.saves, 2);
  });
  testWidgets('Saving disables submit and back until completed', (
    tester,
  ) async {
    final p = PreparationHarness()..saveGate = Completer<void>();
    await mountPreparation(tester, p);
    await toReview(tester);
    await tester.ensureVisible(find.byKey(const Key('goal.save')));
    await tester.tap(find.byKey(const Key('goal.save')));
    await tester.pump();
    final button = find.descendant(
      of: find.byKey(const Key('goal.save')),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(
      tester.widget<TextButton>(find.byKey(const Key('goal.back'))).onPressed,
      isNull,
    );
    p.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(p.saves, 1);
  });
  testWidgets('Edit changes only goal/date and returns home', (tester) async {
    final p = PreparationHarness(hasActive: true);
    await mountPreparation(tester, p);
    await tapVisible(tester, find.text('Hedefi Düzenle'));
    expect(find.byType(RadioListTile<String>), findsNothing);
    await tester.enterText(find.byKey(const Key('goal.target')), '85,5');
    await tapVisible(tester, find.byKey(const Key('goal.save')));
    expect(find.text('85,5 net'), findsOneWidget);
    expect(p.saves, 1);
  });
  testWidgets('Logout is available during onboarding', (tester) async {
    final c = await mountPreparation(tester, PreparationHarness());
    await tapVisible(tester, find.text('Çıkış Yap'));
    expect(find.text('Giriş Yap'), findsOneWidget);
    expect(c.read(preparationControllerProvider).active, isNull);
  });
  testWidgets(
    'Onboarding scrolls on small screens with keyboard and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mountPreparation(tester, PreparationHarness());
      await toTarget(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('goal.target')));
      expect(tester.takeException(), isNull);
    },
  );
}
