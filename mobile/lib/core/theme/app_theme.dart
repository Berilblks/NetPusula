import 'package:flutter/material.dart';
import 'design_tokens.dart';

abstract final class AppTheme {
  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);
  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(
      seedColor: BrandColors.purple,
      brightness: brightness,
    ).copyWith(
      primary: dark ? BrandColors.lavender : BrandColors.purple,
      onPrimary: dark ? BrandColors.navy : BrandColors.surface,
      surface: dark ? BrandColors.darkSurface : BrandColors.surface,
      surfaceContainerLowest:
          dark ? BrandColors.darkSurface : BrandColors.surface,
      onSurface: dark ? BrandColors.darkText : BrandColors.navy,
      onSurfaceVariant:
          dark ? BrandColors.darkSecondary : BrandColors.readableSecondary,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      brightness: brightness,
    );
    final text = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge!.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -.5,
      ),
      headlineMedium: base.textTheme.headlineMedium!.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -.3,
      ),
      headlineSmall: base.textTheme.headlineSmall!.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displaySmall: base.textTheme.displaySmall!.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      titleLarge: base.textTheme.titleLarge!.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.textTheme.bodyLarge!.copyWith(height: 1.45),
      bodyMedium: base.textTheme.bodyMedium!.copyWith(height: 1.4),
      bodySmall: base.textTheme.bodySmall!.copyWith(
        color: colors.onSurfaceVariant,
        height: 1.4,
      ),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
      borderSide: BorderSide(color: colors.outline),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor:
          dark ? BrandColors.darkBackground : BrandColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor:
            dark ? BrandColors.darkBackground : BrandColors.background,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        color: colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.all(AppSpace.lg),
        errorMaxLines: 4,
        helperMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: buttonShape,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xl,
            vertical: AppSpace.lg,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: buttonShape,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xl,
            vertical: AppSpace.lg,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: buttonShape,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.md,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      chipTheme: base.chipTheme.copyWith(
        showCheckmark: true,
        selectedColor: colors.secondaryContainer,
        padding: const EdgeInsets.all(AppSpace.sm),
        labelStyle: text.labelLarge,
        shape: buttonShape,
        side: BorderSide(color: colors.outlineVariant),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        space: AppSpace.xl,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
        linearMinHeight: 6,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: buttonShape,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.sm,
        ),
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
  }
}
