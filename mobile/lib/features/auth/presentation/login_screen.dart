import '../../../core/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import 'auth_text.dart';
import 'auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (ref.read(authControllerProvider).busy ||
        !form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final success = await ref
        .read(authControllerProvider.notifier)
        .login(email.text, password.text);
    if (mounted && success) password.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(authControllerProvider);
    return AuthPage(
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
      child: AutofillGroup(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('login.email'),
                controller: email,
                enabled: !state.busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: InputDecoration(labelText: l10n.emailLabel),
                validator:
                    (value) =>
                        AuthValidation.email(value ?? '')
                            ? null
                            : l10n.emailInvalid,
              ),
              const SizedBox(height: AppSpace.lg),
              PasswordField(
                key: const Key('login.password'),
                controller: password,
                label: l10n.passwordLabel,
                enabled: !state.busy,
                autofillHints: const [AutofillHints.password],
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? l10n.requiredField
                            : value.length > 128
                            ? l10n.passwordPolicy
                            : null,
                onSubmitted: submit,
              ),
              if (state.issue != null)
                AuthNotice(authIssueText(l10n, state.issue!)),
              const SizedBox(height: AppSpace.xl),
              AuthSubmit(
                key: const Key('login.submit'),
                label: l10n.loginAction,
                busy: state.busy,
                onPressed: submit,
              ),
              const SizedBox(height: AppSpace.lg),
              TextButton(
                onPressed:
                    state.busy
                        ? null
                        : () {
                          ref
                              .read(authControllerProvider.notifier)
                              .clearIssue();
                          context.go('/register');
                        },
                child: Text(l10n.noAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
