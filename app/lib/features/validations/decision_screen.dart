import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/app_state.dart';
import '../../data/booking_service.dart';
import '../../data/demo_world.dart';
import '../../domain/bookings.dart';
import '../../domain/people.dart';
import '../../domain/rules/approval.dart';
import '../../domain/rules/quota.dart';
import '../bookings/booking_widgets.dart';
import '../../data/directory.dart';

/// Ready-made refusal reasons, so a refusal takes two taps. The approver
/// can always edit or write their own (R-19: a reason is mandatory).
const refusalPresets = [
  'Créneau réservé pour un événement de l’université',
  'Matériel indispensable indisponible',
  'Demande incomplète : merci de préciser le projet',
  'Activité hors du cadre des studios',
];

/// G2/G3 · One request, everything needed to decide, and the decision.
class DecisionScreen extends ConsumerStatefulWidget {
  const DecisionScreen({super.key, required this.bookingId, this.embedded = false});
  final String bookingId;

  /// True when shown in the right pane of the wide (computer) layout.
  final bool embedded;

  @override
  ConsumerState<DecisionScreen> createState() => _DecisionState();
}

class _DecisionState extends ConsumerState<DecisionScreen> {
  /// Level 2: what the studio can actually provide, per requested item.
  final Map<int, EquipmentOutcome> outcomes = {};
  String? technicianId;
  bool busy = false;

  @override
  void didUpdateWidget(DecisionScreen old) {
    super.didUpdateWidget(old);
    if (old.bookingId != widget.bookingId) {
      outcomes.clear();
      technicianId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final me = ref.watch(currentPersonProvider);
    final b = w.bookings.where((x) => x.id == widget.bookingId).firstOrNull;
    if (b == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Demande introuvable',
          message: 'Elle a peut-être été annulée.',
        ),
      );
    }
    final s = studioById(b.studioId);
    final room = DemoWorld.rooms.firstWhere((r) => r.id == s.roomId);
    final who = personById(b.requesterId);
    final level1 = b.status == BookingStatus.pendingEntity;
    final decidable = canDecide(me, b, people: Directory.people);
    final conflict = b.status == BookingStatus.pendingStudio
        ? ref.read(worldProvider.notifier).level2Conflict(b)
        : null;
    final fallback = level1 && needsLevel1Fallback(b, Directory.people);
    final q = quotaFor(
      requesterId: b.requesterId,
      type: b.requesterType,
      day: b.start,
      bookings: w.bookings,
      policy: w.policy,
      clubId: b.clubId,
    );
    final signed = w.signedCharterVersion[b.requesterId];
    final technicians = [
      for (final p in Directory.people)
        if (p.has(Role.regisseur)) p,
    ];
    final missingRequired = !level1 &&
        [
          for (var i = 0; i < b.equipment.length; i++)
            if (b.equipment[i].required &&
                _outcome(i, b) == EquipmentOutcome.unavailable)
              i,
        ].isNotEmpty;
    final sameDay = [
      for (final o in w.bookings)
        if (o.id != b.id &&
            DemoWorld.studios
                    .firstWhere((x) => x.id == o.studioId)
                    .roomId ==
                s.roomId &&
            o.status.holdsSlot &&
            o.start.year == b.start.year &&
            o.start.month == b.start.month &&
            o.start.day == b.start.day)
          o,
    ]..sort((x, y) => x.start.compareTo(y.start));

    final top = widget.embedded ? EsSpace.s5 : MediaQuery.paddingOf(context).top;

