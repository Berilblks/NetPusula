import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../preparation/application/preparation_controller.dart';
import '../../preparation/domain/preparation.dart';
import '../application/mock_exam_controller.dart';
import '../data/mock_exam_repository.dart';
import '../domain/mock_exam.dart';

String issueText(AppLocalizations l, MockIssue issue) => switch (issue) {
  MockIssue.validation => l.mockValidation,
  MockIssue.session => l.mockSession,
  MockIssue.missing => l.mockMissing,
  MockIssue.noPreparation => l.mockNoPreparation,
  MockIssue.conflict => l.mockConflict,
  MockIssue.rateLimited => l.mockRateLimited,
  MockIssue.network => l.mockNetwork,
  MockIssue.server => l.mockFailure,
};
String dateText(CalendarDate date) =>
    DateFormat.yMMMMd('tr').format(date.pickerDate);

class MockError extends ConsumerWidget {
  const MockError(this.issue, {required this.retry, super.key});
  final MockIssue issue;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(issueText(l, issue), textAlign: TextAlign.center),
        TextButton(
          onPressed:
              issue == MockIssue.noPreparation
                  ? () =>
                      ref.read(preparationControllerProvider.notifier).load()
                  : retry,
          child: Text(
            issue == MockIssue.noPreparation
                ? l.mockPreparationAction
                : l.mockRetry,
          ),
        ),
      ],
    );
  }
}

class MockHistoryScreen extends ConsumerWidget {
  const MockHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!,
        state = ref.watch(mockHistoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.mockHistory),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton(
            onPressed: () => context.push('/mock-exams/new'),
            child: Text(l.mockAdd),
          ),
          if (state.loading && state.items.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (!state.loading && state.issue == null && state.items.isEmpty) ...[
            Text(l.mockEmpty),
            TextButton(
              onPressed: () => context.push('/mock-exams/new'),
              child: Text(l.mockFirst),
            ),
          ],
          for (final exam in state.items)
            Card(
              child: ListTile(
                key: Key('mock.${exam.id}'),
                title: Text(exam.name),
                subtitle: Text(dateText(exam.date)),
                trailing: Text('${displayNet(exam.totalNet)} ${l.mockNet}'),
                onTap: () => context.push('/mock-exams/${exam.id}'),
              ),
            ),
          if (state.issue != null)
            MockError(
              state.issue!,
              retry:
                  () => ref
                      .read(mockHistoryProvider.notifier)
                      .load(more: state.items.isNotEmpty),
            ),
          if (state.page > 0 && state.page < state.totalPages)
            TextButton(
              onPressed:
                  state.loading
                      ? null
                      : () => ref
                          .read(mockHistoryProvider.notifier)
                          .load(more: true),
              child: Text(l.mockMore),
            ),
          if (state.loading && state.items.isNotEmpty)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class MockBreakdown extends StatelessWidget {
  const MockBreakdown(this.exam, {super.key});
  final MockExam exam;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(exam.name, style: Theme.of(context).textTheme.headlineSmall),
        Text(dateText(exam.date)),
        if (exam.notes?.isNotEmpty == true) Text(exam.notes!),
        const SizedBox(height: 20),
        Text(l.mockTotal),
        Text(
          '${displayNet(exam.totalNet)} ${l.mockNet}',
          key: const Key('mock.total'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        for (final result in exam.results)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (result.section.groupName != null)
                    Text(result.section.groupName!),
                  Text(
                    result.section.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${l.mockCorrect}: ${result.correct} · ${l.mockWrong}: ${result.wrong} · ${l.mockBlank}: ${result.blank}',
                  ),
                  Text('${displayNet(result.net)} ${l.mockNet}'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class MockDetailScreen extends ConsumerWidget {
  const MockDetailScreen(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!,
        detail = ref.watch(mockDetailProvider(id)),
        mutation = ref.watch(mockMutationProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.mockHistory),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => Center(
              child: MockError(
                mockIssue(e),
                retry: () => ref.invalidate(mockDetailProvider(id)),
              ),
            ),
        data:
            (exam) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                MockBreakdown(exam),
                if (mutation.issue != null) Text(issueText(l, mutation.issue!)),
                FilledButton(
                  onPressed:
                      mutation.busy
                          ? null
                          : () => context.push('/mock-exams/$id/edit'),
                  child: Text(l.mockEdit),
                ),
                TextButton(
                  key: const Key('mock.delete'),
                  onPressed:
                      mutation.busy
                          ? null
                          : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder:
                                  (dialog) => AlertDialog(
                                    title: Text(l.mockDeleteTitle),
                                    content: Text(l.mockDeleteBody),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(dialog, false),
                                        child: Text(l.mockCancel),
                                      ),
                                      FilledButton(
                                        key: const Key('mock.confirmDelete'),
                                        onPressed:
                                            () => Navigator.pop(dialog, true),
                                        child: Text(l.mockDelete),
                                      ),
                                    ],
                                  ),
                            );
                            if (confirmed != true || !context.mounted) return;
                            final deleted = await ref
                                .read(mockMutationProvider.notifier)
                                .delete(id);
                            if (deleted && context.mounted) {
                              context.go('/mock-exams');
                            }
                          },
                  child: Text(l.mockDelete),
                ),
              ],
            ),
      ),
    );
  }
}

