import '../../../core/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import 'auth_text.dart';
import 'auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
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
        .register(name.text, email.text, password.text);
    if (mounted && success) {
      password.clear();
      confirmation.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(authControllerProvider);
    return AuthPage(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      child: AutofillGroup(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('register.name'),
                controller: name,
                enabled: !state.busy,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(labelText: l10n.nameLabel),
                validator:
                    (value) =>
                        AuthValidation.name(value ?? '')
                            ? null
                            : l10n.nameInvalid,
              ),
              const SizedBox(height: AppSpace.lg),
              TextFormField(
                key: const Key('register.email'),
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
                key: const Key('register.password'),
                controller: password,
                label: l10n.passwordLabel,
                action: TextInputAction.next,
                enabled: !state.busy,
                autofillHints: const [AutofillHints.newPassword],
                validator:
                    (value) =>
                        AuthValidation.password(value ?? '')
                            ? null
                            : l10n.passwordPolicy,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Text(
                  l10n.passwordHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              PasswordField(
                key: const Key('register.confirmation'),
                controller: confirmation,
                label: l10n.passwordConfirmation,
                enabled: !state.busy,
                onSubmitted: submit,
                autofillHints: const [AutofillHints.newPassword],
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? l10n.requiredField
                            : value != password.text
                            ? l10n.passwordMismatch
                            : null,
              ),
              if (state.issue != null)
                AuthNotice(authIssueText(l10n, state.issue!)),
              const SizedBox(height: AppSpace.xl),
              AuthSubmit(
                key: const Key('register.submit'),
                label: l10n.registerAction,
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
                          context.go('/login');
                        },
                child: Text(l10n.haveAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
