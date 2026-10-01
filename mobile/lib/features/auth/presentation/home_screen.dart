import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import 'auth_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../preparation/application/preparation_controller.dart';
import '../../preparation/domain/preparation.dart';
import '../../preparation/presentation/preparation_text.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final user = state.user;
    final preparation = ref.watch(preparationControllerProvider).active;
    if (state.status != AuthStatus.authenticated ||
        user == null ||
        preparation == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.waving_hand_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.homeGreeting(user.displayName),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.homeWelcome, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Text(
                    preparation.exam.code,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(preparation.exam.name, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Text(l10n.targetLabel),
                  Text(
                    l10n.netValue(preparation.target.turkish),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    remainingText(
                      l10n,
                      preparation.date,
                      CalendarDate.local(ref.watch(localNowProvider)()),
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    DateFormat.yMMMMd('tr').format(preparation.date.pickerDate),
                  ),
                  const SizedBox(height: 20),
                  Text(l10n.mockTrackingSoon, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () => context.push('/goal/edit'),
                    child: Text(l10n.editGoalAction),
                  ),
                  const SizedBox(height: 32),
                  AuthSubmit(
                    label: l10n.logoutAction,
                    busy: state.busy,
                    onPressed:
                        () =>
                            ref.read(authControllerProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
