import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../theme/es_colors.dart';
import '../theme/es_text.dart';
import '../../core/l10n/text.dart';

/// Soft shadow used under cards, so they float on the airy background.
List<BoxShadow> esShadow(EsColors c, {double strength = 1}) => [
      BoxShadow(
        color: c.shadow.withValues(alpha: 0.06 * strength),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: c.shadow.withValues(alpha: 0.04 * strength),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];

/// A white rounded card that floats on the page.
///
/// Tappable cards shrink a little while pressed.
class EsCard extends StatefulWidget {
  const EsCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(EsSpace.s4),
    this.clip = false,
    this.color,
    this.radius = EsRadius.lg,
    this.semanticLabel,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool clip;
  final Color? color;
  final double radius;
  final String? semanticLabel;

  @override
  State<EsCard> createState() => _EsCardState();
}

class _EsCardState extends State<EsCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(widget.radius);
    Widget body = Padding(padding: widget.padding, child: widget.child);
    if (widget.onTap != null) {
      body = InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (v) => setState(() => _down = v),
        borderRadius: radius,
        child: body,
      );
    }
    final card = AnimatedScale(
      scale: _down ? 0.985 : 1,
      duration: EsMotion.fast,
      curve: EsMotion.curve,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: dark ? null : esShadow(c),
        ),
        child: Material(
          color: widget.color ?? c.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: dark ? BorderSide(color: c.border) : BorderSide.none,
          ),
          clipBehavior:
              widget.clip || widget.onTap != null ? Clip.antiAlias : Clip.none,
          child: body,
        ),
      ),
    );
    if (widget.semanticLabel == null) return card;
    return Semantics(
      button: widget.onTap != null,
      label: tr(widget.semanticLabel),
      child: card,
    );
  }
}

/// Section title between groups, with an optional "Voir tout" style link.
class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.text, {
    super.key,
    this.trailing,
    this.actionLabel,
    this.onAction,
  });
  final String text;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Padding(
      padding: const EdgeInsets.only(top: EsSpace.s3, bottom: EsSpace.s1),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: EsText.titleL.copyWith(color: c.textPrimary),
              ),
            ),
          ),
          if (trailing != null) trailing!,
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: c.textLink,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 44),
              ),
              child: Text(actionLabel!, style: EsText.labelM),
            ),
        ],
      ),
    );
  }
}

/// Small capitals above a group ("ÉTAPE 2 SUR 4").
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.onBrand = false, this.color});
  final String text;
  final bool onBrand;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Text(
      text.toUpperCase(),
      style: EsText.overline.copyWith(
        color: color ?? (onBrand ? c.brandAccent : c.accent),
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
    this.title,
    this.action,
  });
  final String text;
  final String? title;
  final BannerTone tone;
  final IconData? icon;

  /// Optional button on the right (e.g. "Recharger").
  final Widget? action;

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
      padding: const EdgeInsets.all(EsSpace.s3 + 2),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: EsText.titleS.copyWith(color: fg)),
                  const SizedBox(height: 2),
                ],
                Text(text, style: EsText.bodyS.copyWith(color: fg)),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Initials in a soft circle.
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
        color: onBrand ? c.bgBrandRaised : c.lilac,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: EsText.titleS.copyWith(
          color: onBrand ? c.brandAccent : c.onLilac,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// A rounded lilac square with an icon (quick actions, list leading).
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 44, this.bg, this.fg});
  final IconData icon;
  final double size;
  final Color? bg;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? c.lilac,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.5, color: fg ?? c.onLilac),
    );
  }
}

/// A studio photo with rounded corners.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb(
    this.asset, {
    super.key,
    this.size = 64,
    this.width,
    this.height,
    this.radius = EsRadius.md,
  });
  final String asset;
  final double size;
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        asset,
        width: width ?? size,
        height: height ?? size,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (context, _, __) => Container(
          width: width ?? size,
          height: height ?? size,
          color: context.es.bgSubtle,
        ),
      ),
    );
  }
}

/// The large soft shapes behind content (from the original design).
class BlobBackground extends StatelessWidget {
  const BlobBackground({super.key, required this.child, this.variant = 0})
      : _page = false;

  /// The computer layout's content area: one set of shapes for the whole
  /// width. Screens inside it then skip their own (it would be cut at the
  /// edges of their centred column).
  const BlobBackground.page({super.key, required this.child})
      : variant = 0,
        _page = true;

  final Widget child;
  final int variant;
  final bool _page;