    final body = ListView(
      padding: EdgeInsets.fromLTRB(
        EsSpace.page,
        top + (widget.embedded ? 0 : EsSpace.s3),
        EsSpace.page,
        EsSpace.s6,
      ),
      children: [
        if (!widget.embedded)
          Align(
            alignment: Alignment.centerLeft,
            child: EsBackButton(onPressed: () => context.pop()),
          ),
        const SizedBox(height: EsSpace.s3),
        Row(
          children: [
            Expanded(
              child: Overline(
                b.status.isPending
                    ? level1
                        ? 'Niveau 1 · ${fallback ? 'Administration (repli)' : level1Label(b.requesterType)}'
                        : 'Niveau 2 · $level2Label'
                    : 'Demande traitée',
              ),
            ),
            StatusChip(b.status),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Demande ${b.reference}',
          style: EsText.displayL.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: EsSpace.s4),
        if (fallback) ...[
          const InfoBanner(
            icon: Icons.shield_outlined,
            text: 'Le demandeur est lui-même validateur de niveau 1 : la '
                'demande vous revient pour éviter qu’il ne valide sa propre '
                'demande.',
          ),
          const SizedBox(height: EsSpace.s3),
        ],
        // Who
        EsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Avatar(who.initials, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          who.fullName,
                          style: EsText.titleM.copyWith(color: c.textPrimary),
                        ),
                        Text(
                          [
                            b.requesterType.label,
                            if (who.title != null) who.title!,
                          ].join(' · '),
                          style:
                              EsText.bodyS.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (b.clubId != null)
                    Tag(
                      label: 'Au nom de '
                          '${DemoWorld.clubs.firstWhere((x) => x.id == b.clubId).name}',
                      icon: Icons.groups_outlined,
                      background: c.lilac,
                      foreground: c.onLilac,
                    ),
                  Tag(
                    label: signed == null
                        ? 'Règlement non signé'
                        : 'Règlement v$signed signé',
                    icon: signed == null
                        ? Icons.warning_amber_rounded
                        : Icons.verified_outlined,
                    background: signed == null ? c.pendingBg : c.successBg,
                    foreground: signed == null ? c.pendingText : c.successText,
                  ),
                  if (!q.unlimited)
                    Tag(
                      label: 'Quota : ${formatMinutes(q.usedMinutes)} / '
                          '${formatMinutes(q.limitMinutes!)} cette semaine-là',
                      icon: Icons.hourglass_bottom_rounded,
                      background: q.remainingMinutes < 0
                          ? c.dangerBg
                          : c.neutralBg,
                      foreground: q.remainingMinutes < 0
                          ? c.dangerText
                          : c.neutralText,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: EsSpace.s3),
        // What and when
        EsCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 96,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(s.photo, fit: BoxFit.cover),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            c.bgBrand.withValues(alpha: 0.88),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style:
                                EsText.titleL.copyWith(color: Colors.white),
                          ),
                          Text(
                            room.name,
                            style: EsText.bodyS.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _Fact('Date', Fmt.shortDay(b.start)),
                    _Fact('Horaire', Fmt.range(b.start, b.end)),
                    _Fact('Activité', b.activity.label),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (conflict != null) ...[
          const SizedBox(height: EsSpace.s3),
          InfoBanner(
            tone: BannerTone.danger,
            title: 'Validation impossible',
            text: '$conflict Refusez avec un motif, ou proposez un autre '
                'créneau au demandeur.',
          ),
        ],
        const SizedBox(height: EsSpace.s4),
        const SectionTitle('Ce jour-là dans la salle'),
        const SizedBox(height: EsSpace.s2),
        EsCard(
          child: sameDay.isEmpty
              ? Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        color: c.successText),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Aucune autre réservation dans ${room.name} ce jour-là.',
                        style: EsText.bodyM.copyWith(color: c.textSecondary),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    for (final o in sameDay)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                Fmt.range(o.start, o.end),
                                style: EsText.numeric.copyWith(
                                  fontSize: 13,
                                  color: o.overlaps(b.start, b.end)
                                      ? c.dangerText
                                      : c.textPrimary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${studioById(o.studioId).name} · '
                                '${personById(o.requesterId).displayName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: EsText.bodyS
                                    .copyWith(color: c.textSecondary),
                              ),
                            ),
                            StatusChip(o.status),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        if (b.equipment.isNotEmpty) ...[
          const SizedBox(height: EsSpace.s4),
          SectionTitle(
            decidable && !level1 ? 'Matériel : que pouvez-vous fournir ?' : 'Matériel demandé',
          ),
          const SizedBox(height: EsSpace.s2),
          for (var i = 0; i < b.equipment.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EquipmentDecision(
                request: b.equipment[i],
                outcome: _outcome(i, b),
                editable: decidable && !level1,
                onChanged: (o) => setState(() => outcomes[i] = o),
              ),
            ),
          if (missingRequired)
            const InfoBanner(
              tone: BannerTone.danger,
              text: 'Un matériel indispensable est indisponible : la séance '
                  'ne peut pas avoir lieu. Proposez un remplacement ou '
                  'refusez avec un motif.',
            ),
        ],
        if (decidable && !level1 && technicians.isNotEmpty) ...[
          const SizedBox(height: EsSpace.s4),
          const SectionTitle('Technicien pour la séance'),
          const SizedBox(height: EsSpace.s2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in [null, ...technicians])
                ChoiceChip(
                  label: Text(t == null ? 'Aucun' : t.fullName),
                  selected: technicianId == t?.id,
                  onSelected: (_) => setState(() => technicianId = t?.id),
                ),
            ],
          ),
        ],
        if (b.note != null) ...[
          const SizedBox(height: EsSpace.s4),
          const SectionTitle('Message du demandeur'),
          const SizedBox(height: EsSpace.s2),
          EsCard(
            child: Text(
              '« ${b.note} »',
              style: EsText.bodyM.copyWith(
                color: c.textPrimary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        const SizedBox(height: EsSpace.s4),
        const SectionTitle('Historique'),
        const SizedBox(height: EsSpace.s2),
        EsCard(child: BookingTimeline(booking: b)),
        if (!decidable && b.status.isPending) ...[
          const SizedBox(height: EsSpace.s4),
          InfoBanner(
            text: me.id == b.requesterId
                ? 'C’est votre propre demande : un autre validateur doit '
                    'la traiter.'
                : 'Cette demande attend une autre personne.',
          ),
        ],
      ],
    );

    final actions = !decidable
        ? null
        : Container(
            padding: EdgeInsets.fromLTRB(
              EsSpace.page,
              EsSpace.s3,
              EsSpace.page,
              EsSpace.s3 + (widget.embedded ? 0 : MediaQuery.paddingOf(context).bottom),
            ),
            decoration: BoxDecoration(
              color: c.bgSurface,
              borderRadius: widget.embedded
                  ? null
                  : const BorderRadius.vertical(
                      top: Radius.circular(EsRadius.xl),
                    ),
              boxShadow: esShadow(c, strength: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: EsButton(
                    'Refuser',
                    style: EsButtonStyle.destructive,
                    icon: Icons.close_rounded,
                    onPressed: busy ? null : () => _refuse(b, me),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: EsButton(
                    level1 ? 'Approuver' : 'Valider la séance',
                    icon: Icons.check_rounded,
                    loading: busy,
                    onPressed: conflict != null || missingRequired
                        ? null
                        : () => _approve(b, me, level1),
                  ),
                ),
              ],
            ),
          );

    if (widget.embedded) {
      return Column(
        children: [
          Expanded(child: body),
          if (actions != null) actions,
        ],
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: actions,
    );
  }

  EquipmentOutcome _outcome(int i, Booking b) =>
      outcomes[i] ??
      (b.equipment[i].outcome == EquipmentOutcome.pending
          ? EquipmentOutcome.confirmed
          : b.equipment[i].outcome);

  void _done(String message) {
    final m = ScaffoldMessenger.of(context);
    if (!widget.embedded && context.canPop()) context.pop();
    m
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _fail(Object e) {
    if (!mounted) return;
    setState(() => busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e is BookingConflict
              ? e.message
              : 'L’action n’a pas pu être enregistrée. Réessayez.',
        ),
      ),
    );
  }

  Future<void> _approve(Booking b, Person me, bool level1) async {
    final comment = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ApproveSheet(level1: level1, booking: b),
    );
    if (comment == null || !mounted) return;
    setState(() => busy = true);
    try {
      await ref.read(bookingServiceProvider).approve(
            b.id,
            by: me,
            comment: comment.isEmpty ? null : comment,
            equipment: level1
                ? null
                : [
                    for (var i = 0; i < b.equipment.length; i++)
                      b.equipment[i].copyWith(outcome: _outcome(i, b)),
                  ],
            technicianId: level1 ? null : technicianId,
          );
      if (!mounted) return;
      setState(() => busy = false);
      _done(
        level1
            ? 'Approuvée. La demande passe à la Direction des Studios.'
            : 'Séance validée. Le demandeur reçoit son QR code.',
      );
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _refuse(Booking b, Person me) async {
    final reason = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _RefuseSheet(),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    setState(() => busy = true);
    try {
      await ref.read(bookingServiceProvider).refuse(b.id, by: me, reason: reason);
      if (!mounted) return;
      setState(() => busy = false);
      _done('Demande refusée. Le demandeur voit votre motif.');
    } catch (e) {
      _fail(e);
    }
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: EsText.bodyS.copyWith(color: c.textSecondary)),
          const SizedBox(height: 2),
          Text(
            value,
            style: EsText.titleS.copyWith(color: c.textPrimary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _EquipmentDecision extends StatelessWidget {
  const _EquipmentDecision({
    required this.request,
    required this.outcome,
    required this.editable,
    required this.onChanged,
  });
  final EquipmentRequest request;
  final EquipmentOutcome outcome;
  final bool editable;
  final ValueChanged<EquipmentOutcome> onChanged;

  static String label(EquipmentOutcome o) => switch (o) {
        EquipmentOutcome.pending => 'À vérifier',
        EquipmentOutcome.confirmed => 'Disponible',
        EquipmentOutcome.substituted => 'Remplacé',
        EquipmentOutcome.unavailable => 'Indisponible',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final item = equipmentById(request.itemId);
    return EsCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconTile(Icons.inventory_2_outlined, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.name} × ${request.quantity}',
                      style: EsText.titleS.copyWith(color: c.textPrimary),
                    ),
                    Text(
                      '${request.required ? 'Indispensable' : 'Souhaité'} · '
                      'stock ${item.stock}',
                      style: EsText.bodyS.copyWith(
                        color: request.required ? c.textGold : c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!editable)
                Text(
                  label(request.outcome),
                  style: EsText.labelS.copyWith(color: c.textSecondary),
                ),
            ],
          ),
          if (editable) ...[
            const SizedBox(height: 10),
            SegmentedButton<EquipmentOutcome>(
              showSelectedIcon: false,
              segments: [
                for (final o in const [
                  EquipmentOutcome.confirmed,
                  EquipmentOutcome.substituted,
                  EquipmentOutcome.unavailable,
                ])
                  ButtonSegment(value: o, label: Text(label(o))),
              ],
              selected: {outcome},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ],
        ],
      ),
    );
  }
}

class _ApproveSheet extends StatefulWidget {
  const _ApproveSheet({required this.level1, required this.booking});
  final bool level1;
  final Booking booking;

  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  final comment = TextEditingController();

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        EsSpace.page,
        0,
        EsSpace.page,
        EsSpace.s5 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.successBg, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: 32, color: c.successText),
          ),
          const SizedBox(height: EsSpace.s3),
          Text(
            widget.level1 ? 'Approuver cette demande ?' : 'Valider la séance ?',
            textAlign: TextAlign.center,
            style: EsText.displayM.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: EsSpace.s2),
          Text(
            widget.level1
                ? 'Elle passe ensuite à la Direction des Studios, qui vérifie '
                    'le créneau, le matériel et les techniciens.'
                : 'Le créneau est confirmé et le demandeur reçoit son QR code '
                    'd’accès.',
            textAlign: TextAlign.center,
            style: EsText.bodyM.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: EsSpace.s4),
          TextField(
            controller: comment,
            maxLines: 2,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'Un mot pour le demandeur (facultatif)',
            ),
          ),
          const SizedBox(height: EsSpace.s2),
          EsButton(
            widget.level1 ? 'Approuver' : 'Valider la séance',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.pop(context, comment.text.trim()),
          ),
        ],
      ),
    );
  }
}

class _RefuseSheet extends StatefulWidget {
  const _RefuseSheet();

  @override
  State<_RefuseSheet> createState() => _RefuseSheetState();
}

class _RefuseSheetState extends State<_RefuseSheet> {
  final reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        EsSpace.page,
        0,
        EsSpace.page,
        EsSpace.s5 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pourquoi refuser ?',
            style: EsText.displayM.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Le motif est obligatoire. Le demandeur le verra.',
            style: EsText.bodyM.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: EsSpace.s3),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in refusalPresets)
                ActionChip(
                  label: Text(p),
                  onPressed: () => reason.text = p,
                ),
            ],
          ),
          const SizedBox(height: EsSpace.s3),
          TextField(
            controller: reason,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(
              hintText: 'Écrivez le motif, ou choisissez-en un ci-dessus',
            ),
          ),
          const SizedBox(height: EsSpace.s2),
          EsButton(
            'Refuser la demande',
            style: EsButtonStyle.destructive,
            onPressed: reason.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, reason.text.trim()),
          ),
        ],
      ),
    );
  }
}
