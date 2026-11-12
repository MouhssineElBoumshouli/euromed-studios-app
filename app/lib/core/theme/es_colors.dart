import 'package:flutter/material.dart';

/// Brand colors, one-to-one with the Figma "Color" variables
/// (see docs/decisions/0002-brand-system.md).
///
/// Screens never use raw hex values. They read these roles with
/// `context.es` so light and dark mode always stay correct.
@immutable
class EsColors extends ThemeExtension<EsColors> {
  const EsColors({
    required this.bgApp,
    required this.bgSurface,
    required this.bgSubtle,
    required this.bgBrand,
    required this.bgBrandRaised,
    required this.actionPrimary,
    required this.onActionPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.textOnBrand,
    required this.textOnBrandMuted,
    required this.brandAccent,
    required this.textGold,
    required this.textLink,
    required this.border,
    required this.borderStrong,
    required this.pendingBg,
    required this.pendingText,
    required this.reviewBg,
    required this.reviewText,
    required this.successBg,
    required this.successText,
    required this.successFill,
    required this.dangerBg,
    required this.dangerText,
    required this.neutralBg,
    required this.neutralText,
  });

  final Color bgApp;
  final Color bgSurface;
  final Color bgSubtle;
  final Color bgBrand;
  final Color bgBrandRaised;
  final Color actionPrimary;
  final Color onActionPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color textOnBrand;
  final Color textOnBrandMuted;

  /// Euromed Studios gold. Only on the navy brand surface.
  final Color brandAccent;

  /// Darker gold that passes contrast on light backgrounds.
  final Color textGold;
  final Color textLink;
  final Color border;
  final Color borderStrong;
  final Color pendingBg;
  final Color pendingText;
  final Color reviewBg;
  final Color reviewText;
  final Color successBg;
  final Color successText;

  /// Official UEMF green. Icons and fills only, never text.
  final Color successFill;
  final Color dangerBg;
  final Color dangerText;
  final Color neutralBg;
  final Color neutralText;

  // Primitives (Figma "Primitives" collection).
  static const _night900 = Color(0xFF070B1F);
  static const _night800 = Color(0xFF0A1230);
  static const _night700 = Color(0xFF111833);
  static const _night600 = Color(0xFF1A2142);
  static const _night500 = Color(0xFF263056);
  static const _studiosBlue = Color(0xFF1C2B6B);
  static const _gold500 = Color(0xFFB39467);
  static const _gold700 = Color(0xFF8A6A3A);
  static const _gold200 = Color(0xFFE3C98E);
  static const _uemfBlue700 = Color(0xFF003882);
  static const _uemfBlue400 = Color(0xFF3D7BD9);
  static const _uemfBlue200 = Color(0xFF9DBBEA);
  static const _uemfBlue100 = Color(0xFFE3EAF6);
  static const _uemfBlue900 = Color(0xFF13254A);
  static const _uemfGreen500 = Color(0xFF0DB02B);
  static const _uemfGreen700 = Color(0xFF0B7A23);
  static const _uemfGreen200 = Color(0xFF7FD48F);
  static const _uemfGreen100 = Color(0xFFE7F3E9);
  static const _uemfGreen900 = Color(0xFF0F3318);
  static const _white = Color(0xFFFFFFFF);
  static const _stone100 = Color(0xFFF5F1EA);
  static const _stone200 = Color(0xFFEDE6D8);
  static const _stone300 = Color(0xFFE4DDD0);
  static const _stone500 = Color(0xFF8A8270);
  static const _ink600 = Color(0xFF5A5F73);
  static const _ink300 = Color(0xFFAEB4CB);
  static const _amber100 = Color(0xFFF6EEDD);
  static const _amber700 = Color(0xFF6E5321);
  static const _amber900 = Color(0xFF3A2E14);
  static const _red100 = Color(0xFFFBE9E7);
  static const _red700 = Color(0xFFB42318);
  static const _red300 = Color(0xFFF2A39B);
  static const _red900 = Color(0xFF3D1210);