class MockFormScreen extends ConsumerStatefulWidget {
  const MockFormScreen({this.id, super.key});
  final String? id;
  @override
  ConsumerState<MockFormScreen> createState() => _MockFormScreenState();
}

class _MockFormScreenState extends ConsumerState<MockFormScreen> {
  int step = 0;
  bool invalid = false;
  MockExam? saved;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!,
        draft = ref.watch(mockDraftProvider(widget.id)),
        mutation = ref.watch(mockMutationProvider);
    return PopScope(
      canPop: step == 0 && !mutation.busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !mutation.busy && step > 0) setState(() => step--);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            saved != null
                ? l.mockSaved
                : widget.id == null
                ? l.mockNew
                : l.mockEdit,
          ),
          leading: BackButton(
            onPressed:
                mutation.busy
                    ? null
                    : () {
                      if (step > 0 && saved == null) {
                        setState(() => step--);
                      } else {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/mock-exams');
                        }
                      }
                    },
          ),
        ),
        body:
            saved != null
                ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    MockBreakdown(saved!),
                    FilledButton(
                      onPressed: () => context.go('/mock-exams'),
                      child: Text(l.mockToHistory),
                    ),
                    TextButton(
                      onPressed: () => context.go('/home'),
                      child: Text(l.mockHome),
                    ),
                  ],
                )
                : draft.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (e, _) => Center(
                        child: MockError(
                          mockIssue(e),
                          retry:
                              () =>
                                  ref.invalidate(mockDraftProvider(widget.id)),
                        ),
                      ),
                  data: (value) => _form(value, l, mutation),
                ),
      ),
    );
  }

  Widget _form(
    MockDraft draft,
    AppLocalizations l,
    MockMutationState mutation,
  ) {
    if (draft.answers.isEmpty) return Center(child: Text(l.mockNoSections));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('${step + 1} / 3', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        if (step == 0) ...[
          TextFormField(
            key: const Key('mock.name'),
            initialValue: draft.name,
            maxLength: 200,
            decoration: InputDecoration(labelText: l.mockName),
            onChanged: (v) => draft.name = v,
            enabled: !mutation.busy,
          ),
          ListTile(
            key: const Key('mock.date'),
            title: Text(l.mockDate),
            subtitle: Text(dateText(draft.date)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final today =
                  CalendarDate.local(ref.read(localNowProvider)()).pickerDate;
              final selected = await showDatePicker(
                context: context,
                initialDate:
                    draft.date.pickerDate.isAfter(today)
                        ? today
                        : draft.date.pickerDate,
                firstDate: DateTime(1),
                lastDate: today,
              );
              if (selected != null && mounted) {
                setState(() => draft.date = CalendarDate.local(selected));
              }
            },
          ),
          TextFormField(
            key: const Key('mock.notes'),
            initialValue: draft.notes,
            maxLength: 4000,
            maxLines: 3,
            decoration: InputDecoration(labelText: l.mockNotes),
            onChanged: (v) => draft.notes = v,
            enabled: !mutation.busy,
          ),
        ],
        if (step == 1) ...[
          Text(l.mockSections, style: Theme.of(context).textTheme.titleLarge),
          for (final group
              in draft.answers.map((a) => a.section.groupCode).toSet()) ...[
            if (group != null)
              Text(
                draft.answers
                    .firstWhere((a) => a.section.groupCode == group)
                    .section
                    .groupName!,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            for (final answer in draft.answers.where(
              (a) => a.section.groupCode == group,
            ))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        answer.section.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text('${answer.section.questions} ${l.mockQuestions}'),
                      TextFormField(
                        key: Key('correct.${answer.section.id}'),
                        initialValue: answer.correct,
                        decoration: InputDecoration(labelText: l.mockCorrect),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (v) => setState(() => answer.correct = v),
                      ),
                      TextFormField(
                        key: Key('wrong.${answer.section.id}'),
                        initialValue: answer.wrong,
                        decoration: InputDecoration(labelText: l.mockWrong),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (v) => setState(() => answer.wrong = v),
                      ),
                      Text(
                        '${l.mockBlank}: ${answer.blank ?? '—'}',
                        key: Key('blank.${answer.section.id}'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
        if (step == 2) ...[
          Text(l.mockReview, style: Theme.of(context).textTheme.titleLarge),
          Text(draft.name),
          Text(dateText(draft.date)),
          if (draft.notes.isNotEmpty) Text(draft.notes),
          for (final answer in draft.answers)
            ListTile(
              title: Text(answer.section.name),
              subtitle: Text(
                '${l.mockCorrect}: ${answer.correct} · ${l.mockWrong}: ${answer.wrong} · ${l.mockBlank}: ${answer.blank}',
              ),
            ),
        ],
        if (invalid)
          Text(
            l.mockValidation,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (mutation.issue != null)
          MockError(
            mutation.issue!,
            retry: () async {
              if (!draft.valid(
                CalendarDate.local(ref.read(localNowProvider)()),
              )) {
                setState(() => invalid = true);
                return;
              }
              final result = await ref
                  .read(mockMutationProvider.notifier)
                  .save(draft);
              if (result != null && mounted) {
                setState(() {
                  saved = result;
                  step = 0;
                });
              }
            },
          ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('mock.next'),
          onPressed:
              mutation.busy
                  ? null
                  : () async {
                    final valid =
                        step == 0
                            ? draft.name.trim().isNotEmpty &&
                                draft.name.trim().length <= 200 &&
                                draft.date.compareTo(
                                      CalendarDate.local(
                                        ref.read(localNowProvider)(),
                                      ),
                                    ) <=
                                    0
                            : draft.valid(
                              CalendarDate.local(ref.read(localNowProvider)()),
                            );
                    setState(() => invalid = !valid);
                    if (!valid) return;
                    if (step < 2) {
                      setState(() => step++);
                      return;
                    }
                    final result = await ref
                        .read(mockMutationProvider.notifier)
                        .save(draft);
                    if (result != null && mounted) {
                      setState(() {
                        saved = result;
                        step = 0;
                      });
                    }
                  },
          child:
              mutation.busy
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text(step == 2 ? l.mockSave : l.mockNext),
        ),
        if (step > 0)
          TextButton(
            key: const Key('mock.back'),
            onPressed: mutation.busy ? null : () => setState(() => step--),
            child: Text(l.mockBack),
          ),
      ],
    );
  }
}
