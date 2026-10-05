import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';

// Page layout only: routing, refresh, and provider ownership stay in feature screens.
class PageBody extends StatelessWidget {
  const PageBody({
    required this.child,
    this.maxWidth = AppSpace.contentWidth,
    super.key,
  });
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );
}

PreferredSizeWidget pageAppBar(
  BuildContext context, {
  required String title,
  Widget? leading,
}) => AppBar(
  toolbarHeight: MediaQuery.textScalerOf(context).scale(20) > 28 ? 112 : 64,
  title: Text(title, maxLines: 2),
  leading: leading,
);

class AppCard extends StatelessWidget {
  const AppCard({required this.child, this.highlight = false, super.key});
  final Widget child;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Card(
    color: highlight ? Theme.of(context).colorScheme.primaryContainer : null,
    child: Padding(padding: AppSpace.card, child: child),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.xl, bottom: AppSpace.md),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}

class MetricValue extends StatelessWidget {
  const MetricValue({
    required this.label,
    required this.value,
    this.primary = false,
    super.key,
  });
  final String label, value;
  final bool primary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: AppSpace.xs),
      Text(
        value,
        style:
            primary
                ? Theme.of(context).textTheme.headlineSmall
                : Theme.of(context).textTheme.titleLarge,
      ),
    ],
  );
}

class AppMessage extends StatelessWidget {
  const AppMessage({
    required this.message,
    this.icon = Icons.info_outline,
    this.error = false,
    this.actionLabel,
    this.onAction,
    super.key,
  });
  final String message;
  final IconData icon;
  final bool error;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: error,
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  error ? Icons.error_outline : icon,
                  color: error ? c.error : c.primary,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: error ? c.error : c.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (onAction != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.md),
                child: OutlinedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AppLoading extends StatelessWidget {
  const AppLoading({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpace.xxl),
    child: Center(
      child: CircularProgressIndicator(
        semanticsLabel: AppLocalizations.of(context)!.pleaseWait,
      ),
    ),
  );
}

class SubmitContent extends StatelessWidget {
  const SubmitContent({required this.label, required this.busy, super.key});
  final String label;
  final bool busy;
  @override
  Widget build(BuildContext context) =>
      busy
          ? Semantics(
            label: '$label. ${AppLocalizations.of(context)!.pleaseWait}',
            liveRegion: true,
            child: ExcludeSemantics(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpace.md,
                runSpacing: AppSpace.sm,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  Text(label),
                ],
              ),
            ),
          )
          : Text(label);
}

class StepProgress extends StatelessWidget {
  const StepProgress({
    required this.label,
    required this.step,
    required this.total,
    super.key,
  });
  final String label;
  final int step, total;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpace.sm),
          LinearProgressIndicator(value: step / total),
          const SizedBox(height: AppSpace.xl),
        ],
      ),
    ),
  );
}

class MockSummaryCard extends StatelessWidget {
  const MockSummaryCard({
    required this.name,
    required this.date,
    required this.net,
    required this.onTap,
    super.key,
  });
  final String name, date, net;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Padding(
        padding: AppSpace.card,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpace.xs),
                  Text(date, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpace.sm),
                  Text(net, style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
