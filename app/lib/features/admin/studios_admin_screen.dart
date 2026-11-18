import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/admin_service.dart';
import '../../data/app_state.dart';
import '../../data/catalog.dart';
import '../../domain/bookings.dart';
import '../../domain/people.dart';
import '../../domain/studios.dart';
import 'admin_page.dart';
import '../../core/l10n/text.dart';

/// I4 · Studios open to booking, and maintenance closures per room.
/// The studio manager can plan closures; only the admin opens or closes
/// a studio to booking.
class StudiosAdminScreen extends ConsumerWidget {
  const StudiosAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final me = ref.watch(currentPersonProvider);
    final w = ref.watch(worldProvider);
    final isAdmin = me.has(Role.admin);
    final closures = [
      for (final m in w.maintenance)
        if (m.end.isAfter(w.now)) m,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final rooms = <String, List<Studio>>{};
    for (final s in Catalog.studios) {
      rooms.putIfAbsent(s.roomId, () => []).add(s);
    }

    return AdminPage(
      title: 'Studios et maintenance',
      subtitle: 'Ouvrir ou fermer un studio à la réservation, planifier '
          'les fermetures.',
      allow: const {Role.admin, Role.studioManager},
      children: [
        Row(
          children: [
            const Expanded(child: Overline('Fermetures à venir')),
            TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const _MaintenanceSheet(),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Planifier'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (closures.isEmpty)
          const InfoBanner(
            icon: Icons.build_outlined,
            title: 'Aucune fermeture prévue',
            text: 'Les créneaux concernés par une fermeture ne peuvent pas '
                'être réservés.',
          )
        else
          EsCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < closures.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 62, color: c.border),
                  _ClosureRow(block: closures[i], now: w.now),
                ],
              ],
            ),
          ),
        const SizedBox(height: EsSpace.s5),
        const Overline('Ouverture à la réservation'),
        const SizedBox(height: 4),
        Text(
          isAdmin
              ? 'Un studio fermé n’apparaît plus à la réservation. Les séances '
                  'déjà validées sont conservées.'
              : 'Seule l’administration peut ouvrir ou fermer un studio.',
          style: EsText.bodyS.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 8),
        EsCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final e in rooms.entries) ...[
                if (e.key != rooms.keys.first)
                  Divider(height: 1, color: c.border),
                for (final s in e.value)
                  _StudioRow(
                      studio: s, enabled: isAdmin, shared: e.value.length > 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StudioRow extends ConsumerStatefulWidget {
  const _StudioRow({
    required this.studio,
    required this.enabled,
    required this.shared,
  });
  final Studio studio;
  final bool enabled;
  final bool shared;

  @override
  ConsumerState<_StudioRow> createState() => _StudioRowState();
}

class _StudioRowState extends ConsumerState<_StudioRow> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final s = widget.studio;
    final title = Text(s.name, style: EsText.titleS);
    final status = Text(
      [
        s.bookable ? 'Ouvert à la réservation' : 'Fermé à la réservation',
        if (widget.shared) 'salle partagée',
      ].join(' · '),
      style: EsText.bodyS.copyWith(
        color: s.bookable ? c.successText : c.textSecondary,
      ),
    );
    final thumb = PhotoThumb(s.photo, size: 40, radius: 10);
    // The studio manager sees the state, without a switch he can't use.
    if (!widget.enabled) {
      return ListTile(leading: thumb, title: title, subtitle: status);
    }
    return SwitchListTile(
      secondary: thumb,
      title: title,
      subtitle: status,
      value: s.bookable,
      onChanged: busy ? null : (v) => _toggle(s, v),
    );
  }

  Future<void> _toggle(Studio s, bool v) async {
    if (!v) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Fermer ${s.name} à la réservation ?'),
          content: const Text(
            'Plus personne ne pourra le demander. Les séances déjà validées '
            'ou en attente sont conservées : traitez-les dans Validations.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => busy = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminServiceProvider).setStudioBookable(
            ref.read(currentPersonProvider),
            s.id,
            v,
          );
      m.showSnackBar(
        SnackBar(
          content:
              Text('${s.name} ${v ? 'ouvert' : 'fermé'} à la réservation.'),
        ),
      );
    } on AdminProblem catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _ClosureRow extends ConsumerWidget {
  const _ClosureRow({required this.block, required this.now});
  final MaintenanceBlock block;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final m = block;
    final ongoing = !m.start.isAfter(now);
    final sameDay = m.start.year == m.end.year &&
        m.start.month == m.end.month &&
        m.start.day == m.end.day;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      child: Row(
        children: [
          IconTile(
            Icons.build_outlined,
            size: 36,
            bg: ongoing ? c.dangerBg : c.pendingBg,
            fg: ongoing ? c.dangerText : c.pendingText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        roomName(m.roomId),
                        style: EsText.titleS.copyWith(color: c.textPrimary),
                      ),
                    ),
                    if (ongoing) ...[
                      const SizedBox(width: 8),
                      Tag(
                        label: 'En cours',
                        background: c.dangerBg,
                        foreground: c.dangerText,
                      ),
                    ],
                  ],
                ),
                Text(
                  sameDay
                      ? '${Fmt.shortDay(m.start)} · ${Fmt.range(m.start, m.end)}'
                      : '${Fmt.dateTime(m.start)} → ${Fmt.dateTime(m.end)}',
                  style: EsText.bodyS.copyWith(color: c.textSecondary),
                ),
                Text(
                  m.reason,
                  style: EsText.bodyS.copyWith(color: c.textPrimary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tr('Retirer la fermeture'),
            icon: Icon(Icons.delete_outline_rounded, color: c.dangerText),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Retirer cette fermeture ?'),
                  content: Text(
                    '${roomName(m.roomId)} redeviendra réservable sur ce '
                    'créneau.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Retirer'),
                    ),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              final sm = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(adminServiceProvider)
                    .removeMaintenance(ref.read(currentPersonProvider), m);
                sm.showSnackBar(
                  const SnackBar(content: Text('Fermeture retirée.')),
                );
              } on AdminProblem catch (e) {
                sm.showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Plan a closure: room, from (day, hour) to (day, hour), reason.
/// A closure can span several days (up to 60).
class _MaintenanceSheet extends ConsumerStatefulWidget {
  const _MaintenanceSheet();

  @override
  ConsumerState<_MaintenanceSheet> createState() => _MaintenanceSheetState();
}

class _MaintenanceSheetState extends ConsumerState<_MaintenanceSheet> {
  String? roomId;
  late DateTime day;
  late DateTime endDay;
  late int fromHour;
  late int toHour;
  final reason = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final w = ref.read(worldProvider);
    var d = DateTime(w.now.year, w.now.month, w.now.day + 1);
    while (!w.policy.openWeekdays.contains(d.weekday)) {
      d = DateTime(d.year, d.month, d.day + 1);
    }
    day = d;
    endDay = d;
    fromHour = w.policy.openingHour;
    toHour = w.policy.closingHour;
    reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  DateTime get start => DateTime(day.year, day.month, day.day, fromHour);
  DateTime get end => DateTime(endDay.year, endDay.month, endDay.day, toHour);

  Future<DateTime?> _pick(DateTime initial, DateTime first, DateTime now) =>
      showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: now.add(const Duration(days: 240)),
      );

  Future<void> _save() async {
    setState(() => busy = true);
    final m = ScaffoldMessenger.of(context);
    try {
      final clashes = await ref.read(adminServiceProvider).addMaintenance(
            ref.read(currentPersonProvider),
            roomId: roomId!,
            start: start,
            end: end,
            reason: reason.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      m.showSnackBar(
        SnackBar(
          content: Text(
            clashes == 0
                ? 'Fermeture planifiée.'
                : 'Fermeture planifiée. $clashes séance'
                    '${clashes > 1 ? 's' : ''} sur ce créneau : '
                    'prévenez les personnes concernées.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } on AdminProblem catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final roomIds = {for (final s in Catalog.studios) s.roomId}.toList();
    final rooms = {for (final s in Catalog.studios) s.id: s.roomId};
    final clashes = roomId == null
        ? 0
        : w.bookings
            .where(
              (b) =>
                  rooms[b.studioId] == roomId &&
                  (b.status == BookingStatus.approved || b.status.isPending) &&
                  b.end.isAfter(w.now) &&
                  b.start.isBefore(end) &&
                  start.isBefore(b.end),
            )
            .length;
    final tooLong = end.difference(start) > const Duration(days: 60);
    final ready = roomId != null &&
        end.isAfter(start) &&
        !tooLong &&
        reason.text.trim().length >= 3;
    final today = DateTime(w.now.year, w.now.month, w.now.day);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        EsSpace.page,
        0,
        EsSpace.page,
        EsSpace.s5 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Planifier une fermeture',
              style: EsText.displayM.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: EsSpace.s3),
            DropdownButtonFormField<String>(
              initialValue: roomId,
              decoration: InputDecoration(labelText: tr('Salle')),
              items: [
                for (final r in roomIds)
                  DropdownMenuItem(value: r, child: Text(roomName(r))),
              ],
              onChanged: (v) => setState(() => roomId = v),
            ),
            const SizedBox(height: EsSpace.s3),
            _When(
              label: 'Du',
              day: day,
              hour: _clampHour(fromHour, 6, 22),
              hours: const (6, 22),
              onDay: () async {
                final p = await _pick(day, today, w.now);
                if (p == null) return;
                setState(() {
                  day = p;
                  if (endDay.isBefore(p)) endDay = p;
                });
              },
              onHour: (v) => setState(() => fromHour = v),
            ),
            const SizedBox(height: EsSpace.s3),
            _When(
              label: 'Au',
              day: endDay,
              hour: _clampHour(toHour, 7, 23),
              hours: const (7, 23),
              onDay: () async {
                final p = await _pick(endDay, day, w.now);
                if (p != null) setState(() => endDay = p);
              },
              onHour: (v) => setState(() => toHour = v),
            ),
            if (!end.isAfter(start) || tooLong)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tooLong
                      ? 'Une fermeture dure au plus 60 jours.'
                      : 'La fin doit être après le début.',
                  style: EsText.bodyS.copyWith(color: c.dangerText),
                ),
              ),
            const SizedBox(height: EsSpace.s3),
            TextField(
              controller: reason,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: tr('Raison'),
                hintText: tr('Ex. : remplacement du téléprompteur'),
              ),
            ),
            if (clashes > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InfoBanner(
                  tone: BannerTone.warning,
                  icon: Icons.event_busy_outlined,
                  title: '$clashes séance${clashes > 1 ? 's' : ''} sur ce '
                      'créneau',
                  text: 'Elles ne sont pas annulées automatiquement. '
                      'Prévenez les personnes concernées.',
                ),
              ),
            EsButton(
              'Planifier la fermeture',
              loading: busy,
              onPressed: ready && !busy ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

int _clampHour(int h, int min, int max) => h.clamp(min, max);

/// One end of a closure: a day button and an hour menu.
class _When extends StatelessWidget {
  const _When({
    required this.label,
    required this.day,
    required this.hour,
    required this.hours,
    required this.onDay,
    required this.onHour,
  });
  final String label;
  final DateTime day;
  final int hour;
  final (int, int) hours;
  final VoidCallback onDay;
  final ValueChanged<int> onHour;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onDay,
              icon: const Icon(Icons.event_rounded),
              label: Text(
                '$label ${Fmt.longDay(day).toLowerCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: DropdownButtonFormField<int>(
              key: ValueKey('$label-$hour'),
              initialValue: hour,
              decoration: InputDecoration(labelText: tr('Heure')),
              items: [
                for (var h = hours.$1; h <= hours.$2; h++)
                  DropdownMenuItem(value: h, child: Text('$h h')),
              ],
              onChanged: (v) => v == null ? null : onHour(v),
            ),
          ),
        ],
      );
}
