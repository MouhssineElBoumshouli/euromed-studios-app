import 'package:flutter/material.dart';

import '../theme/es_colors.dart';
import '../theme/es_text.dart';

enum EsButtonStyle { primary, secondary, ghost, destructive }

enum EsButtonSize { large, medium }

/// The app's button (Figma component "Button").
///
/// Use at most one primary button per screen.
class EsButton extends StatelessWidget {
  const EsButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.style = EsButtonStyle.primary,
    this.size = EsButtonSize.large,
    this.icon,
    this.expand = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final EsButtonStyle style;
  final EsButtonSize size;
  final IconData? icon;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (Color bg, Color fg, Color? border) = switch (style) {
      EsButtonStyle.primary => (c.actionPrimary, c.onActionPrimary, null),
      EsButtonStyle.secondary => (c.bgSurface, c.textPrimary, c.borderStrong),
      EsButtonStyle.ghost => (Colors.transparent, c.textLink, null),
      EsButtonStyle.destructive => (c.dangerBg, c.dangerText, null),
    };
    final enabled = onPressed != null && !loading;
    final height = size == EsButtonSize.large ? 52.0 : 44.0;
    final text = size == EsButtonSize.large ? EsText.labelM : EsText.labelS;

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: 20, color: fg),
        if (loading || icon != null) const SizedBox(width: EsSpace.s2),
        Flexible(
          child: Text(
            label,
            style: text.copyWith(color: fg),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled || loading ? 1 : 0.45,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EsRadius.md),
            side: border == null ? BorderSide.none : BorderSide(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Container(
              height: height,
              padding: EdgeInsets.symmetric(
                horizontal: size == EsButtonSize.large ? 24 : 16,
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
