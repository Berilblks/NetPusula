import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/dashboard.dart';

class NetTrendChart extends StatelessWidget {
  const NetTrendChart({required this.points, this.target, super.key});
  final List<TrendPoint> points;
  final Score? target;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (points.isEmpty) return Text(l.dashboardNoData);
    final scores = [
      Score('0'),
      if (target != null) target!,
      ...points.map((p) => p.net),
    ]..sort((a, b) => a.chartValue.compareTo(b.chartValue));
    final low = scores.first, high = scores.last;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label:
          '${l.dashboardTrend}. ${target == null ? '' : '${l.targetLabel}: ${target!.display}.'} ${points.map((p) => '${p.name}, ${p.date.iso}, ${p.net.display} ${l.mockNet}').join('; ')}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              children: [
                Text('${l.mockNet}: ${low.display} – ${high.display}'),
                if (target != null)
                  Text('${l.targetLabel}: ${target!.display}'),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: CustomPaint(
                key: const Key('dashboard.chart'),
                painter: NetTrendPainter(
                  points.map((p) => p.net.chartValue).toList(),
                  target?.chartValue,
                  low.chartValue,
                  high.chartValue,
                  colors.primary,
                  colors.tertiary,
                  colors.outlineVariant,
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              children: [
                Text(points.first.date.iso),
                if (points.length > 1) Text(points.last.date.iso),
              ],
            ),
            Text(
              target == null ? l.statisticsChartHint : l.dashboardChartHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class NetTrendPainter extends CustomPainter {
  NetTrendPainter(
    this.values,
    this.target,
    this.low,
    this.high,
    this.lineColor,
    this.targetColor,
    this.axisColor,
  );
  final List<double> values;
  final double? target;
  final double low, high;
  final Color lineColor, targetColor, axisColor;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.isEmpty) return;
    final rect = Rect.fromLTRB(8, 10, size.width - 8, size.height - 10);
    final span = high == low ? 1.0 : high - low;
    double y(double v) => rect.bottom - (v - low) / span * rect.height;
    final axis =
        Paint()
          ..color = axisColor
          ..strokeWidth = 1;
    canvas.drawLine(rect.bottomLeft, rect.bottomRight, axis);
    canvas.drawLine(rect.topLeft, rect.bottomLeft, axis);
    final reference =
        Paint()
          ..color = targetColor
          ..strokeWidth = 1.5;
    for (double x = rect.left; target != null && x < rect.right; x += 10) {
      canvas.drawLine(
        Offset(x, y(target!)),
        Offset((x + 5).clamp(rect.left, rect.right), y(target!)),
        reference,
      );
    }
    final line =
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
    final dot = Paint()..color = lineColor;
    Offset point(int i) => Offset(
      values.length == 1
          ? rect.center.dx
          : rect.left + i / (values.length - 1) * rect.width,
      y(values[i]),
    );
    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(point(i).dx, point(i).dy);
    }
    canvas.drawPath(path, line);
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(point(i), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant NetTrendPainter old) => true;
}
