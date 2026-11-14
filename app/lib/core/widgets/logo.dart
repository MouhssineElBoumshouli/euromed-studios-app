import 'package:flutter/material.dart';

/// Euromed Studios logo, drawn as vectors so it stays sharp at any size
/// (traced from the logo provided by the team, decision 0006).
///
/// The mark is a shield (white half + two gold leaves) under a sound
/// equaliser. On light backgrounds the white parts turn navy.
class EuromedStudiosLogo extends StatelessWidget {
  const EuromedStudiosLogo({
    super.key,
    this.height = 40,
    this.onDark = true,
    this.wordmark = true,
  });

  /// Height of the whole logo.
  final double height;
  final bool onDark;

  /// False shows the mark alone (small places, app icon).
  final bool wordmark;

  static const gold = Color(0xFFCCAB7C);
  static const navy = Color(0xFF1C2B6B);

  @override
  Widget build(BuildContext context) {
    final light = onDark ? Colors.white : navy;
    final mark = CustomPaint(
      size: Size(height * 0.64, height),
      painter: _MarkPainter(light: light, gold: gold),
    );
    final logo = !wordmark
        ? mark
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              mark,
              SizedBox(width: height * 0.18),
              Padding(
                padding: EdgeInsets.only(top: height * 0.25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Word('EUROMED', light, height),
                    SizedBox(height: height * 0.12),
                    _Word('STUDIOS', gold, height),
                  ],
                ),
              ),
            ],
          );
    return Semantics(
      label: 'Euromed Studios',
      image: true,
      excludeSemantics: true,
      child: logo,
    );
  }
}

class _Word extends StatelessWidget {
  const _Word(this.text, this.color, this.height);
  final String text;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: 'BarlowSemiCondensed',
          fontWeight: FontWeight.w700,
          fontSize: height * 0.41,
          height: 0.78,
          letterSpacing: height * 0.03,
          color: color,
        ),
      );
}

/// Drawn on a 64 × 100 grid (traced from the provided artwork).
class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.light, required this.gold});
  final Color light;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 100);
    final l = Paint()..color = light;
    final g = Paint()..color = gold;

    // Equaliser: 5 columns of bars, counted from the bottom row up.
    const cols = [0.0, 13.0, 27.0, 41.0, 54.0];
    const bars = [2, 4, 3, 2, 3];
    for (var i = 0; i < cols.length; i++) {
      for (var j = 0; j < bars[i]; j++) {
        canvas.drawRect(
          Rect.fromLTWH(cols[i], 17.5 - j * 6, 10, 3.6),
          l,
        );
      }
    }

    // Shield, left half: straight top, curved inner edge, round bottom.
    canvas.drawPath(
      Path()
        ..moveTo(0, 30)
        ..lineTo(35.5, 30)
        ..quadraticBezierTo(26.5, 38, 25.8, 52)
        ..lineTo(25.8, 98)
        ..quadraticBezierTo(7, 97.5, 0, 73)
        ..close(),
      l,
    );

    // Upper gold leaf.
    canvas.drawPath(
      Path()
        ..moveTo(63.5, 30.5)
        ..quadraticBezierTo(40, 33, 39, 64.5)
        ..quadraticBezierTo(47, 61, 63.5, 52)
        ..close(),
      g,
    );

    // Lower gold leaf, following the shield's round bottom-right.
    canvas.drawPath(
      Path()
        ..moveTo(63.5, 67)
        ..quadraticBezierTo(41, 72, 39, 98)
        ..quadraticBezierTo(63.5, 94, 63.5, 73)
        ..close(),
      g,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.light != light || old.gold != gold;
}
