import 'package:flutter/material.dart';

import '../../domain/bookings.dart';
import '../theme/es_colors.dart';
import '../theme/es_text.dart';

/// Booking status label (Figma "StatusChip").
///
/// The status is always written in words. Color is a second signal,
/// never the only one.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (Color bg, Color fg) = switch (status) {
      BookingStatus.pendingEntity => (c.pendingBg, c.pendingText),
      BookingStatus.pendingStudio => (c.reviewBg, c.reviewText),
      BookingStatus.approved => (c.successBg, c.successText),
      BookingStatus.refused => (c.dangerBg, c.dangerText),
      BookingStatus.cancelled ||
      BookingStatus.completed =>
        (c.neutralBg, c.neutralText),
    };
    return Tag(label: status.label, background: bg, foreground: fg, dot: true);
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(label, style: EsText.labelS.copyWith(color: foreground)),
        ],
      ),
    );
  }
}