  static const light = EsColors(
    bgApp: _stone100,
    bgSurface: _white,
    bgSubtle: _stone200,
    bgBrand: _night800,
    bgBrandRaised: _studiosBlue,
    actionPrimary: _uemfBlue700,
    onActionPrimary: _white,
    textPrimary: _night800,
    textSecondary: _ink600,
    textDisabled: _stone500,
    textOnBrand: _stone100,
    textOnBrandMuted: _ink300,
    brandAccent: _gold500,
    textGold: _gold700,
    textLink: _uemfBlue700,
    border: _stone300,
    borderStrong: _stone500,
    pendingBg: _amber100,
    pendingText: _amber700,
    reviewBg: _uemfBlue100,
    reviewText: _uemfBlue700,
    successBg: _uemfGreen100,
    successText: _uemfGreen700,
    successFill: _uemfGreen500,
    dangerBg: _red100,
    dangerText: _red700,
    neutralBg: _stone200,
    neutralText: _ink600,
  );

  static const dark = EsColors(
    bgApp: _night900,
    bgSurface: _night700,
    bgSubtle: _night600,
    bgBrand: _night800,
    bgBrandRaised: _studiosBlue,
    actionPrimary: _uemfBlue400,
    onActionPrimary: _white,
    textPrimary: _stone100,
    textSecondary: _ink300,
    textDisabled: _stone500,
    textOnBrand: _stone100,
    textOnBrandMuted: _ink300,
    brandAccent: _gold500,
    textGold: _gold200,
    textLink: _uemfBlue200,
    border: _night500,
    borderStrong: _ink600,
    pendingBg: _amber900,
    pendingText: _gold200,
    reviewBg: _uemfBlue900,
    reviewText: _uemfBlue200,
    successBg: _uemfGreen900,
    successText: _uemfGreen200,
    successFill: _uemfGreen500,
    dangerBg: _red900,
    dangerText: _red300,
    neutralBg: _night600,
    neutralText: _ink300,
  );

  @override
  EsColors copyWith() => this;

  @override
  EsColors lerp(ThemeExtension<EsColors>? other, double t) {
    if (other is! EsColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return EsColors(
      bgApp: l(bgApp, other.bgApp),
      bgSurface: l(bgSurface, other.bgSurface),
      bgSubtle: l(bgSubtle, other.bgSubtle),
      bgBrand: l(bgBrand, other.bgBrand),
      bgBrandRaised: l(bgBrandRaised, other.bgBrandRaised),
      actionPrimary: l(actionPrimary, other.actionPrimary),
      onActionPrimary: l(onActionPrimary, other.onActionPrimary),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textDisabled: l(textDisabled, other.textDisabled),
      textOnBrand: l(textOnBrand, other.textOnBrand),
      textOnBrandMuted: l(textOnBrandMuted, other.textOnBrandMuted),
      brandAccent: l(brandAccent, other.brandAccent),
      textGold: l(textGold, other.textGold),
      textLink: l(textLink, other.textLink),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      pendingBg: l(pendingBg, other.pendingBg),
      pendingText: l(pendingText, other.pendingText),
      reviewBg: l(reviewBg, other.reviewBg),
      reviewText: l(reviewText, other.reviewText),
      successBg: l(successBg, other.successBg),
      successText: l(successText, other.successText),
      successFill: l(successFill, other.successFill),
      dangerBg: l(dangerBg, other.dangerBg),
      dangerText: l(dangerText, other.dangerText),
      neutralBg: l(neutralBg, other.neutralBg),
      neutralText: l(neutralText, other.neutralText),
    );
  }
}

extension EsColorsX on BuildContext {
  /// The app's color roles for the current light or dark mode.
  EsColors get es => Theme.of(this).extension<EsColors>()!;
}
