import '../../core/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/presentation/premium_auth_page.dart';
import '../../l10n/app_localizations.dart';
import '../auth/application/auth_controller.dart';
import '../auth/presentation/auth_text.dart';
import '../auth/presentation/auth_widgets.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(authControllerProvider);
    void navigate(String path) {
      ref.read(authControllerProvider.notifier).clearIssue();
      context.push(path);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpace.formWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthBrandHeader(),
                  const SizedBox(height: AppSpace.xl),
                  Text(
                    l10n.welcomeTagline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpace.xxl),
                  FilledButton(
                    onPressed: state.busy ? null : () => navigate('/login'),
                    child: Text(l10n.loginAction),
                  ),
                  const SizedBox(height: AppSpace.md),
                  OutlinedButton(
                    onPressed: state.busy ? null : () => navigate('/register'),
                    child: Text(l10n.registerAction),
                  ),
                  if (state.issue != null)
                    AuthNotice(authIssueText(l10n, state.issue!)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
