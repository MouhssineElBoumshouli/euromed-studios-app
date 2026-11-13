import 'package:flutter/material.dart';

/// Text styles, one-to-one with the Figma text styles.
///
/// Display styles use Barlow Condensed in capitals, like the
/// Euromed Studios brochure. Everything else uses Montserrat, the free
/// match for UEMF's Gotham.
abstract final class EsText {
  static const _m = 'Montserrat';
  static const _b = 'BarlowCondensed';

  static const displayXL = TextStyle(
    fontFamily: _b,
    fontWeight: FontWeight.w600,
    fontSize: 34,
    height: 36 / 34,
  );
  static const displayL = TextStyle(
    fontFamily: _b,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 30 / 28,
  );
  static const displayM = TextStyle(
    fontFamily: _b,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 24 / 22,
    letterSpacing: 0.1,
  );
  static const titleL = TextStyle(
    fontFamily: _m,
    fontWeight: FontWeight.w600,
    fontSize: 20,
    height: 28 / 20,
  );
  static const titleM = TextStyle(
    fontFamily: _m,
    fontWeight: FontWeight.w600,
    fontSize: 17,
    height: 24 / 17,
  );
  static const titleS = TextStyle(
    fontFamily: _m,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 20 / 15,
  );
  static const bodyL = TextStyle(
    fontFamily: _m,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 24 / 16,
  );
  static const bodyM = TextStyle(
    fontFamily: _m,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 20 / 14,
  );
  static const bodyS = TextStyle(
    fontFamily: _m,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 16 / 12,
  );
  static const labelM = TextStyle(
    fontFamily: _m,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    height: 20 / 14,
  );
  static const labelS = TextStyle(
    fontFamily: _m,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 16 / 12,
  );
  static const overline = TextStyle(
    fontFamily: _m,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    height: 14 / 11,
    letterSpacing: 1.3,
  );
}

/// Spacing and corner rounding, one-to-one with Figma "Spacing & Radius".
abstract final class EsSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
}

abstract final class EsRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}
