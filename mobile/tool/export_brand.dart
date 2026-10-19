// Run from mobile: flutter test tool/export_brand.dart
// Exports the same vector used in the home header; no external dependencies.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netpusula/core/widgets/compass_mark.dart';
import 'package:netpusula/core/theme/design_tokens.dart';
import 'package:netpusula/core/constants/app_brand.dart';

void main() {
  test('Export platform icons and brand masters', () async {
    // Flutter's bundled Roboto makes wordmarks reproducible across platforms.
    final flutter = Platform.environment['FLUTTER_ROOT'];
    if (flutter == null) throw StateError('Run with flutter test.');
    final font = File(
      '$flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    );
    final loader = FontLoader('BrandRoboto')
      ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
    await loader.load();
    Future<void> export(
      String path,
      int size, {
      bool dark = true,
      bool transparent = false,
      bool adaptive = false,
      bool wordmark = false,
    }) async {
      final width = wordmark ? size * 4 : size;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      if (!transparent) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, width.toDouble(), size.toDouble()),
          Paint()..color = dark ? BrandColors.navy : BrandColors.background,
        );
      }
      final inset = adaptive ? size * .17 : size * .05;
      canvas.save();
      canvas.translate(inset, inset);
      CompassPainter(onDark: dark).paint(canvas, Size.square(size - inset * 2));
      canvas.restore();
      if (wordmark) {
        void text(
          String text,
          double y,
          double fontSize,
          Color color,
          FontWeight weight,
        ) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                fontFamily: 'BrandRoboto',
                fontSize: fontSize,
                color: color,
                fontWeight: weight,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          painter.paint(canvas, Offset(size.toDouble(), y));
        }

        text(
          AppBrand.name,
          size * .23,
          size * .37,
          dark ? BrandColors.surface : BrandColors.navy,
          FontWeight.w700,
        );
        text(
          AppBrand.slogan,
          size * .65,
          size * .125,
          dark ? BrandColors.darkSecondary : BrandColors.readableSecondary,
          FontWeight.w400,
        );
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, size);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }

    for (final entry
        in {
          'mdpi': 48,
          'hdpi': 72,
          'xhdpi': 96,
          'xxhdpi': 144,
          'xxxhdpi': 192,
        }.entries) {
      await export(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        entry.value,
      );
      await export(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_foreground.png',
        (entry.value * 2.25).round(),
        transparent: true,
        adaptive: true,
      );
    }
    final root = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents =
        jsonDecode(await File('$root/Contents.json').readAsString())
            as Map<String, dynamic>;
    for (final entry in contents['images'] as List) {
      final size = double.parse((entry['size'] as String).split('x').first);
      final scale = double.parse(
        (entry['scale'] as String).replaceAll('x', ''),
      );
      await export('$root/${entry['filename']}', (size * scale).round());
    }
    await export('assets/brand/app-icon.png', 1024);
    for (final dark in [false, true]) {
      await export(
        'assets/brand/compass-${dark ? 'dark' : 'light'}.png',
        512,
        dark: dark,
        transparent: true,
      );
      await export(
        'assets/brand/logo-${dark ? 'dark' : 'light'}.png',
        256,
        dark: dark,
        wordmark: true,
      );
    }
  });
}
