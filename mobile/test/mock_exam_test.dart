import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/app/app.dart';
import 'package:netpusula/core/routing/app_router.dart';
import 'package:netpusula/features/auth/application/auth_controller.dart';
import 'package:netpusula/features/preparation/application/preparation_controller.dart';
import 'package:netpusula/features/mock_exams/application/mock_exam_controller.dart';
import 'package:netpusula/features/mock_exams/domain/mock_exam.dart';
import 'package:netpusula/features/mock_exams/data/mock_exam_repository.dart';
import 'support/auth_fakes.dart';
import 'widget_test.dart' show tapVisible;

Map<String, dynamic> mockPayload({
  String id = 'mock-1',
  String name = 'Deneme 1',
  String net = '81.125',
}) => {
  'id': id,
  'name': name,
  'takenAt': '2026-09-29',
  'notes': 'Notlar',
  'totalNet': net,
  'results': [
    {
      'examSectionId': 'section-1',
      'sectionCode': 'SAY',
      'sectionName': 'Sayısal',
      'groupCode': 'GROUP',
      'groupName': 'Örnek Grup',
      'questionCount': 50,
      'correctCount': 42,
      'wrongCount': 6,
      'blankCount': 2,
      'net': '40.5',
    },
  ],
};

class MockHarness {
  MockHarness() {
    h = Harness(
      publicReply:
          (o) => jsonReply([
            {
              'id': 'section-1',
              'code': 'SAY',
              'name': 'Sayısal',
              'groupCode': 'GROUP',
              'groupName': 'Örnek Grup',
              'questionCount': 50,
            },
          ]),
      protectedReply: (o) async {
        if (o.path == '/api/auth/me') return jsonReply(testUser);
        if (o.path == '/api/user-exams/active') {
          return noPreparation
              ? jsonReply(null, 204)
              : jsonReply(preparationPayload());
        }
        if (o.path == '/api/auth/logout') return jsonReply(null, 204);
        if (o.method == 'DELETE') {
          deletes++;
          if (failDelete) return jsonReply({}, 500);
          rows = [];
          return jsonReply(null, 204);
        }
        if (o.method == 'POST' || o.method == 'PUT') {
          saves++;
          if (!saveStarted.isCompleted) saveStarted.complete();
          body = Map<String, dynamic>.from(o.data as Map);
          await saveGate?.future;
          if (failSave) return jsonReply({}, 500);
          current = mockPayload(name: body!['name'] as String, net: '73.875');
          rows = [current];
          return jsonReply(current, o.method == 'POST' ? 201 : 200);
        }
        if (o.path == '/api/mock-exams') {
          lists++;
          await listGate?.future;
          if (noPreparation) {
            return jsonReply({'code': 'active_preparation_required'}, 409);
          }
          if (failList) return jsonReply({}, 500);
          final page = o.queryParameters['page'] as int;
          return jsonReply({
            'items':
                page == 1
                    ? rows
                    : [mockPayload(id: 'mock-2', name: 'Deneme 2')],
            'page': page,
            'pageSize': 20,
            'totalCount': pages == 1 ? rows.length : 21,
            'totalPages': pages,
          });
        }
        if (missing) return jsonReply({}, 404);
        return jsonReply(current);
      },
    );
    h.storage.value = session();
  }
  late final Harness h;
  Map<String, dynamic> current = mockPayload();
  List<Map<String, dynamic>> rows = [mockPayload()];
  Map<String, dynamic>? body;
  bool failSave = false,
      failList = false,
      failDelete = false,
      missing = false,
      noPreparation = false;
  int saves = 0, deletes = 0, lists = 0, pages = 1;
  final saveStarted = Completer<void>();
  Completer<void>? saveGate, listGate;
}

// Control the repository boundary directly for in-flight lifecycle tests.
class PendingMockRepository extends MockExamRepository {
  PendingMockRepository(this.h) : super(h.h.client, h.h.public);
  final MockHarness h;
  @override
  Future<MockExam> save(MockDraft draft) async {
    h.saves++;
    h.body = draft.json;
    await h.saveGate!.future;
    return MockExam.fromJson(mockPayload(name: draft.name, net: '73.875'));
  }
}

