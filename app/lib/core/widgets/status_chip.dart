import 'package:flutter/material.dart' hide Text;

import '../../domain/bookings.dart';
import '../theme/es_colors.dart';
import '../theme/es_text.dart';
import '../../core/l10n/text.dart';

/// Colors for a booking status: (background, text).
(Color, Color) statusColors(EsColors c, BookingStatus s) => switch (s) {
      BookingStatus.pendingEntity => (c.pendingBg, c.pendingText),
      BookingStatus.pendingStudio => (c.reviewBg, c.reviewText),
      BookingStatus.approved => (c.successBg, c.successText),
      BookingStatus.refused || BookingStatus.noShow => (c.dangerBg, c.dangerText),
      BookingStatus.cancelled ||
      BookingStatus.completed =>
        (c.neutralBg, c.neutralText),
    };

IconData statusIcon(BookingStatus s) => switch (s) {
      BookingStatus.pendingEntity => Icons.hourglass_top_rounded,
      BookingStatus.pendingStudio => Icons.hourglass_bottom_rounded,
      BookingStatus.approved => Icons.check_rounded,
      BookingStatus.refused => Icons.close_rounded,
      BookingStatus.cancelled => Icons.block_rounded,
      BookingStatus.completed => Icons.done_all_rounded,
      BookingStatus.noShow => Icons.person_off_outlined,
    };

/// Booking status label.
///
/// The status is always written in words, with an icon. Color is a
/// second signal, never the only one.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = statusColors(context.es, status);
    return Tag(
      label: status.label,
      background: bg,
      foreground: fg,
      icon: statusIcon(status),
    );
  }
}

/// A small rounded label.
class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.dot = false,
    this.icon,
  });
  final String label;
  final Color background;
  final Color foreground;
  final bool dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 4, 11, 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: EsText.labelS.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// A pulsing dot for things happening right now.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, required this.color, this.size = 8});
  final Color color;
  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect "reduce motion" (and keeps widget tests able to settle).
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _a.stop();
    } else if (!_a.isAnimating) {
      _a.repeat();
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final s = widget.size;
    return RepaintBoundary(
      child: SizedBox(
      width: s * 2.2,
      height: s * 2.2,
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            if (!reduce)
              Container(
                width: s + s * 1.2 * _a.value,
                height: s + s * 1.2 * _a.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.35 * (1 - _a.value)),
                ),
              ),
            Container(
              width: s,
              height: s,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
