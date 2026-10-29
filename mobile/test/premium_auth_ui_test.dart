import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/core/routing/app_router.dart';
import 'package:netpusula/core/widgets/compass_mark.dart';
import 'package:netpusula/l10n/app_localizations.dart';
import 'google_auth_test.dart' show mountGoogle, FakeGoogle;
import 'support/auth_fakes.dart';
import 'widget_test.dart' show tapVisible;

void main() {
  for (final route in ['/login', '/register']) {
    for (final dark in [false, true]) {
      for (final large in [false, true]) {
        testWidgets('$route premium dark=$dark large=$large keyboard-safe', (
          t,
        ) async {
          t.view.physicalSize = Size(large ? 320 : 390, large ? 640 : 844);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.platformBrightnessTestValue =
              dark ? Brightness.dark : Brightness.light;
          t.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
          if (large) t.view.viewInsets = FakeViewPadding(bottom: 250);
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(t.view.resetViewInsets);
          const preview = bool.fromEnvironment('PREMIUM_AUTH_PREVIEW');
          if (preview) {
            await t.runAsync(() async {
              final root = Platform.environment['FLUTTER_ROOT'];
              for (final entry
                  in {
                    'Roboto': 'Roboto-Regular.ttf',
                    'MaterialIcons': 'MaterialIcons-Regular.otf',
                  }.entries) {
                final loader = FontLoader(entry.key)..addFont(
                  Future.value(
                    ByteData.sublistView(
                      await File(
                        '$root/bin/cache/artifacts/material_fonts/${entry.value}',
                      ).readAsBytes(),
                    ),
                  ),
                );
                await loader.load();
              }
            });
          }
          final key = GlobalKey();
          final c = await mountGoogle(
            t,
            Harness(),
            FakeGoogle()..token = null,
            route: route,
            wrap: (child) => RepaintBoundary(key: key, child: child),
          );
          expect(t.takeException(), isNull);
          final l =
              AppLocalizations.of(t.element(find.byType(Scaffold).first))!;
          expect(find.text('Sınav yolculuğunda yanında.'), findsOneWidget);
          expect(find.text(l.loginSubtitle), findsNothing);
          expect(find.text(l.registerSubtitle), findsNothing);
          expect(t.widget<CompassMark>(find.byType(CompassMark)).size, 68);
          if (preview && !large) {
            await t.runAsync(
              () => precacheImage(
                const AssetImage('assets/auth/google-g.png'),
                t.element(find.byType(Scaffold).first),
              ),
            );
            await t.pumpAndSettle();
            await t.runAsync(() async {
              final image =
                  await (key.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/auth-preview/${route.substring(1)}-${dark ? 'dark' : 'light'}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tapVisible(t, find.byKey(const Key('auth.google')));
          expect(t.takeException(), isNull);
          final link =
              route == '/login'
                  ? 'Hesabın yok mu? Hesap Oluştur'
                  : 'Zaten hesabın var mı? Giriş yap';
          await tapVisible(t, find.text(link));
          expect(
            c.read(appRouterProvider).routeInformationProvider.value.uri.path,
            route == '/login' ? '/register' : '/login',
          );
          expect(t.takeException(), isNull);
        });
      }
    }
  }
}
