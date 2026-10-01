import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../application/preparation_controller.dart';
import '../domain/preparation.dart';
import '../data/preparation_repository.dart';
import 'preparation_text.dart';

class GoalScreen extends ConsumerStatefulWidget {
  const GoalScreen({super.key, this.edit = false});
  final bool edit;
  @override
  ConsumerState<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends ConsumerState<GoalScreen> {
  int step = 0;
  PreparationExam? selected;
  CalendarDate? date;
  String? editingId;
  String? localError;
  final target = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    if (widget.edit) {
      final active = ref.read(preparationControllerProvider).active;
      selected = active?.exam;
      date = active?.date;
      editingId = active?.id;
      target.text = active?.target.turkish ?? '';
    }
  }

  @override
  void dispose() {
    target.dispose();
    super.dispose();
  }

  CalendarDate get today => CalendarDate.local(ref.read(localNowProvider)());
  String? validateTarget(String? value) {
    final l = AppLocalizations.of(context)!;
    final net = NetTarget.parse(value ?? '');
    if (net == null) return l.prepTargetInvalid;
    final max = selected?.maximum;
    return max != null && net.units > max.units
        ? l.prepMaximum(max.turkish)
        : null;
  }

  Future<void> chooseDate() async {
    final minimum = today;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          date == null || date!.compareTo(minimum) < 0
              ? minimum.pickerDate
              : date!.pickerDate,
      firstDate: minimum.pickerDate,
      lastDate: DateTime(9999, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        date = CalendarDate.local(picked);
        localError = null;
      });
    }
  }

  Future<void> submit() async {
    if (ref.read(preparationControllerProvider).saving || selected == null) {
      return;
    }
    final l = AppLocalizations.of(context)!;
    final error =
        validateTarget(target.text) ??
        (date == null || date!.compareTo(today) < 0 ? l.prepDateInvalid : null);
    if (error != null) {
      setState(() => localError = error);
      return;
    }
    FocusScope.of(context).unfocus();
    final success = await ref
        .read(preparationControllerProvider.notifier)
        .save(
          id: widget.edit ? editingId : null,
          exam: selected!,
          target: NetTarget.parse(target.text)!,
          date: date!,
        );
    if (success && mounted && widget.edit) context.go('/home');
  }

  void next() {
    if (step == 2 && !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      step++;
      localError = null;
    });
  }

  void back() {
    if (step > 0) {
      setState(() {
        step--;
        localError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(preparationControllerProvider);
    final titles = [
      l.prepWelcome,
      l.prepExamTitle,
      l.prepTargetTitle,
      l.prepDateTitle,
      l.prepReviewTitle,
    ];
    final canContinue =
        step == 1
            ? selected != null
            : step == 3
            ? date != null && date!.compareTo(today) >= 0
            : true;
    return PopScope(
      canPop: widget.edit && !state.saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !state.saving && !widget.edit) back();
      },
      child: AuthPage(
        title: widget.edit ? l.editGoalAction : titles[step],
        subtitle: widget.edit ? selected?.code ?? '' : l.prepStep(step + 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.edit) ...[
              LinearProgressIndicator(value: (step + 1) / 5),
              const SizedBox(height: 24),
            ],
            if (widget.edit) ...[
              targetField(l, state.saving),
              const SizedBox(height: 24),
              dateField(l, state.saving),
            ] else ...[
              if (step == 0) ...[
                Icon(
                  Icons.explore_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  l.prepWelcomeBody,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              if (step == 1) examList(l),
              if (step == 2) targetField(l, state.saving),
              if (step == 3) dateField(l, state.saving),
              if (step == 4) ...[
                reviewRow(l.examLabel, '${selected!.code} · ${selected!.name}'),
                reviewRow(
                  l.targetLabel,
                  l.netValue(NetTarget.parse(target.text)!.turkish),
                ),
                reviewRow(
                  l.examDateLabel,
                  DateFormat.yMMMMd('tr').format(date!.pickerDate),
                ),
              ],
            ],
            if (localError != null) AuthNotice(localError!),
            if (state.issue != null)
              AuthNotice(preparationIssueText(l, state.issue!)),
            const SizedBox(height: 28),
            if (widget.edit || step == 4)
              AuthSubmit(
                key: const Key('goal.save'),
                label: widget.edit ? l.saveGoalAction : l.createGoalAction,
                busy: state.saving,
                onPressed: submit,
              )
            else
              FilledButton(
                key: const Key('goal.next'),
                onPressed: canContinue ? next : null,
                child: Text(l.continueAction),
              ),
            if (!widget.edit && step > 0)
              TextButton(
                key: const Key('goal.back'),
                onPressed: state.saving ? null : back,
                child: Text(l.backAction),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed:
                  state.saving
                      ? null
                      : () =>
                          ref.read(authControllerProvider.notifier).logout(),
              child: Text(l.logoutAction),
            ),
          ],
        ),
      ),
    );
  }

  Widget targetField(AppLocalizations l, bool busy) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.prepTargetHint),
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('goal.target'),
          controller: target,
          enabled: !busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          inputFormatters: [
            TextInputFormatter.withFunction(
              (oldValue, newValue) =>
                  RegExp(r'^\d{0,8}([,.]\d{0,4})?$').hasMatch(newValue.text)
                      ? newValue
                      : oldValue,
            ),
          ],
          decoration: InputDecoration(
            labelText: l.targetNetLabel,
            suffixText: 'net',
          ),
          validator: validateTarget,
          onFieldSubmitted: (_) {
            if (!widget.edit) next();
          },
        ),
        if (selected?.maximum != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l.prepMaximum(selected!.maximum!.turkish)),
          ),
      ],
    ),
  );
  Widget dateField(AppLocalizations l, bool busy) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(l.prepDateHint),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        key: const Key('goal.date'),
        onPressed: busy ? null : chooseDate,
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text(
          date == null
              ? l.chooseDateAction
              : DateFormat.yMMMMd('tr').format(date!.pickerDate),
        ),
      ),
    ],
  );
  Widget reviewRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
  Widget examList(AppLocalizations l) {
    final catalogue = ref.watch(examCatalogueProvider);
    return catalogue.when(
      loading:
          () => Center(
            child: CircularProgressIndicator(semanticsLabel: l.pleaseWait),
          ),
      error:
          (error, __) => Column(
            children: [
              AuthNotice(
                preparationIssue(error) == PreparationIssue.unexpected
                    ? l.prepLoadError
                    : preparationIssueText(l, preparationIssue(error)),
              ),
              TextButton(
                onPressed: () => ref.invalidate(examCatalogueProvider),
                child: Text(l.retryAction),
              ),
            ],
          ),
      data:
          (exams) =>
              exams.isEmpty
                  ? Column(
                    children: [
                      Text(l.examListEmpty),
                      TextButton(
                        onPressed: () => ref.invalidate(examCatalogueProvider),
                        child: Text(l.retryAction),
                      ),
                    ],
                  )
                  : Column(
                    children:
                        exams
                            .map(
                              (exam) => Card(
                                child: RadioListTile<String>(
                                  key: Key('exam.${exam.id}'),
                                  value: exam.id,
                                  groupValue: selected?.id,
                                  title: Text(exam.code),
                                  subtitle: Text(exam.name),
                                  onChanged:
                                      (_) => setState(() {
                                        if (selected?.id != exam.id) {
                                          target.clear();
                                        }
                                        selected = exam;
                                      }),
                                ),
                              ),
                            )
                            .toList(),
                  ),
    );
  }
}
