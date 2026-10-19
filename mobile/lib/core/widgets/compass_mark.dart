import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Vector adaptation of the selected compass reference; also used to export
/// platform icons. No raster screenshot or third-party icon font is required.
class CompassMark extends StatelessWidget {
  const CompassMark({this.size = 40, this.onDark = false, super.key});
  final double size;
  final bool onDark;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: CompassPainter(onDark: onDark),
    ),
  );
}

class CompassPainter extends CustomPainter {
  const CompassPainter({this.onDark = false});
  final bool onDark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    const circle = Rect.fromLTWH(16, 16, 68, 68);
    final ring =
        Paint()
          ..shader = BrandColors.compass.createShader(circle)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(circle, -.43 * math.pi, .94 * math.pi, false, ring);
    canvas.drawArc(circle, .59 * math.pi, .94 * math.pi, false, ring);
    Path polygon(List<Offset> points) => Path()..addPolygon(points, true);
    final needle = polygon(const [
      Offset(59, 8),
      Offset(58, 43),
      Offset(75, 50),
      Offset(54, 58),
      Offset(41, 92),
      Offset(42, 57),
      Offset(25, 50),
      Offset(46, 42),
    ]);
    canvas.drawPath(
      needle,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors:
              onDark
                  ? [BrandColors.coral, BrandColors.pink, BrandColors.purple]
                  : [BrandColors.purple, BrandColors.navy],
        ).createShader(const Rect.fromLTWH(25, 8, 50, 84)),
    );
    canvas.drawPath(
      polygon(const [
        Offset(59, 8),
        Offset(50, 50),
        Offset(41, 92),
        Offset(54, 58),
        Offset(75, 50),
        Offset(58, 43),
      ]),
      Paint()
        ..color = (onDark ? BrandColors.lavender : BrandColors.navy).withValues(
          alpha: .55,
        ),
    );
    canvas.drawCircle(
      const Offset(50, 50),
      3.8,
      Paint()..color = BrandColors.surface,
    );
    final sparkle = polygon(const [
      Offset(84, 10),
      Offset(86, 16),
      Offset(92, 18),
      Offset(86, 20),
      Offset(84, 26),
      Offset(82, 20),
      Offset(76, 18),
      Offset(82, 16),
    ]);
    canvas.drawPath(sparkle, Paint()..color = BrandColors.pink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CompassPainter oldDelegate) =>
      oldDelegate.onDark != onDark;
}
