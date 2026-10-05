import '../../../core/widgets/app_components.dart';
import '../../../core/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import '../../preparation/application/preparation_controller.dart';
import '../../preparation/domain/preparation.dart';
import '../../dashboard/application/dashboard_provider.dart';
import '../../dashboard/domain/dashboard.dart';
import '../../dashboard/presentation/net_trend_chart.dart';
import '../../mock_exams/data/mock_exam_repository.dart';
import '../../mock_exams/presentation/mock_exam_screens.dart' show MockError;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider),
        prep = ref.watch(preparationControllerProvider).active;
    if (auth.status != AuthStatus.authenticated ||
        auth.user == null ||
        prep == null) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context)!,
        dashboard = ref.watch(dashboardProvider);
    Future<void> refresh() async {
      try {
        ref.invalidate(dashboardProvider);
        await ref.read(dashboardProvider.future);
      } catch (_) {
        /* Error rendered by provider. */
      }
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpace.contentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.homeGreeting(auth.user!.displayName),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpace.lg),
                    dashboard.when(
                      skipLoadingOnRefresh: false,
                      skipLoadingOnReload: false,
                      loading: () => const AppLoading(),
                      error: (e, _) => MockError(mockIssue(e), retry: refresh),
                      data: (d) => _content(context, d, l),
                    ),
                    if (!dashboard.hasValue) _actions(context, l),
                    const SizedBox(height: AppSpace.xl),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => context.push('/goal/edit'),
                          child: Text(l.editGoalAction),
                        ),
                        TextButton(
                          onPressed: refresh,
                          child: Text(l.dashboardRefresh),
                        ),
                        TextButton(
                          onPressed:
                              auth.busy
                                  ? null
                                  : () =>
                                      ref
                                          .read(authControllerProvider.notifier)
                                          .logout(),
                          child: Text(l.logoutAction),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, AppLocalizations l) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
    child: Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        FilledButton.icon(
          onPressed: () => context.push('/mock-exams/new'),
          icon: const Icon(Icons.add),
          label: Text(l.mockAdd),
        ),
        TextButton(
          onPressed: () => context.push('/mock-exams'),
          child: Text(l.mockHistory),
        ),
        TextButton(
          onPressed: () => context.push('/statistics'),
          child: Text(l.statisticsEntry),
        ),
      ],
    ),
  );

  Widget _content(BuildContext context, Dashboard d, AppLocalizations l) {
    final theme = Theme.of(context);
    Widget card(Widget child) => AppCard(child: child);
    Widget title(String text) => SectionHeader(text);
    Widget metric(String label, Score? value) =>
        MetricValue(label: label, value: value?.display ?? '—');
    final difference = d.difference;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.examCode, style: theme.textTheme.labelLarge),
              Text(d.examName, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpace.md),
              Text(l.targetLabel),
              Text(l.netValue(NetTarget.parse(d.target.value)!.turkish)),
              Text(switch (d.dateStatus) {
                'past' => l.examPassed,
                'today' => l.examToday,
                _ => l.daysRemaining(d.days),
              }),
              Text(DateFormat.yMMMMd('tr').format(d.date.pickerDate)),
            ],
          ),
        ),
        _actions(context, l),
        if (d.count == 0)
          AppMessage(
            message: l.mockEmpty,
            icon: Icons.assignment_outlined,
            actionLabel: l.mockFirst,
            onAction: () => context.push('/mock-exams/new'),
          ),
        if (d.count > 0) ...[
          AppCard(
            highlight: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.dashboardLatest),
                Text(
                  d.latest!.display,
                  key: const Key('dashboard.latest'),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text('${l.dashboardCount}: ${d.count}'),
                const SizedBox(height: AppSpace.lg),
                Wrap(
                  spacing: 32,
                  runSpacing: 20,
                  children: [
                    metric(l.dashboardAverage, d.average),
                    metric(l.dashboardBest, d.best),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  difference!.isZero
                      ? l.dashboardReached
                      : difference.negative
                      ? '${l.dashboardAbove}: ${difference.absolute} ${l.mockNet}'
                      : '${l.dashboardRemaining}: ${difference.display} ${l.mockNet}',
                  key: const Key('dashboard.difference'),
                ),
              ],
            ),
          ),
          title(l.dashboardTrend),
          card(NetTrendChart(points: d.trend, target: d.target)),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            d.enough
                ? l.dashboardChange(
                  '${d.change!.negative || d.change!.isZero ? '' : '+'}${d.change!.display}',
                )
                : l.dashboardInsufficient,
            key: const Key('dashboard.improvement'),
          ),
        ),
        if (d.sections.isNotEmpty) title(l.dashboardSections),
        for (final group in d.sections.map((s) => s.groupCode).toSet()) ...[
          if (group != null)
            Text(
              d.sections.firstWhere((s) => s.groupCode == group).groupName!,
              style: theme.textTheme.titleMedium,
            ),
          for (final s in d.sections.where((s) => s.groupCode == group))
            card(
              Column(
                key: Key('dashboard.section.${s.id}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: theme.textTheme.titleMedium),
                  if (!s.active) Text(l.dashboardRetired),
                  Text(
                    '${s.questions} ${l.mockQuestions} · ${l.dashboardCount}: ${s.count}',
                  ),
                  const SizedBox(height: AppSpace.md),
                  if (s.count == 0)
                    Text(l.dashboardNoData)
                  else
                    Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        metric(l.dashboardLatest, s.latest),
                        metric(l.dashboardAverage, s.average),
                        metric(l.dashboardBest, s.best),
                      ],
                    ),
                ],
              ),
            ),
        ],
        if (d.recent.isNotEmpty) title(l.dashboardRecent),
        for (final mock in d.recent)
          MockSummaryCard(
            key: Key('dashboard.recent.${mock.id}'),
            name: mock.name,
            date: DateFormat.yMMMMd('tr').format(mock.date.pickerDate),
            net: '${mock.net.display} ${l.mockNet}',
            onTap: () => context.push('/mock-exams/${mock.id}'),
          ),
      ],
    );
  }
}
