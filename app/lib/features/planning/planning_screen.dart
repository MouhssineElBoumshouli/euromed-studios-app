import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell.dart';
import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/app_state.dart';
import '../../data/demo_world.dart';
import '../../domain/bookings.dart';
import '../../domain/people.dart';
import '../../domain/rules/approval.dart';
import '../../domain/rules/availability.dart';
import '../../domain/studios.dart';
import '../../data/directory.dart';
import '../../data/catalog.dart';
import '../../core/l10n/text.dart';

/// F1 · Planning: every studio on one day, hour by hour.
///
/// Rows are studios (grouped by the physical room they share), columns are
/// opening hours. Each booking is a block coloured by its status; tapping
/// it opens the decision (if it waits for you) or the booking.
class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningState();
}

class _PlanningState extends ConsumerState<PlanningScreen> {
  DateTime? _day;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final me = ref.watch(currentPersonProvider);
    final today = dateOnly(w.now);
    final day = _day ?? _firstOpen(today);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    final week = [for (var i = 0; i < 5; i++) monday.add(Duration(days: i))];
    // A studio closed to booking keeps its column while it still has
    // sessions: they are kept and staff must see them.
    final studios = [
      for (final s in Catalog.studios)
        if (s.bookable ||
            w.bookings.any((b) =>
                b.studioId == s.id &&
                (b.status.holdsSlot || b.status == BookingStatus.completed)))
          s,
    ];
    final dayBookings = [
      for (final b in w.bookings)
        if (_sameDay(b.start, day) &&
            (b.status.holdsSlot || b.status == BookingStatus.completed))
          b,
    ];
    final wide = isWide(context);

    void open(Booking b) {
      if (b.isPrivate) return;
      if (b.status.isPending && canDecide(me, b, people: Directory.people)) {
        context.push('/validations/${b.id}');
      } else {
        context.push('/bookings/${b.id}');
      }
    }

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        EsSpace.page,
        MediaQuery.paddingOf(context).top + EsSpace.s5,
        EsSpace.page,
        EsSpace.s3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planning',
                      style: EsText.displayXL.copyWith(color: c.textPrimary),
                    ),
                    Text(
                      Fmt.longDay(day),
                      style: EsText.bodyM.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: tr('Semaine précédente'),
                onPressed: () => setState(
                  () => _day = day.subtract(const Duration(days: 7)),
                ),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => setState(() => _day = _firstOpen(today)),
                child: const Text('Aujourd’hui'),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                tooltip: tr('Semaine suivante'),
                onPressed: () =>
                    setState(() => _day = day.add(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: EsSpace.s3),
          Row(
            children: [
              for (final d in week)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _DayTab(
                      day: d,
                      selected: _sameDay(d, day),
                      isToday: _sameDay(d, today),
                      count: w.bookings
                          .where(
                            (b) =>
                                _sameDay(b.start, d) &&
                                b.status.holdsSlot &&
                                !b.isPrivate,
                          )
                          .length,
                      pending: w.bookings
                          .where(
                            (b) =>
                                _sameDay(b.start, d) &&
                                b.status.isPending &&
                                !b.isPrivate,
                          )
                          .length,
                      onTap: () => setState(() => _day = d),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: EsSpace.s3),
          Row(
            children: [
              const Expanded(child: _Legend()),
              // Closures are planned by the studio manager or the admin.
              if (me.has(Role.admin) || me.has(Role.studioManager))
                TextButton.icon(
                  onPressed: () => context.push('/admin/studios'),
                  icon: const Icon(Icons.build_outlined, size: 18),
                  label: const Text('Fermetures'),
                ),
            ],
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: wide
              ? _Timeline(
                  day: day,
                  now: w.now,
                  studios: studios,
                  bookings: dayBookings,
                  maintenance: [
                    for (final m in w.maintenance)
                      if (_sameDay(m.start, day)) m,
                  ],
                  opening: w.policy.openingHour,
                  closing: w.policy.closingHour,
                  onOpen: open,
                )
              : _DayList(
                  studios: studios,
                  bookings: dayBookings,
                  now: w.now,
                  onOpen: open,
                ),
        ),
      ],
    );
  }

  DateTime _firstOpen(DateTime d) {
    var x = d;
    while (x.weekday > 5) {
      x = x.add(const Duration(days: 1));
    }
    return x;
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

(Color, Color) _blockColors(EsColors c, Booking b) {
  if (b.isPrivate) return (c.neutralBg, c.neutralText);
  return statusColors(c, b.status);
}

class _DayTab extends StatelessWidget {
  const _DayTab({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.count,
    required this.pending,
    required this.onTap,
  });
  final DateTime day;
  final bool selected;
  final bool isToday;
  final int count;
  final int pending;
  final VoidCallback onTap;

  static const _wd = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final fg = selected ? c.onActionPrimary : c.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: tr('${Fmt.longDay(day)}, $count réservations'),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EsRadius.md),
        child: AnimatedContainer(
          duration: EsMotion.fast,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? c.actionPrimary : c.bgSurface,
            borderRadius: BorderRadius.circular(EsRadius.md),
            border: Border.all(
              color: selected
                  ? c.actionPrimary
                  : isToday
                      ? c.accent
                      : c.border,
            ),
          ),
          child: Row(
            children: [
              Text(
                '${_wd[day.weekday - 1]} ${day.day}',
                style: EsText.titleS.copyWith(color: fg),
              ),
              const Spacer(),
              if (pending > 0)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: selected ? c.brandAccent : c.pendingText,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                '$count',
                style: EsText.labelS.copyWith(
                  color: selected ? fg : c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    Widget item(Color bg, Color fg, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: fg.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: EsText.bodyS.copyWith(color: c.textSecondary)),
          ],
        );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        item(c.successBg, c.successText, 'Validée'),
        item(c.reviewBg, c.reviewText, 'Attente studio'),
        item(c.pendingBg, c.pendingText, 'Attente entité'),
        item(c.neutralBg, c.neutralText, 'Terminée / autre'),
        item(c.dangerBg, c.dangerText, 'Maintenance'),
      ],
    );
  }
}

