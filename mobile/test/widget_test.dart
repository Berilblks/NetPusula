import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/app/app.dart';
import 'package:netpusula/core/routing/app_router.dart';
import 'package:netpusula/features/auth/application/auth_controller.dart';
import 'support/auth_fakes.dart';

Future<ProviderContainer> mount(WidgetTester tester, Harness h) async {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(h.repository)],
  );
  addTearDown(container.dispose);
  addTearDown(h.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const NetPusulaApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder field(String key) =>
    find
            .descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(TextFormField),
            )
            .evaluate()
            .isEmpty
        ? find.byKey(Key(key))
        : find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(TextFormField),
        );
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Unauthenticated startup reaches Turkish welcome', (
    tester,
  ) async {
    await mount(tester, Harness());
    expect(find.text('NetPusula'), findsOneWidget);
    expect(find.text('Hedefine giden yolu netlerinle keşfet.'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });
  testWidgets('Welcome fits small screen and large text', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mount(tester, Harness());
    expect(tester.takeException(), isNull);
  });
  testWidgets('Login required and email validation prevents HTTP', (
    tester,
  ) async {
    final h = Harness();
    await mount(tester, h);
    await tapVisible(tester, find.text('Giriş Yap'));
    await tapVisible(tester, find.byKey(const Key('login.submit')));
    expect(find.text('Bu alanı doldur.'), findsWidgets);
    await tester.enterText(field('login.email'), 'invalid');
    await tapVisible(tester, find.byKey(const Key('login.submit')));
    expect(find.text('Geçerli bir e-posta adresi gir.'), findsOneWidget);
    expect(h.publicPaths, isEmpty);
  });
  testWidgets('Register validates name email and backend password policy', (
    tester,
  ) async {
    final h = Harness();
    await mount(tester, h);
    await tapVisible(tester, find.text('Hesap Oluştur'));
    await tapVisible(tester, find.byKey(const Key('register.submit')));
    expect(find.text('Adın 2–120 karakter olmalı.'), findsOneWidget);
    expect(find.text('Geçerli bir e-posta adresi gir.'), findsOneWidget);
    expect(find.textContaining('Şifren 8–128'), findsOneWidget);
    expect(h.publicPaths, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Register confirmation mismatch prevents HTTP', (tester) async {
    final h = Harness();
    await mount(tester, h);
    await tapVisible(tester, find.text('Hesap Oluştur'));
    await tester.enterText(field('register.name'), 'Deniz');
    await tester.enterText(field('register.email'), 'deniz@example.com');
    await tester.enterText(field('register.password'), 'Password1');
    await tester.enterText(field('register.confirmation'), 'Different1');
    await tapVisible(tester, find.byKey(const Key('register.submit')));
    expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
    expect(h.publicPaths, isEmpty);
  });
  for (final register in [false, true]) {
    testWidgets(
      '${register ? "Register" : "Login"} authenticates directly and logout clears home and session',
      (tester) async {
        final h = Harness();
        final c = await mount(tester, h);
        await tapVisible(
          tester,
          find.text(register ? 'Hesap Oluştur' : 'Giriş Yap'),
        );
        final prefix = register ? 'register' : 'login';
        if (register) await tester.enterText(field('$prefix.name'), 'Deniz');
        await tester.enterText(field('$prefix.email'), 'deniz@example.com');
        await tester.enterText(field('$prefix.password'), 'Password1');
        if (register) {
          await tester.enterText(field('$prefix.confirmation'), 'Password1');
        }
        await tapVisible(tester, find.byKey(Key('$prefix.submit')));
        expect(find.text('Merhaba, Deniz'), findsOneWidget);
        expect(c.read(authControllerProvider).status, AuthStatus.authenticated);
        expect(h.storage.value, isNotNull);
        await tapVisible(tester, find.text('Çıkış Yap'));
        expect(find.text('Merhaba, Deniz'), findsNothing);
        expect(h.storage.value, isNull);
        expect(c.read(authControllerProvider).user, isNull);
      },
    );
  }
  testWidgets('Existing secure session restores into home', (tester) async {
    final h = Harness();
    h.storage.value = session();
    await mount(tester, h);
    expect(find.text('Merhaba, Deniz'), findsOneWidget);
    expect(h.protectedCalls, 1);
  });
  testWidgets('Splash protects content while secure storage is pending', (
    tester,
  ) async {
    final h = Harness();
    h.storage.value = session();
    h.storage.readGate = Completer<void>();
    final c = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(h.repository)],
    );
    addTearDown(c.dispose);
    addTearDown(h.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const NetPusulaApp()),
    );
    await tester.pump();
    c.read(appRouterProvider).go('/home');
    await tester.pump();
    expect(find.text('Merhaba, Deniz'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    h.storage.readGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Merhaba, Deniz'), findsOneWidget);
  });
  testWidgets('Anonymous home deep link redirects to welcome', (tester) async {
    final c = await mount(tester, Harness());
    c.read(appRouterProvider).go('/home');
    await tester.pumpAndSettle();
    expect(
      c.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/welcome',
    );
    expect(find.text('Çıkış Yap'), findsNothing);
  });
  testWidgets('Authenticated login and register deep links redirect home', (
    tester,
  ) async {
    final h = Harness();
    h.storage.value = session();
    final c = await mount(tester, h);
    for (final path in ['/login', '/register', '/welcome']) {
      c.read(appRouterProvider).go(path);
      await tester.pumpAndSettle();
      expect(
        c.read(appRouterProvider).routeInformationProvider.value.uri.path,
        '/home',
      );
    }
  });
  testWidgets('Password visibility can toggle without changing value', (
    tester,
  ) async {
    await mount(tester, Harness());
    await tapVisible(tester, find.text('Giriş Yap'));
    await tester.enterText(field('login.password'), 'Password1');
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: field('login.password'),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isTrue,
    );
    await tapVisible(tester, find.byTooltip('Şifreyi göster'));
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: field('login.password'),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isFalse,
    );
  });
  testWidgets('Keyboard next moves from email to password once', (
    tester,
  ) async {
    await mount(tester, Harness());
    await tapVisible(tester, find.text('Giriş Yap'));
    await tester.enterText(field('login.email'), 'deniz@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    final password = tester.widget<EditableText>(
      find.descendant(
        of: field('login.password'),
        matching: find.byType(EditableText),
      ),
    );
    expect(password.focusNode.hasFocus, isTrue);
  });
  testWidgets('Login failure displays safe localized message', (tester) async {
    final h = Harness(
      publicReply: (_) => jsonReply({'detail': 'secret raw stacktrace'}, 401),
    );
    await mount(tester, h);
    await tapVisible(tester, find.text('Giriş Yap'));
    await tester.enterText(field('login.email'), 'deniz@example.com');
    await tester.enterText(field('login.password'), 'Password1');
    await tapVisible(tester, find.byKey(const Key('login.submit')));
    expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
    expect(find.textContaining('secret raw'), findsNothing);
  });
  testWidgets(
    'Storage failure remains on recovery splash without protected content',
    (tester) async {
      final h = Harness();
      h.storage.failRead = true;
      await mount(tester, h);
      expect(find.text('Tekrar Dene'), findsOneWidget);
      expect(find.text('Çıkış Yap'), findsNothing);
      h.storage.failRead = false;
      await tapVisible(tester, find.text('Tekrar Dene'));
      expect(find.text('Giriş Yap'), findsOneWidget);
    },
  );
  testWidgets(
    'Register scrolls with keyboard and large text without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(tester, Harness());
      await tapVisible(tester, find.text('Hesap Oluştur'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(field('register.confirmation'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
