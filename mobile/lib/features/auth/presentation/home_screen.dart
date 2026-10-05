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
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.homeGreeting(auth.user!.displayName),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () => context.push('/mock-exams/new'),
                          child: Text(l.mockAdd),
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
                    const SizedBox(height: 16),
                    dashboard.when(
                      skipLoadingOnRefresh: false,
                      skipLoadingOnReload: false,
                      loading:
                          () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      error: (e, _) => MockError(mockIssue(e), retry: refresh),
                      data: (d) => _content(context, d, l),
                    ),
                    const SizedBox(height: 16),
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

  Widget _content(BuildContext context, Dashboard d, AppLocalizations l) {
    final theme = Theme.of(context);
    Widget card(Widget child) =>
        Card(child: Padding(padding: const EdgeInsets.all(20), child: child));
    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(text, style: theme.textTheme.titleLarge),
    );
    Widget metric(String label, Score? value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        Text(value?.display ?? '—', style: theme.textTheme.headlineSmall),
      ],
    );
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
              const SizedBox(height: 12),
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
        if (d.count == 0)
          card(
            Column(
              children: [
                Text(l.mockEmpty),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/mock-exams/new'),
                  child: Text(l.mockFirst),
                ),
              ],
            ),
          ),
        if (d.count > 0) ...[
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.dashboardLatest),
                Text(
                  d.latest!.display,
                  key: const Key('dashboard.latest'),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text('${l.dashboardCount}: ${d.count}'),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 32,
                  runSpacing: 20,
                  children: [
                    metric(l.dashboardAverage, d.average),
                    metric(l.dashboardBest, d.best),
                  ],
                ),
                const SizedBox(height: 20),
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
                  const SizedBox(height: 12),
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
          Card(
            child: ListTile(
              key: Key('dashboard.recent.${mock.id}'),
              title: Text(mock.name),
              subtitle: Text(
                '${DateFormat.yMMMMd('tr').format(mock.date.pickerDate)} · ${mock.net.display} ${l.mockNet}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/mock-exams/${mock.id}'),
            ),
          ),
      ],
    );
  }
}