  @override
  Widget build(BuildContext context) {
    if (!_page && _BlobScope.of(context)) return child;
    final paint = CustomPaint(
      painter: _BlobPainter(context.es.blob, variant, wide: _page),
      child: child,
    );
    return _page ? _BlobScope(child: paint) : paint;
  }
}

class _BlobScope extends InheritedWidget {
  const _BlobScope({required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_BlobScope>() != null;

  @override
  bool updateShouldNotify(_BlobScope old) => false;
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.color, this.variant, {this.wide = false});
  final Color color;
  final int variant;
  final bool wide;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final w = size.width;
    if (wide) {
      // Same shapes, sized for a phone-like width, at the area's corners.
      final r = w.clamp(0.0, 820.0);
      canvas.drawCircle(Offset(w - r * 0.08, 230), r * 0.6, p);
      canvas.drawCircle(Offset(r * 0.12, 700), r * 0.48, p);
      return;
    }
    if (variant == 0) {
      canvas.drawCircle(Offset(w * 1.02, 250), w * 0.62, p);
      canvas.drawCircle(Offset(w * 0.05, 640), w * 0.5, p);
    } else {
      canvas.drawCircle(Offset(w * 0.95, 120), w * 0.45, p);
      canvas.drawCircle(Offset(-w * 0.1, 520), w * 0.4, p);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.color != color || old.variant != variant || old.wide != wide;
}

/// Page title block used at the top of tab screens.
///
/// Light and calm: a big bold title, an optional line under it and an
/// optional action on the right (avatar, add button…).
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.title,
    this.overline,
    this.subtitle,
    this.trailing,
    this.bottomPadding = EsSpace.s4,
  });
  final String title;
  final String? overline;
  final String? subtitle;
  final Widget? trailing;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        EsSpace.page,
        top + EsSpace.s6,
        EsSpace.page,
        bottomPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null) ...[
                  Overline(overline!),
                  const SizedBox(height: 6),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: EsText.displayXL.copyWith(color: c.textPrimary),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: EsText.bodyM.copyWith(color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Faint 8-point stars inspired by Fès zellige. Used sparingly on navy.
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
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset(x, y), width: half * 2, height: half * 2),
          p,
        );
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
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: c.lilac, shape: BoxShape.circle),
            child: Icon(icon, color: c.onLilac, size: 32),
          ),
          const SizedBox(height: EsSpace.s4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: EsText.titleL.copyWith(color: c.textPrimary),
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

/// Fades and lifts a child in, with a small delay per list position.
///
/// Gives lists a calm "settling" feel on first show. Turned off when the
/// system asks for reduced motion.
class FadeInUp extends StatefulWidget {
  const FadeInUp({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  State<FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<FadeInUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: EsMotion.slow);

  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Only the first screenful settles in. Later items, and everything
    // when the system asks for reduced motion, appear at once.
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce || widget.index > 6) {
      _a.value = 1;
    } else {
      _timer = Timer(Duration(milliseconds: 40 * widget.index), _a.forward);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return widget.child;
    }
    final t = CurvedAnimation(parent: _a, curve: EsMotion.curve);
    return FadeTransition(
      opacity: t,
      child: SlideTransition(
        position:
            Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(t),
        child: widget.child,
      ),
    );
  }
}

/// A detail page with a large photo on top and a rounded sheet that
/// slides up over it. The back button stays pinned while scrolling.
class PhotoPage extends StatelessWidget {
  const PhotoPage({
    super.key,
    required this.photo,
    required this.sheet,
    required this.onBack,
    this.height = 300,
    this.heroTag,
  });
  final String photo;
  final Widget sheet;
  final VoidCallback onBack;
  final double height;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    Widget image = Image.asset(
      photo,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
    );
    if (heroTag != null) image = Hero(tag: heroTag!, child: image);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: c.bgApp)),
          SingleChildScrollView(
            child: Stack(
              children: [
                image,
                Padding(
                  padding: EdgeInsets.only(top: height - 28),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: c.bgApp,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(EsRadius.xl),
                      ),
                    ),
                    child: sheet,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 16,
            child: _PinnedBack(onPressed: onBack),
          ),
        ],
      ),
    );
  }
}

class _PinnedBack extends StatelessWidget {
  const _PinnedBack({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Semantics(
      button: true,
      label: tr('Retour'),
      excludeSemantics: true,
      child: Material(
        color: c.bgSurface,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 17,
              color: c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
