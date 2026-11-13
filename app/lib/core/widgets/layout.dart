import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/es_colors.dart';
import '../theme/es_text.dart';

/// A white card with a hairline border (Figma cards).
class EsCard extends StatelessWidget {
  const EsCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(EsSpace.s4),
    this.clip = false,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Material(
      color: c.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EsRadius.lg),
        side: BorderSide(color: c.border),
      ),
      clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Section title used between groups of content.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: EsSpace.s2, bottom: EsSpace.s1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: EsText.titleM.copyWith(color: context.es.textPrimary),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small gold capitals above a group ("PRODUCTION").
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.onBrand = false});
  final String text;
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Text(
      text.toUpperCase(),
      style: EsText.overline.copyWith(
        color: onBrand ? c.brandAccent : c.textGold,
      ),
    );
  }
}

enum BannerTone { info, warning, danger, success }

/// A tinted message box with an icon.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.tone = BannerTone.info,
    this.icon,
  });
  final String text;
  final BannerTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (Color bg, Color fg, IconData ic) = switch (tone) {
      BannerTone.info => (c.reviewBg, c.reviewText, Icons.info_outline_rounded),
      BannerTone.warning => (
          c.pendingBg,
          c.pendingText,
          Icons.schedule_rounded
        ),
      BannerTone.danger => (
          c.dangerBg,
          c.dangerText,
          Icons.error_outline_rounded
        ),
      BannerTone.success => (
          c.successBg,
          c.successText,
          Icons.check_circle_outline_rounded,
        ),
    };
    return Container(
      padding: const EdgeInsets.all(EsSpace.s3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(EsRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? ic, size: 20, color: fg),
          const SizedBox(width: EsSpace.s3),
          Expanded(
            child: Text(text, style: EsText.bodyS.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }
}

/// Initials in a circle.
class Avatar extends StatelessWidget {
  const Avatar(this.initials,
      {super.key, this.size = 40, this.onBrand = false});
  final String initials;
  final double size;
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onBrand ? c.bgBrandRaised : c.bgSubtle,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: EsText.labelM.copyWith(
          color: onBrand ? c.brandAccent : c.textPrimary,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

/// The navy header with the faint zellige pattern (Figma "TopBar / Brand").
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.title,
    this.overline = 'Euromed Studios · UEMF',
    this.subtitle,
    this.trailing,
    this.bottomPadding = EsSpace.s6,
  });
  final String title;
  final String overline;
  final String? subtitle;
  final Widget? trailing;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      color: c.bgBrand,
      child: CustomPaint(
        painter: ZelligePainter(color: c.brandAccent),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            EsSpace.s5,
            top + EsSpace.s5,
            EsSpace.s5,
            bottomPadding,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Overline(overline, onBrand: true),
                    const SizedBox(height: EsSpace.s2),
                    Text(
                      title.toUpperCase(),
                      style: EsText.displayL.copyWith(color: c.textOnBrand),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: EsSpace.s1),
                      Text(
                        subtitle!,
                        style: EsText.bodyM.copyWith(color: c.textOnBrandMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Faint 8-point stars inspired by Fès zellige.
class ZelligePainter extends CustomPainter {
  ZelligePainter({required this.color, this.opacity = 0.08});
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 40.0;
    const half = 9.0;
    for (var y = step / 2; y < size.height + step; y += step) {
      for (var x = step / 2; x < size.width + step; x += step) {
        final r = Rect.fromCenter(
          center: Offset(x, y),
          width: half * 2,
          height: half * 2,
        );
        canvas.drawRect(r, p);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: half * 2, height: half * 2),
          p,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(ZelligePainter old) =>
      old.color != color || old.opacity != opacity;
}

/// Shown when a list has nothing in it: an invitation, not an apology.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: EsSpace.s6,
        vertical: EsSpace.s10,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration:
                BoxDecoration(color: c.bgSubtle, shape: BoxShape.circle),
            child: Icon(icon, color: c.textSecondary, size: 28),
          ),
          const SizedBox(height: EsSpace.s4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: EsText.titleM.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: EsSpace.s2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: EsText.bodyM.copyWith(color: c.textSecondary),
          ),
          if (action != null) ...[const SizedBox(height: EsSpace.s5), action!],
        ],
      ),
    );
  }
}
