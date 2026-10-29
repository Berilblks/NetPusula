import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/compass_mark.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';

/// One brand header for sign-in, registration and preparation onboarding.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key, this.showSlogan = true});
  final bool showSlogan;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        CompassMark(size: 68, onDark: theme.brightness == Brightness.dark),
        const SizedBox(height: 8),
        Text(
          AppBrand.name,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineLarge,
        ),
        if (showSlogan) ...[
          const SizedBox(height: 4),
          Text(
            AppBrand.slogan,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class PremiumAuthPage extends StatelessWidget {
  const PremiumAuthPage({
    required this.title,
    required this.child,
    this.subtitle,
    this.onboarding = false,
    super.key,
  });
  final String title;
  final String? subtitle;
  final bool onboarding;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            gradient:
                onboarding
                    ? RadialGradient(
                      center: Alignment.topRight,
                      radius: 1.1,
                      colors: [
                        BrandColors.lavender.withValues(
                          alpha: dark ? .12 : .14,
                        ),
                        theme.scaffoldBackgroundColor,
                      ],
                    )
                    : null,
          ),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!onboarding)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip:
                                MaterialLocalizations.of(
                                  context,
                                ).backButtonTooltip,
                            onPressed: () => context.go('/welcome'),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        )
                      else
                        const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AuthBrandHeader(showSlogan: !onboarding),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                subtitle!,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Theme(
                              data: theme.copyWith(
                                inputDecorationTheme: theme.inputDecorationTheme
                                    .copyWith(
                                      filled: true,
                                      fillColor:
                                          dark
                                              ? theme
                                                  .colorScheme
                                                  .surfaceContainerLow
                                              : BrandColors.background,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color:
                                              theme.colorScheme.outlineVariant,
                                        ),
                                      ),
                                    ),
                              ),
                              child: child,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumAuthSubmit extends StatelessWidget {
  const PremiumAuthSubmit({
    required this.label,
    required this.busy,
    required this.onPressed,
    super.key,
  });
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [BrandColors.purple, BrandColors.headerEnd],
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: BrandColors.surface,
        disabledForegroundColor: BrandColors.surface,
        shadowColor: Colors.transparent,
      ),
      onPressed: busy ? null : onPressed,
      child: SubmitContent(label: label, busy: busy),
    ),
  );
}

class GoogleAuthButton extends ConsumerWidget {
  const GoogleAuthButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final busy = ref.watch(authControllerProvider.select((s) => s.busy));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(l.authOr),
              ),
              const Expanded(child: Divider()),
            ],
          ),
        ),
        OutlinedButton(
          key: const Key('auth.google'),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1F1F1F),
            side: const BorderSide(color: Color(0xFF747775)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed:
              busy
                  ? null
                  : () {
                    FocusScope.of(context).unfocus();
                    ref.read(authControllerProvider.notifier).google();
                  },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/auth/google-g.png',
                width: 20,
                height: 20,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(l.googleContinue, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