/// Computer view: studios × hours, with a red line for "now".
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.day,
    required this.now,
    required this.studios,
    required this.bookings,
    required this.maintenance,
    required this.opening,
    required this.closing,
    required this.onOpen,
  });
  final DateTime day;
  final DateTime now;
  final List<Studio> studios;
  final List<Booking> bookings;
  final List<MaintenanceBlock> maintenance;
  final int opening;
  final int closing;
  final ValueChanged<Booking> onOpen;

  static const _label = 190.0;
  static const _row = 64.0;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final hours = closing - opening;
    return Padding(
      padding: const EdgeInsets.fromLTRB(EsSpace.page, 0, EsSpace.page, 24),
      child: EsCard(
        padding: EdgeInsets.zero,
        child: LayoutBuilder(
          builder: (context, box) {
            final hourW = (box.maxWidth - _label) / (hours <= 0 ? 1 : hours);
            double x(DateTime t) =>
                _label +
                ((t.hour + t.minute / 60) - opening).clamp(0, hours) * hourW;
            final showNow = _sameDay(now, day) &&
                now.hour >= opening &&
                now.hour < closing;
            return SingleChildScrollView(
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Hour header
                      SizedBox(
                        height: 40,
                        child: Row(
                          children: [
                            SizedBox(
                              width: _label,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Text(
                                  'Studio',
                                  style: EsText.labelS
                                      .copyWith(color: c.textSecondary),
                                ),
                              ),
                            ),
                            for (var h = opening; h < closing; h++)
                              SizedBox(
                                width: hourW,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Text(
                                    '${h.toString().padLeft(2, '0')}:00',
                                    style: EsText.labelS
                                        .copyWith(color: c.textSecondary),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      for (var i = 0; i < studios.length; i++)
                        _TimelineRow(
                          studio: studios[i],
                          shade: i.isOdd,
                          height: _row,
                          labelWidth: _label,
                          hourWidth: hourW,
                          hours: hours,
                          blocks: [
                            for (final m in maintenance)
                              if (m.roomId == studios[i].roomId &&
                                  x(m.end) - x(m.start) > 8)
                                Positioned(
                                  left: x(m.start) + 2,
                                  width: (x(m.end) - x(m.start) - 4).clamp(0, double.infinity),
                                  top: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    alignment: Alignment.centerLeft,
                                    decoration: BoxDecoration(
                                      color: c.dangerBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Maintenance · ${m.reason}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: EsText.labelS
                                          .copyWith(color: c.dangerText),
                                    ),
                                  ),
                                ),
                            for (final b in bookings)
                              if (_inRow(b, studios[i]) &&
                                  x(b.end) - x(b.start) > 8)
                                Positioned(
                                  left: x(b.start) + 2,
                                  width: (x(b.end) - x(b.start) - 4).clamp(0, double.infinity),
                                  top: 6,
                                  bottom: 6,
                                  child: _Block(
                                    booking: b,
                                    shared: b.studioId != studios[i].id,
                                    onTap: () => onOpen(b),
                                  ),
                                ),
                          ],
                        ),
                    ],
                  ),
                  if (showNow)
                    Positioned(
                      left: x(now),
                      top: 34,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: c.dangerText,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Container(width: 2, color: c.dangerText),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// A booking appears on its own studio's row. A booking of another
  /// studio in the same room shows faded, because it blocks this one too.
  bool _inRow(Booking b, Studio s) {
    if (b.studioId == s.id) return true;
    final other =
        Catalog.studios.where((x) => x.id == b.studioId).firstOrNull;
    return other?.roomId == s.roomId && b.status.holdsSlot;
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.studio,
    required this.shade,
    required this.height,
    required this.labelWidth,
    required this.hourWidth,
    required this.hours,
    required this.blocks,
  });
  final Studio studio;
  final bool shade;
  final double height;
  final double labelWidth;
  final double hourWidth;
  final int hours;
  final List<Widget> blocks;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final room = DemoWorld.rooms.firstWhere((r) => r.id == studio.roomId);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: shade ? c.bgSubtle.withValues(alpha: 0.5) : null,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              SizedBox(
                width: labelWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      PhotoThumb(studio.photo, size: 36, radius: 10),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studio.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  EsText.titleS.copyWith(color: c.textPrimary),
                            ),
                            Text(
                              room.name,
                              style: EsText.bodyS
                                  .copyWith(color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (var h = 0; h < hours; h++)
                Container(
                  width: hourWidth,
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: c.border)),
                  ),
                ),
            ],
          ),
          ...blocks,
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.booking,
    required this.shared,
    required this.onTap,
  });
  final Booking booking;
  final bool shared;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final b = booking;
    final (bg, fg) = _blockColors(c, b);
    final who = b.isPrivate ? 'Réservé' : personById(b.requesterId).displayName;
    final label = shared
        ? '${studioById(b.studioId).name} (salle partagée)'
        : '$who · ${b.activity.label}';
    return Tooltip(
      message: tr(b.isPrivate
          ? 'Créneau réservé'
          : '${studioById(b.studioId).name} · ${Fmt.range(b.start, b.end)}\n'
              '$who · ${b.status.label}'),
      child: Opacity(
        opacity: shared ? 0.45 : 1,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: shared || b.isPrivate ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: fg, width: 3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EsText.labelS.copyWith(color: fg),
                  ),
                  Text(
                    Fmt.range(b.start, b.end),
                    maxLines: 1,
                    style: EsText.bodyS.copyWith(color: fg, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Phone view: the same day as a list, studio by studio.
class _DayList extends StatelessWidget {
  const _DayList({
    required this.studios,
    required this.bookings,
    required this.now,
    required this.onOpen,
  });
  final List<Studio> studios;
  final List<Booking> bookings;
  final DateTime now;
  final ValueChanged<Booking> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final sorted = [...bookings]..sort((a, b) => a.start.compareTo(b.start));
    if (sorted.isEmpty) {
      return ListView(
        padding: EdgeInsets.only(bottom: tabBarSpace(context)),
        children: const [
          EmptyState(
            icon: Icons.event_available_outlined,
            title: 'Journée libre',
            message: 'Aucune réservation ce jour-là.',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        EsSpace.page,
        EsSpace.s2,
        EsSpace.page,
        tabBarSpace(context),
      ),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final b = sorted[i];
        final s = studioById(b.studioId);
        final (bg, fg) = _blockColors(c, b);
        return EsCard(
          padding: const EdgeInsets.all(12),
          onTap: b.isPrivate ? null : () => onOpen(b),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: fg,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 54,
                child: Text(
                  '${Fmt.time(b.start)}\n${Fmt.time(b.end)}',
                  style: EsText.numeric.copyWith(
                    color: c.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: EsText.titleS.copyWith(color: c.textPrimary),
                    ),
                    Text(
                      b.isPrivate
                          ? 'Réservé'
                          : '${personById(b.requesterId).displayName} · '
                              '${b.activity.label}',
                      style: EsText.bodyS.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Tag(
                label: b.isPrivate ? 'Réservé' : b.status.label,
                background: bg,
                foreground: fg,
              ),
            ],
          ),
        );
      },
    );
  }
}
