import 'package:flutter/material.dart';

/// Text styles for the "Studio Light" look (decision 0003).
///
/// Headings use Plus Jakarta Sans, bold and tight, in sentence case.
/// Everything else uses DM Sans, which stays readable at small sizes.
abstract final class EsText {
  static const _h = 'Jakarta';
  static const _b = 'DMSans';

  /// Hero headline on Home ("Vos idées prennent vie en studio.").
  static const hero = TextStyle(
    fontFamily: _h,
    fontWeight: FontWeight.w800,
    fontSize: 36,
    height: 40 / 36,
    letterSpacing: -1.1,
  );
  static const displayXL = TextStyle(
    fontFamily: _h,
    fontWeight: FontWeight.w800,
    fontSize: 30,
    height: 36 / 30,
    letterSpacing: -0.8,
  );
  static const displayL = TextStyle(
    fontFamily: _h,
    fontWeight: FontWeight.w800,
    fontSize: 26,
    height: 32 / 26,
    letterSpacing: -0.6,
  );
  static const displayM = TextStyle(
    fontFamily: _h,
    fontWeight: FontWeight.w700,
    fontSize: 21,
    height: 26 / 21,
    letterSpacing: -0.3,
  );
  static const titleL = TextStyle(
    fontFamily: _h,
    fontWeight: FontWeight.w700,
    fontSize: 19,
    height: 26 / 19,
    letterSpacing: -0.2,
  );
  static const titleM = TextStyle(
    fontFamily: _h,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 22 / 16,
    letterSpacing: -0.1,
  );
  static const titleS = TextStyle(
    fontFamily: _h,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    height: 20 / 14,
  );
  static const bodyL = TextStyle(
    fontFamily: _b,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 24 / 16,
  );
  static const bodyM = TextStyle(
    fontFamily: _b,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 20 / 14,
  );
  static const bodyS = TextStyle(
    fontFamily: _b,
    fontWeight: FontWeight.w400,
    fontSize: 12.5,
    height: 17 / 12.5,
  );
  static const labelM = TextStyle(
    fontFamily: _b,
    fontWeight: FontWeight.w600,
    fontSize: 14.5,
    height: 20 / 14.5,
  );
  static const labelS = TextStyle(
    fontFamily: _b,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    height: 16 / 12,
  );
  static const overline = TextStyle(
    fontFamily: _b,
    fontWeight: FontWeight.w700,
    fontSize: 11,
    height: 14 / 11,
    letterSpacing: 1.1,
  );

  /// Times and counts that line up in columns.
  static const numeric = TextStyle(
    fontFamily: _h,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    height: 20 / 15,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Spacing steps.
abstract final class EsSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;

  /// Side margin of every screen.
  static const page = 20.0;
}

abstract final class EsRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

/// Durations and curves, so motion feels the same everywhere.
abstract final class EsMotion {
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
}
