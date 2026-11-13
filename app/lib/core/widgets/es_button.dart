import 'package:flutter/material.dart';

import '../theme/es_colors.dart';
import '../theme/es_text.dart';

enum EsButtonStyle { primary, secondary, ghost, destructive }

enum EsButtonSize { large, medium }

/// The app's pill button.
///
/// Use at most one primary button per screen. It shrinks slightly while
/// pressed so a tap always feels answered.
class EsButton extends StatefulWidget {
  const EsButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.style = EsButtonStyle.primary,
    this.size = EsButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.expand = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final EsButtonStyle style;
  final EsButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool expand;
  final bool loading;

  @override
  State<EsButton> createState() => _EsButtonState();
}

class _EsButtonState extends State<EsButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (Color bg, Color fg, Color? border) = switch (widget.style) {
      EsButtonStyle.primary => (c.actionPrimary, c.onActionPrimary, null),
      EsButtonStyle.secondary => (c.bgSurface, c.textPrimary, c.borderStrong),
      EsButtonStyle.ghost => (Colors.transparent, c.textLink, null),
      EsButtonStyle.destructive => (c.dangerBg, c.dangerText, null),
    };
    final enabled = widget.onPressed != null && !widget.loading;
    final large = widget.size == EsButtonSize.large;
    final height = large ? 54.0 : 44.0;
    final text = large ? EsText.labelM : EsText.labelS.copyWith(fontSize: 13.5);

    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: 19, color: fg),
        if (widget.loading || widget.icon != null)
          const SizedBox(width: EsSpace.s2),
        Flexible(
          child: Text(
            widget.label,
            style: text.copyWith(color: fg),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.trailingIcon != null && !widget.loading) ...[
          const SizedBox(width: EsSpace.s2),
          Icon(widget.trailingIcon, size: 18, color: fg),
        ],
      ],
    );

    final primary = widget.style == EsButtonStyle.primary && enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: EsMotion.fast,
        curve: EsMotion.curve,
        child: AnimatedOpacity(
          duration: EsMotion.fast,
          opacity: enabled || widget.loading ? 1 : 0.42,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(EsRadius.pill),
              boxShadow: primary
                  ? [
                      BoxShadow(
                        color: c.shadow.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: bg,
              shape: StadiumBorder(
                side: border == null
                    ? BorderSide.none
                    : BorderSide(color: border, width: 1.2),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? widget.onPressed : null,
                onHighlightChanged: (v) => setState(() => _down = v),
                child: Container(
                  height: height,
                  padding: EdgeInsets.symmetric(horizontal: large ? 26 : 18),
                  alignment: Alignment.center,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round outlined back button with an optional "Retour" label.
class EsBackButton extends StatelessWidget {
  const EsBackButton({
    super.key,
    required this.onPressed,
    this.label = 'Retour',
    this.close = false,
    this.onDark = false,
  });
  final VoidCallback onPressed;
  final String? label;
  final bool close;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final fg = onDark ? c.textOnBrand : c.textPrimary;
    return Semantics(
      button: true,
      label: close ? 'Fermer' : 'Retour',
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(EsRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: onDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : c.bgSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: onDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : c.border,
                  ),
                ),
                child: Icon(
                  close
                      ? Icons.close_rounded
                      : Icons.arrow_back_ios_new_rounded,
                  size: close ? 20 : 16,
                  color: fg,
                ),
              ),
              if (label != null) ...[
                const SizedBox(width: 10),
                Text(label!, style: EsText.labelM.copyWith(color: fg)),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