Future<ProviderContainer> mountMock(WidgetTester tester, MockHarness h) async {
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(h.h.repository),
      if (h.saveGate != null)
        mockRepositoryProvider.overrideWithValue(PendingMockRepository(h)),
      localNowProvider.overrideWithValue(() => DateTime(2026, 9, 30)),
    ],
  );
  addTearDown(c.dispose);
  addTearDown(h.h.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const NetPusulaApp()),
  );
  await tester.pumpAndSettle();
  return c;
}

Future<void> newReview(WidgetTester t) async {
  await tapVisible(t, find.text('Deneme Ekle'));
  await t.enterText(find.byKey(const Key('mock.name')), 'Yeni deneme');
  await tapVisible(t, find.byKey(const Key('mock.next')));
  await t.enterText(find.byKey(const Key('correct.section-1')), '42');
  await t.enterText(find.byKey(const Key('wrong.section-1')), '6');
  await tapVisible(t, find.byKey(const Key('mock.next')));
}

void main() {
  test(
    'Exact decimal display rounds only presentation, including negatives',
    () {
      expect(displayNet('78.50'), '78,50');
      expect(displayNet('73.875'), '73,88');
      expect(displayNet('-0.125'), '-0,13');
      expect(displayNet('99999999999999999.995'), '100000000000000000,00');
    },
  );
  test('Blank derivation rejects invalid counts', () {
    final a = MockAnswer(
      const MockSection('s', 'S', 'S', 50),
      correct: '42',
      wrong: '6',
    );
    expect(a.blank, 2);
    a.correct = '51';
    expect(a.blank, isNull);
    a.correct = '-1';
    expect(a.blank, isNull);
    a.correct = '1.5';
    expect(a.blank, isNull);
  });
  for (final pair in [
    (400, MockIssue.validation),
    (401, MockIssue.session),
    (404, MockIssue.missing),
    (409, MockIssue.conflict),
    (429, MockIssue.rateLimited),
    (500, MockIssue.server),
  ]) {
    test('Safe HTTP error ${pair.$1}', () {
      final o = RequestOptions();
      expect(
        mockIssue(
          DioException(
            requestOptions: o,
            response: Response(requestOptions: o, statusCode: pair.$1),
          ),
        ),
        pair.$2,
      );
    });
  }
  test('Timeout and offline do not mean no preparation', () {
    for (final type in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      expect(
        mockIssue(DioException(requestOptions: RequestOptions(), type: type)),
        MockIssue.network,
      );
    }
  });
  testWidgets('Home has add and history, logout still works', (t) async {
    final h = MockHarness();
    await mountMock(t, h);
    expect(find.text('Deneme Ekle'), findsOneWidget);
    expect(find.text('Deneme Geçmişi'), findsOneWidget);
    await tapVisible(t, find.text('Çıkış Yap'));
    expect(find.text('Merhaba, Deniz'), findsNothing);
  });
  testWidgets(
    'API sections group and derived blank render; draft survives back',
    (t) async {
      final h = MockHarness();
      await mountMock(t, h);
      await newReview(t);
      expect(find.text('Kontrol'), findsOneWidget);
      expect(find.text('Doğru: 42 · Yanlış: 6 · Boş: 2'), findsOneWidget);
      await tapVisible(t, find.byKey(const Key('mock.back')));
      expect(find.text('Örnek Grup'), findsOneWidget);
      expect(find.text('Boş: 2'), findsOneWidget);
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('correct.section-1')))
            .initialValue,
        '42',
      );
      await tapVisible(t, find.byKey(const Key('mock.back')));
      expect(find.text('Yeni deneme'), findsOneWidget);
      expect(h.h.publicPaths, contains('/api/exams/exam-id/sections'));
    },
  );
  testWidgets('Invalid correct wrong prevents review', (t) async {
    final h = MockHarness();
    await mountMock(t, h);
    await newReview(t);
    await tapVisible(t, find.byKey(const Key('mock.back')));
    await t.enterText(find.byKey(const Key('wrong.section-1')), '51');
    await tapVisible(t, find.byKey(const Key('mock.next')));
    expect(find.text('Kontrol'), findsNothing);
    expect(find.text('Boş: —'), findsOneWidget);
    expect(h.saves, 0);
  });
  testWidgets('Date picker ends today', (t) async {
    final h = MockHarness();
    await mountMock(t, h);
    await tapVisible(t, find.text('Deneme Ekle'));
    await tapVisible(t, find.byKey(const Key('mock.date')));
    expect(
      t.widget<DatePickerDialog>(find.byType(DatePickerDialog)).lastDate,
      DateTime(2026, 9, 30),
    );
  });
  testWidgets('Save uses server total and excludes ownership/net inputs', (
    t,
  ) async {
    final h = MockHarness();
    await mountMock(t, h);
    await newReview(t);
    await tapVisible(t, find.byKey(const Key('mock.next')));
    expect(find.text('73,88 net'), findsOneWidget);
    expect(
      h.body!.keys,
      unorderedEquals(['name', 'takenAt', 'notes', 'results']),
    );
    expect((h.body!['results'] as List).first['blankCount'], 2);
    expect(h.saves, 1);
  });
  testWidgets('Duplicate save disabled while pending', (t) async {
    final h = MockHarness()..saveGate = Completer<void>();
    await mountMock(t, h);
    await newReview(t);
    final button = find.byKey(const Key('mock.next'));
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pump();
    expect(t.widget<FilledButton>(button).onPressed, isNull);
    expect(h.saves, 1);
    h.saveGate!.complete();
    await t.pumpAndSettle();
    expect(find.text('73,88 net'), findsOneWidget);
  });
  testWidgets('Failed save preserves draft and retries', (t) async {
    final h = MockHarness()..failSave = true;
    await mountMock(t, h);
    await newReview(t);
    await tapVisible(t, find.byKey(const Key('mock.next')));
    expect(find.text('Yeni deneme'), findsOneWidget);
    expect(find.text('Doğru: 42 · Yanlış: 6 · Boş: 2'), findsOneWidget);
    h.failSave = false;
    await tapVisible(t, find.byKey(const Key('mock.next')));
    expect(h.saves, 2);
    expect(find.text('73,88 net'), findsOneWidget);
  });
  testWidgets('History empty CTA', (t) async {
    final h = MockHarness()..rows = [];
    await mountMock(t, h);
    await tapVisible(t, find.text('Deneme Geçmişi'));
    expect(find.text('Henüz deneme eklemedin.'), findsOneWidget);
    expect(find.text('İlk Denemeni Ekle'), findsOneWidget);
  });
  testWidgets('History loading then cards and load more', (t) async {
    final h =
        MockHarness()
          ..pages = 2
          ..listGate = Completer<void>();
    final c = await mountMock(t, h);
    c.read(appRouterProvider).push('/mock-exams');
    await t.pump();
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    h.listGate!.complete();
    await t.pumpAndSettle();
    expect(find.text('81,13 net'), findsOneWidget);
    await tapVisible(t, find.text('Daha fazla yükle'));
    expect(find.text('Deneme 2'), findsOneWidget);
    expect(h.lists, 2);
  });
  testWidgets('History error retry remains protected', (t) async {
    final h = MockHarness()..failList = true;
    final c = await mountMock(t, h);
    await tapVisible(t, find.text('Deneme Geçmişi'));
    expect(
      c.read(preparationControllerProvider).status,
      PreparationStatus.ready,
    );
    h.failList = false;
    await tapVisible(t, find.text('Tekrar Dene'));
    expect(find.text('Deneme 1'), findsOneWidget);
  });
  testWidgets('Detail renders backend values', (t) async {
    final h = MockHarness();
    final c = await mountMock(t, h);
    c.read(appRouterProvider).push('/mock-exams/mock-1');
    await t.pumpAndSettle();
    expect(find.text('81,13 net'), findsOneWidget);
    expect(find.text('40,50 net'), findsOneWidget);
    expect(find.text('Notlar'), findsOneWidget);
  });
  testWidgets('Edit prepopulates and refreshes history and detail', (t) async {
    final h = MockHarness();
    final c = await mountMock(t, h);
    c.read(appRouterProvider).push('/mock-exams/mock-1');
    await t.pumpAndSettle();
    await tapVisible(t, find.text('Düzenle'));
    expect(find.text('Deneme 1'), findsOneWidget);
    await t.enterText(find.byKey(const Key('mock.name')), 'Güncel');
    await tapVisible(t, find.byKey(const Key('mock.next')));
    expect(
      t
          .widget<TextFormField>(find.byKey(const Key('correct.section-1')))
          .initialValue,
      '42',
    );
    await tapVisible(t, find.byKey(const Key('mock.next')));
    await tapVisible(t, find.byKey(const Key('mock.next')));
    expect(find.text('73,88 net'), findsOneWidget);
    await tapVisible(t, find.text('Deneme Geçmişine Git'));
    expect(find.text('Güncel'), findsOneWidget);
  });
  testWidgets('Delete cancel is safe and confirmation removes history', (
    t,
  ) async {
    final h = MockHarness();
    final c = await mountMock(t, h);
    c.read(appRouterProvider).push('/mock-exams/mock-1');
    await t.pumpAndSettle();
    await tapVisible(t, find.byKey(const Key('mock.delete')));
    expect(h.deletes, 0);
    await tapVisible(t, find.text('Vazgeç'));
    expect(h.deletes, 0);
    await tapVisible(t, find.byKey(const Key('mock.delete')));
    await tapVisible(t, find.byKey(const Key('mock.confirmDelete')));
    expect(h.deletes, 1);
    expect(find.text('Henüz deneme eklemedin.'), findsOneWidget);
  });
  testWidgets('Failed delete stays on detail', (t) async {
    final h = MockHarness()..failDelete = true;
    final c = await mountMock(t, h);
    c.read(appRouterProvider).push('/mock-exams/mock-1');
    await t.pumpAndSettle();
    await tapVisible(t, find.byKey(const Key('mock.delete')));
    await tapVisible(t, find.byKey(const Key('mock.confirmDelete')));
    expect(find.text('81,13 net'), findsOneWidget);
    expect(h.rows.length, 1);
  });
  testWidgets('Foreign or missing detail shows safe not found', (t) async {
    final h = MockHarness()..missing = true;
    final c = await mountMock(t, h);
    c.read(appRouterProvider).push('/mock-exams/foreign');
    await t.pumpAndSettle();
    expect(find.text('Deneme bulunamadı.'), findsOneWidget);
    expect(find.byKey(const Key('mock.delete')), findsNothing);
  });
  testWidgets('Explicit missing preparation offers recheck then onboarding', (
    t,
  ) async {
    final h = MockHarness();
    await mountMock(t, h);
    h.noPreparation = true;
    await tapVisible(t, find.text('Deneme Geçmişi'));
    expect(find.text('Hazırlığı Kontrol Et'), findsOneWidget);
    await tapVisible(t, find.text('Hazırlığı Kontrol Et'));
    expect(find.text('Deneme Geçmişi'), findsNothing);
  });

  testWidgets(
    'Logout clears pending mock mutation and cannot publish late save',
    (t) async {
      final h = MockHarness()..saveGate = Completer<void>();
      final c = await mountMock(t, h);
      await newReview(t);
      final button = find.byKey(const Key('mock.next'));
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pump();
      expect(h.saves, 1);
      final logout = c.read(authControllerProvider.notifier).logout();
      await t.pumpAndSettle();
      await logout;
      h.saveGate!.complete();
      await t.pumpAndSettle();
      expect(find.text('73,88 net'), findsNothing);
      expect(c.read(mockMutationProvider).busy, isFalse);
    },
  );
  testWidgets('Mock form scrolls on small screen with large text', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final h = MockHarness();
    await mountMock(t, h);
    await newReview(t);
    expect(find.text('Kontrol'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
