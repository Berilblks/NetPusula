import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/core/theme/app_theme.dart';
import 'package:netpusula/core/theme/design_tokens.dart';
import 'package:netpusula/features/dashboard/domain/dashboard.dart';
import 'package:netpusula/features/dashboard/presentation/premium_widgets.dart';
import 'dashboard_test.dart' show FakeDashboard, mountDashboard;

void main() {
  testWidgets('Brand uses requested palette and retains two theme modes', (
    t,
  ) async {
    expect(AppTheme.light.colorScheme.primary, BrandColors.purple);
    expect(AppTheme.light.scaffoldBackgroundColor, BrandColors.background);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });
  for (final entry
      in <String?, double>{null: 0, '-12.5': 0, '35': .5, '85': 1}.entries) {
    testWidgets('Target ring bounds ${entry.key}; exact score remains visible', (
      t,
    ) async {
      final fake = FakeDashboard();
      await mountDashboard(t, fake);
      final context = t.element(find.byType(TargetRing));
      final widget = TargetRing(
        latest: entry.key == null ? null : Score(entry.key!),
        target: Score('70'),
      );
      final built = widget.build(context);
      // Inspect painter through normal widget layout, with the app's localization.
      await t.pumpWidget(MaterialApp(home: Scaffold(body: built)));
      final painters =
          t
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .map((p) => p.painter)
              .whereType<TargetRingPainter>();
      expect(painters.single.progress, entry.value);
      if (entry.key != null) {
        expect(find.text(Score(entry.key!).display), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    });
  }
  for (final mode in [Brightness.light, Brightness.dark]) {
    testWidgets('Premium home ${mode.name}: navigation and responsive preview', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.platformBrightnessTestValue = mode;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
      const preview = bool.fromEnvironment('PREMIUM_PREVIEW');
      if (preview) {
        await t.runAsync(() async {
          final root = Platform.environment['FLUTTER_ROOT'];
          final bytes =
              await File(
                '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
              ).readAsBytes();
          final loader = FontLoader('Roboto')
            ..addFont(Future.value(ByteData.sublistView(bytes)));
          await loader.load();
          final icons = FontLoader('MaterialIcons')..addFont(
            Future.value(
              ByteData.sublistView(
                await File(
                  '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytes(),
              ),
            ),
          );
          await icons.load();
        });
      }
      final boundary = GlobalKey();
      await mountDashboard(
        t,
        FakeDashboard(),
        wrap: (child) => RepaintBoundary(key: boundary, child: child),
      );
      expect(find.text('Profil'), findsNothing);
      expect(find.byType(HomeNavigation), findsOneWidget);
      expect(
        find.text('Bugün de hedeflerine bir adım daha yaklaş!'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      if (preview) {
        await t.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/premium-preview/home-${mode.name}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await t.ensureVisible(find.text('Son Denemeler'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ana Sayfa'));
      await t.pumpAndSettle();
      expect(t.getTopLeft(find.text('Merhaba, Deniz')).dy, lessThan(250));
      await t.tap(find.text('Denemeler'));
      await t.pumpAndSettle();
      expect(find.byType(HomeNavigation), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
}
