import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/dashboard.dart';
import 'net_trend_chart.dart';

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .35),
      ),
      boxShadow: [
        BoxShadow(
          color: BrandColors.navy.withValues(alpha: .045),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class TargetRing extends StatelessWidget {
  const TargetRing({required this.latest, required this.target, super.key});
  final Score? latest;
  final Score target;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // A bounded arc is presentation geometry, not a new percentage/score metric.
    final progress =
        latest == null || target.chartValue <= 0
            ? 0.0
            : (latest!.chartValue / target.chartValue).clamp(0.0, 1.0);
    return Semantics(
      label:
          '${l.dashboardLatest}: ${latest?.display ?? l.dashboardNoData}. ${l.targetLabel}: ${target.display} ${l.mockNet}',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 174,
          child: CustomPaint(
            painter: TargetRingPainter(
              progress,
              Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Padding(
              padding: const EdgeInsets.all(29),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        latest?.display ?? '—',
                        key:
                            latest == null
                                ? null
                                : const Key('dashboard.latest'),
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Text(l.mockNet, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TargetRingPainter extends CustomPainter {
  const TargetRingPainter(this.progress, this.track);
  final double progress;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(8);
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2,
      false,
      paint..color = track,
    );
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        progress * math.pi * 2,
        false,
        paint
          ..shader = const SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: math.pi * 1.5,
            transform: GradientRotation(-math.pi / 2),
            colors: [
              BrandColors.purple,
              BrandColors.lavender,
              BrandColors.pink,
            ],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(TargetRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.track != track;
}

class MiniTrend extends StatelessWidget {
  const MiniTrend(this.points, {super.key});
  final List<TrendPoint> points;
  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.net.chartValue).toList();
    final low = values.fold<double>(0, math.min),
        high = values.fold<double>(0, math.max);
    final c = Theme.of(context).colorScheme;
    return Semantics(
      label: points
          .map((p) => '${p.date.iso}: ${p.net.display} net')
          .join('; '),
      child: SizedBox(
        height: 62,
        child: CustomPaint(
          painter: NetTrendPainter(
            values,
            null,
            low,
            high,
            c.primary,
            c.tertiary,
            c.outlineVariant,
            filled: true,
            guides: false,
          ),
        ),
      ),
    );
  }
}

class HomeNavigation extends StatelessWidget {
  const HomeNavigation({
    required this.onHome,
    required this.onHistory,
    required this.onAdd,
    required this.onGoal,
    required this.onStatistics,
    super.key,
  });
  final VoidCallback onHome, onHistory, onAdd, onGoal, onStatistics;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    Widget item(
      String label,
      IconData icon,
      VoidCallback onTap, {
      bool selected = false,
      bool add = false,
    }) => Expanded(
      child: Semantics(
        selected: selected,
        onTap: onTap,
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(add ? 10 : 4),
                    decoration:
                        add
                            ? const BoxDecoration(
                              gradient: BrandColors.compass,
                              shape: BoxShape.circle,
                            )
                            : null,
                    child: Icon(
                      icon,
                      size: add ? 28 : 24,
                      color:
                          add
                              ? BrandColors.surface
                              : selected
                              ? colors.primary
                              : colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color:
                          selected ? colors.primary : colors.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Material(
      color: colors.surface,
      elevation: 8,
      shadowColor: BrandColors.navy.withValues(alpha: .1),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              item(l.homeNavHome, Icons.home_rounded, onHome, selected: true),
              item(l.homeNavMocks, Icons.assignment_outlined, onHistory),
              item(l.homeNavAdd, Icons.add, onAdd, add: true),
              item(l.homeNavGoal, Icons.flag_outlined, onGoal),
              item(l.homeNavStatistics, Icons.insights_rounded, onStatistics),
            ],
          ),
        ),
      ),
    );
  }
}
