import 'package:flutter/services.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/widgets/compass_mark.dart';
import '../../dashboard/presentation/premium_widgets.dart';
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        bottomNavigationBar: HomeNavigation(
          onHome:
              () => _scroll.animateTo(
                0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              ),
          onHistory: () => context.push('/mock-exams'),
          onAdd: () => context.push('/mock-exams/new'),
          onGoal: () => context.push('/goal/edit'),
          onStatistics: () => context.push('/statistics'),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: BrandColors.header),
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: refresh,
              child: SingleChildScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppSpace.contentWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: BrandColors.header,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CompassMark(size: 30, onDark: true),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        AppBrand.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          color: BrandColors.surface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  l.homeGreeting(auth.user!.displayName),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium?.copyWith(
                                    color: BrandColors.surface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l.homeEncouragement,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(color: BrandColors.surface),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpace.lg),
                          dashboard.when(
                            skipLoadingOnRefresh: false,
                            skipLoadingOnReload: false,
                            loading: () => const AppLoading(),
                            error:
                                (e, _) =>
                                    MockError(mockIssue(e), retry: refresh),
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
                                                .read(
                                                  authControllerProvider
                                                      .notifier,
                                                )
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
    Widget card(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(child: child),
    );
    Widget title(String text) => SectionHeader(text);
    Widget metric(String label, Score? value) =>
        MetricValue(label: label, value: value?.display ?? '—');
    final difference = d.difference;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CompassMark(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.examCode, style: theme.textTheme.labelMedium),
                        Text(d.examName, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: [
                            Text('${l.targetLabel}:'),
                            Text(
                              l.netValue(
                                NetTarget.parse(d.target.value)!.turkish,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.editGoalAction,
                    onPressed: () => context.push('/goal/edit'),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final info = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.dashboardLatest,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      if (difference != null)
                        Text(
                          difference.isZero
                              ? l.dashboardReached
                              : difference.negative
                              ? '${l.dashboardAbove}: ${difference.absolute} ${l.mockNet}'
                              : '${l.dashboardRemaining}: ${difference.display} ${l.mockNet}',
                          key: const Key('dashboard.difference'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        )
                      else
                        Text(l.dashboardNoData),
                      const SizedBox(height: 16),
                      if (d.best != null) metric(l.dashboardBest, d.best),
                    ],
                  );
                  final ring = TargetRing(latest: d.latest, target: d.target);
                  return constraints.maxWidth < 280 ||
                          MediaQuery.textScalerOf(context).scale(14) > 21
                      ? Column(
                        children: [ring, const SizedBox(height: 16), info],
                      )
                      : Row(
                        children: [
                          ring,
                          const SizedBox(width: 16),
                          Expanded(child: info),
                        ],
                      );
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(switch (d.dateStatus) {
                    'past' => l.examPassed,
                    'today' => l.examToday,
                    _ => l.daysRemaining(d.days),
                  }),
                  Text(
                    DateFormat.yMMMMd('tr').format(d.date.pickerDate),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (d.trend.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(l.homeRecentTrend, style: theme.textTheme.labelLarge),
                MiniTrend(
                  d.trend
                      .skip(d.trend.length > 5 ? d.trend.length - 5 : 0)
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        if (d.count == 0)
          AppMessage(
            message: l.mockEmpty,
            icon: Icons.assignment_outlined,
            actionLabel: l.mockFirst,
            onAction: () => context.push('/mock-exams/new'),
          ),
        if (d.count > 0) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  MediaQuery.textScalerOf(context).scale(14) > 21 ? 1 : 3;
              final width =
                  (constraints.maxWidth - (columns - 1) * 8) / columns;
              final values = [
                (l.dashboardCount, '${d.count}'),
                (l.dashboardAverage, d.average?.display ?? '—'),
                (
                  l.homeNetChange,
                  d.enough && d.change != null
                      ? '${d.change!.negative || d.change!.isZero ? '' : '+'}${d.change!.display}'
                      : '—',
                ),
              ];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in values)
                    SizedBox(
                      width: width,
                      child: PremiumCard(
                        padding: const EdgeInsets.all(12),
                        child: MetricValue(label: value.$1, value: value.$2),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        _actions(context, l),
        if (d.count > 0) ...[
          title(l.dashboardTrend),
          card(NetTrendChart(points: d.trend, target: d.target, filled: true)),
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
