import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/layout.dart';

/// Month calendar for picking a booking date (D0).
///
/// Each day shows at a glance whether it can be booked:
/// - white with a green dot: free hours left;
/// - grey with a red dot: bookable day but full;
/// - grey: closed, in the past, or beyond the booking window.
///
/// [freeByDay] holds the number of free hours for every bookable day.
/// A day missing from it is closed.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.selected,
    required this.freeByDay,
    required this.canGoBack,
    required this.canGoForward,
    required this.onMonth,
    required this.onDay,
  });

  /// First day of the month shown.
  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final Map<DateTime, int> freeByDay;
  final bool canGoBack;
  final bool canGoForward;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onDay;

  static const _letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const _weekdays = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
  ];

  void _shift(int by) => onMonth(DateTime(month.year, month.month + by));

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final lead = month.weekday - 1; // Monday first
    final count = DateUtils.getDaysInMonth(month.year, month.month);
    final rows = ((lead + count) / 7).ceil();

    return EsCard(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 16),
      child: GestureDetector(
        // Swipe left or right to change month.
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -250 && canGoForward) _shift(1);
          if (v > 250 && canGoBack) _shift(-1);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _NavButton(
                  icon: Icons.chevron_left_rounded,
                  label: 'Mois précédent',
                  onTap: canGoBack ? () => _shift(-1) : null,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: EsMotion.fast,
                    child: Text(
                      Fmt.month(month),
                      key: ValueKey(month),
                      textAlign: TextAlign.center,
                      style: EsText.titleL.copyWith(color: c.textPrimary),
                    ),
                  ),
                ),
                _NavButton(
                  icon: Icons.chevron_right_rounded,
                  label: 'Mois suivant',
                  onTap: canGoForward ? () => _shift(1) : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ExcludeSemantics(
              child: Row(
                children: [
                  for (final l in _letters)
                    Expanded(
                      child: Text(
                        l,
                        textAlign: TextAlign.center,
                        style: EsText.labelS.copyWith(color: c.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: EsMotion.medium,
              switchInCurve: EsMotion.curve,
              transitionBuilder: (child, a) =>
                  FadeTransition(opacity: a, child: child),
              child: Column(
                key: ValueKey(month),
                children: [
                  for (var r = 0; r < rows; r++)
                    Padding(
                      padding: EdgeInsets.only(top: r == 0 ? 0 : 3),
                      child: Row(
                        children: [
                          for (var col = 0; col < 7; col++) ...[
                            if (col > 0) const SizedBox(width: 3),
                            Expanded(child: _cell(r * 7 + col - lead + 1, count)),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ExcludeSemantics(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 6,
                children: [
                  _Legend(color: c.successText, label: 'Libre'),
                  _Legend(color: c.dangerText, label: 'Complet'),
                  _Legend(color: c.textDisabled, label: 'Fermé', hollow: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(int dayNumber, int count) {
    if (dayNumber < 1 || dayNumber > count) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox());
    }
    final d = DateTime(month.year, month.month, dayNumber);
    final free = freeByDay[d];
    return _DayCell(
      day: d,
      free: free,
      isToday: d == today,
      isSelected: d == selected,
      semanticLabel: '${_weekdays[d.weekday - 1]} ${Fmt.dayMonthYear(d)}, '
          '${free == null ? 'fermé' : free == 0 ? 'complet' : '$free '
              'créneau${free > 1 ? 'x' : ''} libre${free > 1 ? 's' : ''}'}',
      onTap: free != null && free > 0 ? () => onDay(d) : null,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.free,
    required this.isToday,
    required this.isSelected,
    required this.semanticLabel,
    required this.onTap,
  });
  final DateTime day;

  /// Free hours that day, or null when closed / out of the window.
  final int? free;
  final bool isToday;
  final bool isSelected;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final open = onTap != null;
    final full = free == 0;
    final bg = isSelected
        ? c.actionPrimary
        : open
            ? c.bgSurface
            : c.bgSubtle;
    final fg = isSelected
        ? c.onActionPrimary
        : open
            ? c.textPrimary
            : c.textDisabled;
    final Color? dot = isSelected
        ? c.onActionPrimary
        : open
            ? c.successText
            : full
                ? c.dangerText
                : null;

    return Semantics(
      button: open,
      selected: isSelected,
      enabled: open,
      label: semanticLabel,
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(EsRadius.md),
            child: AnimatedContainer(
              duration: EsMotion.medium,
              curve: EsMotion.curve,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(EsRadius.md),
                border: Border.all(
                  color: isToday && !isSelected
                      ? c.accent
                      : open && !isSelected
                          ? c.border
                          : Colors.transparent,
                  width: isToday && !isSelected ? 1.6 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: c.shadow.withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: EsText.titleM.copyWith(
                      color: fg,
                      fontWeight: isSelected || isToday
                          ? FontWeight.w800
                          : FontWeight.w600,
                      decoration: full ? TextDecoration.lineThrough : null,
                      decorationColor: c.textDisabled,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: dot ?? Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        backgroundColor: onTap == null ? Colors.transparent : c.bgSubtle,
      ),
      icon: Icon(
        icon,
        color: onTap == null ? c.textDisabled : c.textPrimary,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.hollow = false});
  final Color color;
  final String label;
  final bool hollow;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: hollow ? 12 : 7,
          height: hollow ? 12 : 7,
          decoration: hollow
              ? BoxDecoration(
                  color: c.bgSubtle,
                  borderRadius: BorderRadius.circular(3),
                )
              : BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: EsText.bodyS.copyWith(color: c.textSecondary)),
      ],
    );
  }
}
