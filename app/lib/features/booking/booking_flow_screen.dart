import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../data/app_state.dart';
import '../../data/booking_service.dart';
import '../../data/demo_world.dart';
import '../../data/selectors.dart';
import '../../domain/bookings.dart';
import '../../domain/people.dart';
import '../../domain/rules/approval.dart';
import '../../domain/rules/availability.dart';
import '../../domain/rules/quota.dart';
import '../../domain/studios.dart';

/// D1–D3 · Booking in three steps (R-10 to R-15, R-33):
/// 1. choose the time, 2. details, 3. review and send.
class BookingFlowScreen extends ConsumerStatefulWidget {
  const BookingFlowScreen({super.key, required this.studioId, this.initialDay});
  final String studioId;
  final DateTime? initialDay;

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowState();
}

class _Equip {
  _Equip(this.item);
  final EquipmentItem item;
  int qty = 0;
  bool required = false;
}

class _BookingFlowState extends ConsumerState<BookingFlowScreen> {
  int step = 0;
  late DateTime day;
  DateTime? rangeStart;
  DateTime? rangeEnd;
  Activity? activity;
  bool forClub = false;
  final note = TextEditingController();
  final equip = [for (final e in DemoWorld.equipment) _Equip(e)];
  bool sending = false;

  Studio get studio => studioById(widget.studioId);

