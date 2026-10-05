import '../../../core/widgets/app_components.dart';
import '../../../core/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: pageAppBar(context, title: ''),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: AppSpace.page,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpace.formWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(subtitle, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: AppSpace.xxl),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.onSubmitted,
    this.enabled = true,
    this.action = TextInputAction.done,
    this.autofillHints,
  });
  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final VoidCallback? onSubmitted;
  final bool enabled;
  final TextInputAction action;
  final Iterable<String>? autofillHints;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: hidden,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.action,
      onFieldSubmitted: (_) {
        if (widget.action != TextInputAction.next) {
          widget.onSubmitted?.call();
        }
      },
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          onPressed:
              widget.enabled ? () => setState(() => hidden = !hidden) : null,
          tooltip: hidden ? l10n.showPassword : l10n.hidePassword,
          icon: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

class AuthNotice extends StatelessWidget {
  const AuthNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) =>
      AppMessage(message: message, error: true);
}

class AuthSubmit extends StatelessWidget {
  const AuthSubmit({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: SubmitContent(label: label, busy: busy),
  );
}
