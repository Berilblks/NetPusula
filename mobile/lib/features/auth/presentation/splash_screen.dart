import '../../../core/widgets/app_components.dart';
import '../../../core/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_brand.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import 'auth_text.dart';
import 'auth_widgets.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpace.formWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppBrand.name,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  if (state.status == AuthStatus.startupError) ...[
                    AuthNotice(authIssueText(l10n, state.issue!)),
                    FilledButton(
                      onPressed:
                          () =>
                              ref
                                  .read(authControllerProvider.notifier)
                                  .initialize(),
                      child: Text(l10n.retryAction),
                    ),
                    TextButton(
                      onPressed:
                          () =>
                              ref
                                  .read(authControllerProvider.notifier)
                                  .logout(),
                      child: Text(l10n.localSignOutAction),
                    ),
                  ] else ...[
                    const AppLoading(),
                    const SizedBox(height: AppSpace.lg),
                    Text(l10n.startupMessage),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