  @override
  void initState() {
    super.initState();
    final w = ref.read(worldProvider);
    day = widget.initialDay != null
        ? dateOnly(widget.initialDay!)
        : _bookableDays(w).first;
    if (widget.initialDay != null &&
        widget.initialDay!.hour >= w.policy.openingHour) {
      rangeStart = widget.initialDay;
      rangeEnd = widget.initialDay!.add(Duration(minutes: w.policy.slotMinutes));
    }
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  List<DateTime> _bookableDays(WorldState w) => [
        for (var d = 0; d <= w.policy.maxAdvanceDays; d++)
          if (isBookableDay(
            DateTime(w.now.year, w.now.month, w.now.day + d),
            w.now,
            w.policy,
          ))
            DateTime(w.now.year, w.now.month, w.now.day + d),
      ];

  List<Slot> _slots(WorldState w) => slotsFor(
        studio: studio,
        day: day,
        policy: w.policy,
        allStudios: DemoWorld.studios,
        bookings: w.bookings,
        maintenance: w.maintenance,
        now: w.now,
      );

  int get _minutes =>
      rangeStart == null ? 0 : rangeEnd!.difference(rangeStart!).inMinutes;

  RequesterType _type(Person me) =>
      forClub ? RequesterType.club : defaultRequesterType(me);

  void _tapSlot(Slot s) {
    setState(() {
      if (rangeStart == null) {
        rangeStart = s.start;
        rangeEnd = s.end;
      } else if (s.start == rangeEnd) {
        rangeEnd = s.end; // extend after
      } else if (s.end == rangeStart) {
        rangeStart = s.start; // extend before
      } else if (s.start == rangeStart && s.end == rangeEnd) {
        rangeStart = rangeEnd = null; // unselect single
      } else if (s.start == rangeStart) {
        rangeStart = s.end; // shrink from the start
      } else if (s.end == rangeEnd) {
        rangeEnd = s.start; // shrink from the end
      } else {
        rangeStart = s.start;
        rangeEnd = s.end;
      }
    });
  }

  bool _selected(Slot s) =>
      rangeStart != null &&
      !s.start.isBefore(rangeStart!) &&
      !s.end.isAfter(rangeEnd!);

  Future<void> _send() async {
    final me = ref.read(currentPersonProvider);
    final w = ref.read(worldProvider);
    if (w.signedCharterVersion[me.id] != w.policy.charterVersion) {
      final signed = await context.push<bool>('/charter');
      if (signed != true || !mounted) return;
    }
    setState(() => sending = true);
    try {
      final b = await ref.read(bookingServiceProvider).submit(
            requesterId: me.id,
            requesterType: _type(me),
            establishmentId: me.establishmentId,
            clubId: forClub ? me.clubIds.first : null,
            studioId: studio.id,
            start: rangeStart!,
            end: rangeEnd!,
            activity: activity!,
            note: note.text.trim().isEmpty ? null : note.text.trim(),
            equipment: [
              for (final e in equip)
                if (e.qty > 0)
                  EquipmentRequest(
                    itemId: e.item.id,
                    quantity: e.qty,
                    required: e.required,
                  ),
            ],
          );
      if (!mounted) return;
      context.go('/sent/${b.id}');
    } on SubmitRejected catch (e) {
      if (!mounted) return;
      setState(() => sending = false);
      await _showProblem(e.problem);
    }
  }

  Future<void> _showProblem(SubmitProblem p) async {
    final w = ref.read(worldProvider);
    final me = ref.read(currentPersonProvider);
    final c = context.es;
    final (IconData icon, Color bg, Color fg, String title, String body) =
        switch (p) {
      SubmitProblem.slotUnavailable => (
          Icons.error_outline_rounded,
          c.dangerBg,
          c.dangerText,
          'Ce créneau vient d’être demandé',
          'Quelqu’un a envoyé une demande juste avant vous. Rien n’a été '
              'envoyé de votre côté. Choisissez un autre créneau.',
        ),
      SubmitProblem.overQuota => (
          Icons.hourglass_bottom_rounded,
          c.pendingBg,
          c.pendingText,
          'Quota de la semaine atteint',
          () {
            final q = quotaFor(
              requesterId: me.id,
              type: _type(me),
              day: day,
              bookings: w.bookings,
              policy: w.policy,
            );
            return 'Vous avez déjà ${formatMinutes(q.usedMinutes)} sur '
                '${formatMinutes(q.limitMinutes ?? 0)} cette semaine-là. '
                'Il vous reste ${formatMinutes(q.remainingMinutes)}. Le quota '
                'se renouvelle le lundi à 00:00.';
          }(),
        ),
      _ => (
          Icons.info_outline_rounded,
          c.reviewBg,
          c.reviewText,
          'Demande impossible',
          p.message,
        ),
    };
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: bg,
                child: Icon(icon, color: fg, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: EsText.titleL.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: EsText.bodyM.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: 20),
              EsButton(
                p == SubmitProblem.slotUnavailable ||
                        p == SubmitProblem.overQuota
                    ? 'Choisir un autre créneau'
                    : 'Fermer',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (p == SubmitProblem.slotUnavailable ||
                      p == SubmitProblem.overQuota) {
                    setState(() {
                      step = 0;
                      rangeStart = rangeEnd = null;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final me = ref.watch(currentPersonProvider);
    final titles = ['Choisir un créneau', 'Détails', 'Vérifier et envoyer'];

    final canContinue = switch (step) {
      0 => rangeStart != null,
      1 => activity != null,
      _ => !sending,
    };

    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => step--);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(titles[step]),
          leading: IconButton(
            tooltip: step == 0 ? 'Fermer' : 'Étape précédente',
            icon: Icon(step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded),
            onPressed: () =>
                step == 0 ? context.pop() : setState(() => step--),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= step ? c.actionPrimary : c.bgSubtle,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Étape ${step + 1} sur 3 · ${studio.name}',
                    style: EsText.labelS.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(step),
            child: switch (step) {
              0 => _timeStep(w, me),
              1 => _detailsStep(me),
              _ => _reviewStep(w, me),
            },
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: c.bgSurface,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (step == 0 && rangeStart != null) ...[
                  Text(
                    '${Fmt.longDay(day)} · ${Fmt.range(rangeStart!, rangeEnd!)} '
                    '· ${formatMinutes(_minutes)}',
                    style: EsText.titleS.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 10),
                ],
                EsButton(
                  step < 2 ? 'Continuer' : 'Envoyer la demande',
                  loading: sending,
                  onPressed: canContinue
                      ? () => step < 2 ? setState(() => step++) : _send()
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ step 1 (D1)
  Widget _timeStep(WorldState w, Person me) {
    final c = context.es;
    final days = _bookableDays(w);
    final slots = _slots(w);
    final q = quotaFor(
      requesterId: me.id,
      type: _type(me),
      day: day,
      bookings: w.bookings,
      policy: w.policy,
      clubId: forClub ? me.clubIds.first : null,
    );
    final shared = DemoWorld.studios
        .where((s) => s.roomId == studio.roomId && s.id != studio.id)
        .map((s) => s.name)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = days[i];
              final on = d == day;
              return Semantics(
                selected: on,
                button: true,
                label: Fmt.longDay(d),
                child: Material(
                  color: on ? c.bgBrand : c.bgSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: on ? c.bgBrand : c.border),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() {
                      day = d;
                      rangeStart = rangeEnd = null;
                    }),
                    child: SizedBox(
                      width: 60,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _weekday(d),
                            style: EsText.labelS.copyWith(
                              color: on ? c.brandAccent : c.textSecondary,
                            ),
                          ),
                          Text(
                            '${d.day}',
                            style: EsText.titleM.copyWith(
                              color: on ? c.textOnBrand : c.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: EsSpace.s4),
        Text(Fmt.longDay(day), style: EsText.titleM.copyWith(color: c.textPrimary)),
        const SizedBox(height: EsSpace.s3),
        if (slots.isEmpty)
          Text(
            'Aucun créneau ce jour-là.',
            style: EsText.bodyM.copyWith(color: c.textSecondary),
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth > 500 ? 6 : 4;
              final w0 = (box.maxWidth - (cols - 1) * 8) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in slots)
                    SizedBox(
                      width: w0,
                      child: SlotTile(
                        slot: s,
                        selected: _selected(s),
                        onTap: s.state.isSelectable ? () => _tapSlot(s) : null,
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: EsSpace.s3),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _Legend(color: c.bgSurface, border: c.border, label: 'Libre'),
            _Legend(color: c.bgBrand, label: 'Choisi'),
            _Legend(color: c.pendingBg, label: 'En attente'),
            _Legend(color: c.bgSubtle, label: 'Pris ou passé'),
          ],
        ),
        const SizedBox(height: EsSpace.s4),
        if (shared.isNotEmpty) ...[
          InfoBanner(
            icon: Icons.meeting_room_outlined,
            text: 'Salle partagée avec ${shared.join(', ')} : leurs '
                'réservations bloquent aussi ces créneaux.',
          ),
          const SizedBox(height: EsSpace.s3),
        ],
        if (!q.unlimited)
          InfoBanner(
            tone: q.allows(_minutes) ? BannerTone.warning : BannerTone.danger,
            icon: Icons.hourglass_bottom_rounded,
            text: q.allows(_minutes)
                ? 'Quota de cette semaine : ${formatMinutes(q.usedMinutes)} '
                    'déjà réservé sur ${formatMinutes(q.limitMinutes!)}. '
                    'Après cette demande, il restera '
                    '${formatMinutes(q.remainingMinutes - _minutes)}.'
                : 'Cette durée dépasse votre quota : il ne vous reste que '
                    '${formatMinutes(q.remainingMinutes)} cette semaine-là.',
          ),
        const SizedBox(height: EsSpace.s2),
        Text(
          'Touchez plusieurs créneaux qui se suivent pour réserver plus '
          'longtemps.',
          style: EsText.bodyS.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }

  String _weekday(DateTime d) =>
      const ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'][d.weekday - 1];

  // ------------------------------------------------------------ step 2 (D2)
  Widget _detailsStep(Person me) {
    final c = context.es;
    final clubs = [
      for (final id in me.clubIds) DemoWorld.clubs.firstWhere((x) => x.id == id),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const SectionTitle('Nature de l’activité'),
        Text(
          'Obligatoire. Elle aide la régie à préparer le studio.',
          style: EsText.bodyS.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: EsSpace.s3),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in Activity.values)
              ChoiceChip(
                label: Text(a.label),
                selected: activity == a,
                onSelected: (_) => setState(() => activity = a),
              ),
          ],
        ),
        if (clubs.isNotEmpty) ...[
          const SizedBox(height: EsSpace.s5),
          const SectionTitle('Pour qui ?'),
          _Choice(
            title: 'Pour moi',
            subtitle: me.title ?? '',
            selected: !forClub,
            onTap: () => setState(() => forClub = false),
          ),
          const SizedBox(height: 8),
          _Choice(
            title: 'Pour ${clubs.first.name}',
            subtitle: 'Vous êtes représentant·e. La demande est au nom du club.',
            selected: forClub,
            onTap: () => setState(() => forClub = true),
          ),
        ],
        const SizedBox(height: EsSpace.s5),
        const SectionTitle('Matériel supplémentaire'),
        Text(
          'Facultatif. Indiquez ce qui est indispensable : un article '
          'souhaité mais indisponible n’annule pas la réservation.',
          style: EsText.bodyS.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: EsSpace.s3),
        EsCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < equip.length; i++) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                _EquipRow(
                  e: equip[i],
                  onChanged: () => setState(() {}),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: EsSpace.s5),
        const SectionTitle('Note pour les validateurs'),
        TextField(
          controller: note,
          maxLines: 3,
          maxLength: 300,
          decoration: const InputDecoration(
            hintText: 'Ex. : enregistrement avec deux invités externes',
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ step 3 (D3)
  Widget _reviewStep(WorldState w, Person me) {
    final c = context.es;
    final type = _type(me);
    final problem = ref.read(worldProvider.notifier).check(
          requesterId: me.id,
          requesterType: type,
          studioId: studio.id,
          start: rangeStart!,
          end: rangeEnd!,
          clubId: forClub ? me.clubIds.first : null,
        );
    final signed = w.signedCharterVersion[me.id] == w.policy.charterVersion;
    final items = [
      for (final e in equip)
        if (e.qty > 0)
          '${e.item.name} × ${e.qty} '
              '(${e.required ? 'indispensable' : 'souhaité'})',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (problem != null &&
            problem != SubmitProblem.charterMissing) ...[
          InfoBanner(tone: BannerTone.danger, text: problem.message),
          const SizedBox(height: EsSpace.s3),
        ],
        EsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Row('Studio', '${studio.name} · ${DemoWorld.rooms.firstWhere((r) => r.id == studio.roomId).name}'),
              _Row(
                'Créneau',
                '${Fmt.longDay(day)} · ${Fmt.range(rangeStart!, rangeEnd!)} '
                    '(${formatMinutes(_minutes)})',
              ),
              _Row('Activité', activity!.label),
              _Row(
                'Au nom de',
                forClub
                    ? DemoWorld.clubs
                        .firstWhere((x) => x.id == me.clubIds.first)
                        .name
                    : me.fullName,
              ),
              if (items.isNotEmpty) _Row('Matériel', items.join('\n')),
              if (note.text.trim().isNotEmpty) _Row('Note', note.text.trim()),
            ],
          ),
        ),
        const SizedBox(height: EsSpace.s4),
        const SectionTitle('Qui va valider ?'),
        EsCard(
          child: Column(
            children: [
              _Level(n: 1, title: level1Label(type), subtitle: 'Validation métier'),
              const SizedBox(height: 10),
              const _Level(
                n: 2,
                title: level2Label,
                subtitle: 'Régie, techniciens et maintenance',
              ),
            ],
          ),
        ),
        const SizedBox(height: EsSpace.s4),
        const InfoBanner(
          icon: Icons.lock_clock_outlined,
          text: 'Dès l’envoi, ce créneau est bloqué « En attente » pour tout '
              'le monde. Un refus est toujours accompagné d’un motif.',
        ),
        const SizedBox(height: EsSpace.s3),
        Row(
          children: [
            Icon(
              signed ? Icons.verified_outlined : Icons.draw_outlined,
              size: 20,
              color: signed ? c.successText : c.pendingText,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                signed
                    ? 'Règlement intérieur signé (version ${w.policy.charterVersion}).'
                    : 'Vous signerez le règlement intérieur avant l’envoi.',
                style: EsText.bodyS.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One time slot (Figma "SlotChip").
class SlotTile extends StatelessWidget {
  const SlotTile({
    super.key,
    required this.slot,
    required this.selected,
    this.onTap,
  });
  final Slot slot;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (Color bg, Color fg, Color? border, String sub) = selected
        ? (c.bgBrand, c.textOnBrand, null, 'Choisi')
        : switch (slot.state) {
            SlotState.free => (c.bgSurface, c.textPrimary, c.border, 'Libre'),
            SlotState.pending => (c.pendingBg, c.pendingText, null, 'En attente'),
            SlotState.taken => (c.bgSubtle, c.textDisabled, null, 'Pris'),
            SlotState.maintenance => (
                c.bgSubtle,
                c.textDisabled,
                null,
                'Maintenance',
              ),
            SlotState.past => (c.bgSubtle, c.textDisabled, null, 'Passé'),
          };
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '${Fmt.time(slot.start)}, $sub',
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EsRadius.sm),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(EsRadius.sm),
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Fmt.time(slot.start),
                  style: EsText.labelM.copyWith(
                    color: fg,
                    decoration: slot.state == SlotState.taken && !selected
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Text(sub, style: EsText.bodyS.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.border});
  final Color color;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: border == null ? null : Border.all(color: border!),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: EsText.bodyS.copyWith(color: c.textSecondary)),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: c.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EsRadius.md),
          side: BorderSide(
            color: selected ? c.actionPrimary : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(EsRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? c.actionPrimary : c.textDisabled,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: EsText.titleS.copyWith(color: c.textPrimary)),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: EsText.bodyS.copyWith(color: c.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EquipRow extends StatelessWidget {
  const _EquipRow({required this.e, required this.onChanged});
  final _Equip e;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final icon = switch (e.item.icon) {
      'camera' => Icons.videocam_outlined,
      'mic' => Icons.mic_none_rounded,
      'light' => Icons.light_mode_outlined,
      _ => Icons.inventory_2_outlined,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.bgSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: c.textPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.item.name, style: EsText.titleS.copyWith(color: c.textPrimary)),
                    Text(
                      e.item.detail,
                      style: EsText.bodyS.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Retirer un',
                onPressed: e.qty == 0
                    ? null
                    : () {
                        e.qty--;
                        if (e.qty == 0) e.required = false;
                        onChanged();
                      },
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              SizedBox(
                width: 20,
                child: Text(
                  '${e.qty}',
                  textAlign: TextAlign.center,
                  style: EsText.titleS.copyWith(color: c.textPrimary),
                ),
              ),
              IconButton(
                tooltip: 'Ajouter un',
                onPressed: e.qty >= e.item.stock
                    ? null
                    : () {
                        e.qty++;
                        onChanged();
                      },
                icon: Icon(Icons.add_circle_outline_rounded, color: c.actionPrimary),
              ),
            ],
          ),
          if (e.qty > 0)
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.required ? 'Indispensable' : 'Souhaité',
                      style: EsText.labelS.copyWith(
                        color: e.required ? c.textGold : c.textSecondary,
                      ),
                    ),
                  ),
                  Switch(
                    value: e.required,
                    onChanged: (v) {
                      e.required = v;
                      onChanged();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: EsText.labelS.copyWith(color: c.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: EsText.bodyM.copyWith(color: c.textPrimary)),
        ],
      ),
    );
  }
}

class _Level extends StatelessWidget {
  const _Level({required this.n, required this.title, required this.subtitle});
  final int n;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: c.bgBrand,
          child: Text('$n', style: EsText.labelS.copyWith(color: c.brandAccent)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Niveau $n · $title', style: EsText.titleS.copyWith(color: c.textPrimary)),
              Text(subtitle, style: EsText.bodyS.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
