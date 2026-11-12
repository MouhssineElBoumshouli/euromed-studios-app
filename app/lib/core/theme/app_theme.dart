import 'package:flutter/material.dart';

import 'es_colors.dart';
import 'es_text.dart';

/// Builds the Material theme from our brand tokens.
abstract final class AppTheme {
  static ThemeData light() => _build(EsColors.light, Brightness.light);
  static ThemeData dark() => _build(EsColors.dark, Brightness.dark);

  static ThemeData _build(EsColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.actionPrimary,
      onPrimary: c.onActionPrimary,
      secondary: c.brandAccent,
      onSecondary: c.bgBrand,
      error: c.dangerText,
      onError: c.onActionPrimary,
      surface: c.bgSurface,
      onSurface: c.textPrimary,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: 'Montserrat',
      scaffoldBackgroundColor: c.bgApp,
      extensions: [c],
      textTheme: TextTheme(
        displayLarge: EsText.displayXL.copyWith(color: c.textPrimary),
        headlineMedium: EsText.displayL.copyWith(color: c.textPrimary),
        titleLarge: EsText.titleL.copyWith(color: c.textPrimary),
        titleMedium: EsText.titleM.copyWith(color: c.textPrimary),
        titleSmall: EsText.titleS.copyWith(color: c.textPrimary),
        bodyLarge: EsText.bodyL.copyWith(color: c.textPrimary),
        bodyMedium: EsText.bodyM.copyWith(color: c.textPrimary),
        bodySmall: EsText.bodyS.copyWith(color: c.textSecondary),
        labelLarge: EsText.labelM.copyWith(color: c.textPrimary),
        labelSmall: EsText.labelS.copyWith(color: c.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgApp,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: EsText.titleM.copyWith(color: c.textPrimary),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.bgSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.reviewBg,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => EsText.labelS.copyWith(
            color: s.contains(WidgetState.selected)
                ? c.actionPrimary
                : c.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected)
                ? c.actionPrimary
                : c.textSecondary,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bgSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(EsRadius.xl),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.bgSurface,
        hintStyle: EsText.bodyM.copyWith(color: c.textDisabled),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EsRadius.md),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EsRadius.md),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EsRadius.md),
          borderSide: BorderSide(color: c.actionPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EsRadius.md),
          borderSide: BorderSide(color: c.dangerText, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.bgBrand,
        contentTextStyle: EsText.bodyM.copyWith(color: c.textOnBrand),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
