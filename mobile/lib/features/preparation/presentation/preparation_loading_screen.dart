import '../../../core/widgets/app_components.dart';
import '../../../core/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../application/preparation_controller.dart';
import 'preparation_text.dart';

class PreparationLoadingScreen extends ConsumerWidget {
  const PreparationLoadingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(preparationControllerProvider);
    return AuthPage(
      title: l.prepLoading,
      subtitle: state.issue == null ? l.pleaseWait : l.prepLoadError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.status == PreparationStatus.error) ...[
            AuthNotice(preparationIssueText(l, state.issue!)),
            FilledButton(
              onPressed:
                  () => ref.read(preparationControllerProvider.notifier).load(),
              child: Text(l.retryAction),
            ),
          ] else
            const AppLoading(),
          const SizedBox(height: AppSpace.xl),
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: Text(l.logoutAction),
          ),
        ],
      ),
    );
  }
}
