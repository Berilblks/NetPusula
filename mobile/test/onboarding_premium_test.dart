import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/core/widgets/compass_mark.dart';
import 'preparation_widget_test.dart' show PreparationHarness, mountPreparation;
import 'widget_test.dart' show tapVisible;

void main() {
  for (final dark in [false, true]) {
    for (final large in [false, true]) {
      testWidgets('Five premium onboarding steps dark=$dark large=$large', (
        t,
      ) async {
        t.view.physicalSize = Size(large ? 320 : 390, large ? 640 : 844);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.platformBrightnessTestValue =
            dark ? Brightness.dark : Brightness.light;
        t.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearAllTestValues);
        const preview = bool.fromEnvironment('PREMIUM_AUTH_PREVIEW');
        if (preview) {
          await t.runAsync(() async {
            final root = Platform.environment['FLUTTER_ROOT'];
            for (final font
                in {
                  'Roboto': 'Roboto-Regular.ttf',
                  'MaterialIcons': 'MaterialIcons-Regular.otf',
                }.entries) {
              await (FontLoader(font.key)..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File(
                      '$root/bin/cache/artifacts/material_fonts/${font.value}',
                    ).readAsBytes(),
                  ),
                ),
              )).load();
            }
          });
        }
        final key = GlobalKey();
        final p = PreparationHarness();
        await mountPreparation(
          t,
          p,
          wrap: (child) => RepaintBoundary(key: key, child: child),
        );
        for (var step = 0; step < 5; step++) {
          expect(find.byType(CompassMark), findsOneWidget);
          expect(t.takeException(), isNull);
          if (preview && !large) {
            await t.runAsync(() async {
              final image =
                  await (key.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/auth-preview/onboarding-$step-${dark ? "dark" : "light"}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          if (step == 4) break;
          if (step == 1) {
            await tapVisible(t, find.byKey(const Key('exam.exam-id')));
          }
          if (step == 2) {
            if (large) t.view.viewInsets = const FakeViewPadding(bottom: 240);
            await t.enterText(find.byKey(const Key('goal.target')), '80,25');
            await t
                .pumpAndSettle(); // Complete keyboard resize before scrolling to the action.
          }
          if (step == 3) {
            t.view.resetViewInsets();
            await t.pumpAndSettle();
            await tapVisible(t, find.byKey(const Key('goal.date')));
            final label =
                MaterialLocalizations.of(
                  t.element(find.byType(DatePickerDialog)),
                ).okButtonLabel;
            await tapVisible(t, find.text(label));
          }
          await tapVisible(t, find.byKey(const Key('goal.next')));
        }
        expect(p.saves, 0);
        expect(find.byKey(const Key('goal.save')), findsOneWidget);
        await tapVisible(t, find.byKey(const Key('goal.back')));
        expect(find.byKey(const Key('goal.date')), findsOneWidget);
      });
    }
  }
}
