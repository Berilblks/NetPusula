import '../../../core/widgets/app_components.dart';
import '../../../core/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../preparation/application/preparation_controller.dart';
import '../../dashboard/presentation/net_trend_chart.dart';
import '../../mock_exams/data/mock_exam_repository.dart';
import '../../mock_exams/presentation/mock_exam_screens.dart' show MockError;
import '../application/statistics_provider.dart';
import '../domain/statistics.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});
  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  String range = '20';
  String? selectedSection;
  Future<void> refresh() async {
    final provider = statisticsProvider(range);
    try {
      ref.invalidate(provider);
      await ref.read(provider.future);
    } catch (_) {
      /* Provider renders safe error. */
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authControllerProvider).status != AuthStatus.authenticated ||
        ref.watch(preparationControllerProvider).active == null) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context)!;
    final data = ref.watch(statisticsProvider(range));
    return Scaffold(
      appBar: pageAppBar(context, title: l.statisticsTitle),
      body: PageBody(
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in ['5', '10', '20', 'all'])
                          ChoiceChip(
                            key: Key('statistics.range.$option'),
                            label: Text(
                              option == 'all'
                                  ? l.statisticsAll
                                  : l.statisticsLast(option),
                            ),
                            selected: range == option,
                            onSelected: (_) => setState(() => range = option),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.lg),
                    data.when(
                      skipLoadingOnRefresh: false,
                      skipLoadingOnReload: false,
                      loading: () => const AppLoading(),
                      error: (e, _) => MockError(mockIssue(e), retry: refresh),
                      data: (d) => content(d, l),
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

  Widget card(Widget child) => AppCard(child: child);
  Widget title(String text) => SectionHeader(text);
  Widget metric(String label, String value) =>
      MetricValue(label: label, value: value);
  Widget metrics(StatisticsMetrics m, AppLocalizations l) => Wrap(
    spacing: 24,
    runSpacing: 16,
    children: [
      metric(l.dashboardLatest, m.latest?.display ?? '—'),
      MetricValue(
        label: l.dashboardAverage,
        value: m.average?.display ?? '—',
        primary: true,
      ),
      metric(l.dashboardBest, m.best?.display ?? '—'),
      metric(l.statisticsWorst, m.worst?.display ?? '—'),
      metric(l.dashboardCount, '${m.count}'),
    ],
  );
  Widget comparison(StatisticsChange c, AppLocalizations l) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      c.enough
          ? l.dashboardChange(
            '${c.change!.negative || c.change!.isZero ? '' : '+'}${c.change!.display}',
          )
          : l.statisticsInsufficient,
    ),
  );
  Widget content(Statistics d, AppLocalizations l) {
    if (d.metrics.count == 0) {
      return AppMessage(
        message: l.statisticsEmpty,
        icon: Icons.insights_outlined,
        actionLabel: l.mockFirst,
        onAction: () => context.push('/mock-exams/new'),
      );
    }
    final section =
        d.sections.where((s) => s.id == selectedSection).firstOrNull ??
        d.sections.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (d.capped) Text(l.statisticsCap(d.limit, d.available)),
        title(l.statisticsOverview),
        card(metrics(d.metrics, l)),
        title(l.dashboardTrend),
        card(NetTrendChart(points: d.series, target: d.target)),
        comparison(d.change, l),
        if (d.best != null) ...[
          title(l.statisticsBestMock),
          MockSummaryCard(
            key: const Key('statistics.best'),
            name: d.best!.name,
            date: d.best!.date.iso,
            net: '${d.best!.net.display} ${l.mockNet}',
            onTap: () => context.push('/mock-exams/${d.best!.id}'),
          ),
        ],
        if (section != null) ...[
          title(l.statisticsSections),
          for (final group in d.sections.map((s) => s.groupCode).toSet()) ...[
            if (group != null)
              Text(
                d.sections.firstWhere((s) => s.groupCode == group).groupName ??
                    group,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in d.sections.where((s) => s.groupCode == group))
                  ChoiceChip(
                    key: Key('statistics.section.${s.id}'),
                    label: Text(
                      s.active ? s.name : '${s.name} (${l.dashboardRetired})',
                    ),
                    selected: section.id == s.id,
                    onSelected: (_) => setState(() => selectedSection = s.id),
                  ),
              ],
            ),
          ],
          title(section.name),
          if (section.metrics.count == 0)
            AppMessage(
              message: l.statisticsSectionEmpty,
              icon: Icons.show_chart,
            )
          else ...[
            card(metrics(section.metrics, l)),
            card(
              NetTrendChart(
                points: section.series.map((p) => p.point).toList(),
              ),
            ),
            comparison(section.change, l),
            title(l.statisticsAnswers),
            card(AnswerDistribution(section: section)),
            ExpansionTile(
              title: Text(l.statisticsAnswerHistory),
              children: [
                for (final p in section.series)
                  ListTile(
                    title: Text(p.point.date.iso),
                    subtitle: Text(
                      '${l.mockCorrect}: ${p.correct} · ${l.mockWrong}: ${p.wrong} · ${l.mockBlank}: ${p.blank}',
                    ),
                  ),
              ],
            ),
          ],
        ],
        title(l.statisticsActivity),
        card(
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              metric(l.statisticsFirst, d.first ?? '—'),
              metric(l.statisticsLatestDate, d.last ?? '—'),
              metric(l.dashboardCount, '${d.metrics.count}'),
              metric(l.statisticsInterval, d.interval?.display ?? '—'),
            ],
          ),
        ),
        Text(l.statisticsActivityHint),
      ],
    );
  }
}

class AnswerDistribution extends StatelessWidget {
  const AnswerDistribution({required this.section, super.key});
  final StatisticsSection section;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final entries = [
      (l.statisticsCorrect, section.correct),
      (l.statisticsWrong, section.wrong),
      (l.statisticsBlank, section.blank),
    ];
    // Relative bar lengths only; the displayed averages are supplied by the backend.
    final maximum = entries.fold<double>(
      0,
      (m, e) => e.$2 != null && e.$2!.chartValue > m ? e.$2!.chartValue : m,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Semantics(
              container: true,
              label: '${e.$1}: ${e.$2?.display ?? '—'}',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.$1}: ${e.$2?.display ?? '—'}'),
                    const SizedBox(height: AppSpace.xs),
                    LinearProgressIndicator(
                      value:
                          maximum == 0 ? 0 : (e.$2?.chartValue ?? 0) / maximum,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
