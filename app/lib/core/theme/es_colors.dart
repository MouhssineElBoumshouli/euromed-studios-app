import 'package:flutter/material.dart';

/// Color roles for the "Studio Light" look (decision 0003).
///
/// Light, airy surfaces with soft lilac shapes, a deep Euromed navy for
/// actions and a bright blue for highlights. Screens never use raw hex
/// values: they read these roles with `context.es`, so light and dark
/// mode always stay correct.
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
    required this.accent,
    required this.lilac,
    required this.onLilac,
    required this.blob,
    required this.shadow,
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

  /// Page background.
  final Color bgApp;

  /// Cards and sheets.
  final Color bgSurface;

  /// Quiet fills: inputs, disabled slots, skeletons.
  final Color bgSubtle;

  /// Deep navy surfaces (QR ticket, hero overlays).
  final Color bgBrand;
  final Color bgBrandRaised;

  /// Main buttons and selected states.
  final Color actionPrimary;
  final Color onActionPrimary;

  /// Bright blue for highlighted words and live dots.
  final Color accent;

  /// Soft lilac behind selected tabs and icon tiles.
  final Color lilac;
  final Color onLilac;

  /// The large soft shapes behind content.
  final Color blob;

  /// Card shadow tint.
  final Color shadow;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color textOnBrand;
  final Color textOnBrandMuted;

  /// Euromed Studios gold. Small touches on navy only.
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

  static const light = EsColors(
    bgApp: Color(0xFFF6F7FD),
    bgSurface: Color(0xFFFFFFFF),
    bgSubtle: Color(0xFFEFF1F8),
    bgBrand: Color(0xFF141D52),
    bgBrandRaised: Color(0xFF1E2A6E),
    actionPrimary: Color(0xFF1C2B6B),
    onActionPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF2563EB),
    lilac: Color(0xFFE8E7FC),
    onLilac: Color(0xFF3F3AB8),
    blob: Color(0xFFE6E8FB),
    shadow: Color(0xFF1C2B6B),
    textPrimary: Color(0xFF0E1433),
    textSecondary: Color(0xFF5B6180),
    textDisabled: Color(0xFF9AA0B8),
    textOnBrand: Color(0xFFFFFFFF),
    textOnBrandMuted: Color(0xFFB9C0E0),
    brandAccent: Color(0xFFD9BC8C),
    textGold: Color(0xFF8A6A3A),
    textLink: Color(0xFF1C2B6B),
    border: Color(0xFFE3E6F2),
    borderStrong: Color(0xFFC5CADF),
    pendingBg: Color(0xFFFFF1D6),
    pendingText: Color(0xFF8A5300),
    reviewBg: Color(0xFFECEBFF),
    reviewText: Color(0xFF4338CA),
    successBg: Color(0xFFE2F6EA),
    successText: Color(0xFF0B7A3E),
    successFill: Color(0xFF0DB02B),
    dangerBg: Color(0xFFFDE8E8),
    dangerText: Color(0xFFB42318),
    neutralBg: Color(0xFFEEF0F6),
    neutralText: Color(0xFF5B6180),
  );

  static const dark = EsColors(
    bgApp: Color(0xFF0A0E24),
    bgSurface: Color(0xFF141A38),
    bgSubtle: Color(0xFF1C2347),
    bgBrand: Color(0xFF1A2462),
    bgBrandRaised: Color(0xFF1E2A6E),
    actionPrimary: Color(0xFF4B63E6),
    onActionPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF8FB0FF),
    lilac: Color(0xFF262C5E),
    onLilac: Color(0xFFC9C6FF),
    blob: Color(0xFF151B42),
    shadow: Color(0xFF000000),
    textPrimary: Color(0xFFF2F4FF),
    textSecondary: Color(0xFFA9B0CF),
    textDisabled: Color(0xFF6B7296),
    textOnBrand: Color(0xFFFFFFFF),
    textOnBrandMuted: Color(0xFFB9C0E0),
    brandAccent: Color(0xFFD9BC8C),
    textGold: Color(0xFFE3C98E),
    textLink: Color(0xFFAFC2FF),
    border: Color(0xFF262D52),
    borderStrong: Color(0xFF3A4270),
    pendingBg: Color(0xFF3A2E14),
    pendingText: Color(0xFFF5CF85),
    reviewBg: Color(0xFF26245A),
    reviewText: Color(0xFFC4C0FF),
    successBg: Color(0xFF0F3320),
    successText: Color(0xFF86E0A8),
    successFill: Color(0xFF0DB02B),
    dangerBg: Color(0xFF3D1210),
    dangerText: Color(0xFFF2A39B),
    neutralBg: Color(0xFF1C2347),
    neutralText: Color(0xFFA9B0CF),
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
      accent: l(accent, other.accent),
      lilac: l(lilac, other.lilac),
      onLilac: l(onLilac, other.onLilac),
      blob: l(blob, other.blob),
      shadow: l(shadow, other.shadow),
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
