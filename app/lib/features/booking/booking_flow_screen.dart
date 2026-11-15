
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
import '../../data/projects_state.dart';
import '../../data/selectors.dart';
import '../../domain/bookings.dart';
import '../../domain/people.dart';
import '../../domain/projects.dart';
import '../../domain/rules/approval.dart';
import '../../domain/rules/availability.dart';
import '../../domain/rules/projects.dart';
import '../../domain/rules/quota.dart';
import '../../domain/studios.dart';
import 'month_calendar.dart';
import '../../data/catalog.dart';

/// D0–D3 · Booking in four steps (R-10 to R-15, R-33):
/// 1. choose the date on a month calendar, 2. choose the time,
/// 3. details, 4. review and send.
class BookingFlowScreen extends ConsumerStatefulWidget {
  const BookingFlowScreen({
    super.key,
    required this.studioId,
    this.initialDay,
    this.projectId,
  });
  final String studioId;
  final DateTime? initialDay;

  /// Booking started from a project: linked to it automatically (R-23).
  final String? projectId;

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowState();
}

class _Equip {
  _Equip(this.id);
  final String id;

  /// Read live, so a stock change by the admin shows at once.
  EquipmentItem get item => Catalog.equipment.firstWhere((e) => e.id == id);
  int qty = 0;
  bool required = false;
}

class _BookingFlowState extends ConsumerState<BookingFlowScreen> {
  int step = 0;
  late DateTime day;

  /// First day of the month shown on the calendar.
  late DateTime month;
  DateTime? rangeStart;
  DateTime? rangeEnd;
  Activity? activity;
  bool forClub = false;
  String? projectId;
  final note = TextEditingController();
  final equip = [for (final e in Catalog.equipment) _Equip(e.id)];
  bool sending = false;

  Studio get studio => studioById(widget.studioId);

  @override
  void initState() {
    super.initState();
    // Keep a project from the link only if this person works on it.
    final me = ref.read(currentPersonProvider);
    projectId = _myProjects(me).any((p) => p.id == widget.projectId)
        ? widget.projectId
        : null;
    final w = ref.read(worldProvider);
    final days = _bookableDays(w);
    final asked =
        widget.initialDay == null ? null : dateOnly(widget.initialDay!);
    // Use the requested day only if it can really be booked.
    final usable = asked != null && _canPick(w, asked);
    day = usable
        ? asked
        : days.firstWhere((d) => _freeOn(w, d) > 0, orElse: () => days.first);
    month = DateTime(day.year, day.month);
    if (usable && widget.initialDay!.hour >= w.policy.openingHour) {
      // Came from a suggested slot: skip the calendar, slot already picked.
      rangeStart = widget.initialDay;
      rangeEnd = widget.initialDay!.add(Duration(minutes: w.policy.slotMinutes));
      step = 1;
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

  List<Slot> _slots(WorldState w) => _slotsOn(w, day);

  List<Slot> _slotsOn(WorldState w, DateTime d) => slotsFor(
        studio: studio,
        day: d,
        policy: w.policy,
        allStudios: Catalog.studios,
        bookings: w.bookings,
        maintenance: w.maintenance,
        now: w.now,
      );

  /// Free hours on [d] (0 = full or closed).
  int _freeOn(WorldState w, DateTime d) =>
      _slotsOn(w, d).where((s) => s.state.isSelectable).length;

  /// Inside the booking window, open, and not full.
  bool _canPick(WorldState w, DateTime d) =>
      _bookableDays(w).contains(d) && _freeOn(w, d) > 0;

  /// Projects this person can book for (owner or collaborator).
  List<Project> _myProjects(Person me) => [
        for (final p in ref.read(projectsProvider).projects)
          if (canWorkOn(me, p)) p,
      ];

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
            projectId: projectId,
            studioId: studio.id,
            start: rangeStart!,
            end: rangeEnd!,
            activity: activity!,
            note: note.text.trim().isEmpty ? null : note.text.trim(),
            equipment: [
              // Never more than the stock, even if it was lowered meanwhile.
              for (final e in equip)
                if (e.qty.clamp(0, e.item.stock) > 0)
                  EquipmentRequest(
                    itemId: e.id,
                    quantity: e.qty.clamp(0, e.item.stock),
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
                      step = 1;
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
    // Closed by the admin (or an old link): say so instead of an empty
    // calendar.
    if (!studio.bookable && !sending) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(EsSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EsBackButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/studios'),
                ),
                const Expanded(
                  child: EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'Studio fermé à la réservation',
                    message: 'Ce studio ne prend pas de nouvelles demandes '
                        'pour le moment. Les séances déjà validées sont '
                        'maintenues.',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final titles = [
      'Choisissez une date',
      'Choisissez un créneau',
      'Votre demande',
      'Vérifiez et envoyez',
    ];

    final canContinue = switch (step) {
      0 => _canPick(w, day),
      1 => rangeStart != null,
      2 => activity != null,
      _ => !sending,
    };
    final top = MediaQuery.paddingOf(context).top;

    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => step--);
      },
      child: Scaffold(
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                EsSpace.page - 4,
                top + EsSpace.s3,
                EsSpace.page,
                0,
              ),
              child: Row(
                children: [
                  EsBackButton(
                    close: step == 0,
                    label: step == 0 ? null : 'Retour',
                    onPressed: () =>
                        step == 0 ? context.pop() : setState(() => step--),
                  ),
                  const Spacer(),
                  _StepPill(step: step, total: 4),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                EsSpace.page,
                EsSpace.s4,
                EsSpace.page,
                EsSpace.s2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: EsMotion.medium,
                          child: Text(
                            titles[step],
                            key: ValueKey(step),
                            style: EsText.displayL
                                .copyWith(color: c.textPrimary),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${studio.name} · '
                          '${DemoWorld.rooms.firstWhere((r) => r.id == studio.roomId).name}',
                          style: EsText.bodyM.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  PhotoThumb(studio.photo, size: 52, radius: 16),
                ],
              ),
            ),
            _Progress(step: step),
            Expanded(
              child: AnimatedSwitcher(
                duration: EsMotion.medium,
                switchInCurve: EsMotion.curve,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(step),
                  child: switch (step) {
                    0 => _dateStep(w),
                    1 => _timeStep(w, me),
                    2 => _detailsStep(me),
                    _ => _reviewStep(w, me),
                  },
                ),
              ),
            ),
            _BottomBar(
              summary: step == 1 && rangeStart != null
                  ? '${Fmt.shortDay(day)} · ${Fmt.range(rangeStart!, rangeEnd!)}'
                  : null,
              duration: step == 1 && rangeStart != null
                  ? formatMinutes(_minutes)
                  : null,
              label: switch (step) {
                0 when !canContinue => 'Choisissez un autre jour',
                0 => 'Voir les créneaux du ${Fmt.dayMonth(day)}',
                1 when rangeStart == null => 'Choisissez un créneau',
                2 when activity == null => 'Choisissez une activité',
                1 || 2 => 'Continuer',
                _ => 'Envoyer la demande',
              },
              loading: sending,
              onPressed: canContinue
                  ? () => step < 3 ? setState(() => step++) : _send()
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ step 1 (D0)
  Widget _dateStep(WorldState w) {
    final days = _bookableDays(w);
    final first = DateTime(w.now.year, w.now.month);
    final last = DateTime(days.last.year, days.last.month);
    final free = {for (final d in days) d: _freeOn(w, d)};
    final n = free[day] ?? 0;
    return ListView(
      // A little narrower gutter so day cells stay ≥ 44 px on small phones.
      padding: const EdgeInsets.fromLTRB(
        EsSpace.page - 8,
        EsSpace.s3,
        EsSpace.page - 8,
        EsSpace.s6,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonthCalendar(
                  month: month,
                  today: dateOnly(w.now),
                  selected: day,
                  freeByDay: free,
                  canGoBack: month.isAfter(first),
                  canGoForward: month.isBefore(last),
                  onMonth: (m) => setState(() => month = m),
                  onDay: (d) => setState(() {
                    if (d != day) rangeStart = rangeEnd = null;
                    day = d;
                  }),
                ),
                const SizedBox(height: EsSpace.s4),
                _ChosenDate(day: day, free: n),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ step 2 (D1)
  Widget _timeStep(WorldState w, Person me) {
    final c = context.es;
    final slots = _slots(w);
    final q = quotaFor(
      requesterId: me.id,
      type: _type(me),
      day: day,
      bookings: w.bookings,
      policy: w.policy,
      clubId: forClub ? me.clubIds.first : null,
    );
    final shared = Catalog.studios
        .where((s) => s.roomId == studio.roomId && s.id != studio.id)
        .map((s) => s.name)
        .toList();
    final freeCount = slots.where((s) => s.state.isSelectable).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, EsSpace.s3, 0, EsSpace.s6),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EsSpace.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EsCard(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                child: Row(
                  children: [
                    const IconTile(Icons.calendar_month_rounded, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Fmt.longDay(day),
                            style:
                                EsText.titleM.copyWith(color: c.textPrimary),
                          ),
                          Text(
                            freeCount == 0
                                ? 'Complet'
                                : '$freeCount créneau${freeCount > 1 ? 'x' : ''} '
                                    'libre${freeCount > 1 ? 's' : ''}',
                            style: EsText.bodyS.copyWith(
                              color: freeCount == 0
                                  ? c.dangerText
                                  : c.successText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        step = 0;
                        month = DateTime(day.year, day.month);
                      }),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      child: const Text('Changer'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: EsSpace.s4),
              if (slots.isEmpty)
                Text(
                  'Aucun créneau ce jour-là.',
                  style: EsText.bodyM.copyWith(color: c.textSecondary),
                )
              else
                for (var i = 0; i < slots.length; i++)
                  SlotTile(
                    slot: slots[i],
                    selected: _selected(slots[i]),
                    joinTop: i > 0 &&
                        _selected(slots[i]) &&
                        _selected(slots[i - 1]),
                    joinBottom: i < slots.length - 1 &&
                        _selected(slots[i]) &&
                        _selected(slots[i + 1]),
                    onTap: slots[i].state.isSelectable
                        ? () => _tapSlot(slots[i])
                        : null,
                  ),
              const SizedBox(height: EsSpace.s2),
              Text(
                'Touchez plusieurs créneaux qui se suivent pour réserver '
                'plus longtemps.',
                style: EsText.bodyS.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: EsSpace.s4),
              if (shared.isNotEmpty) ...[
                InfoBanner(
                  icon: Icons.meeting_room_outlined,
                  title: 'Salle partagée',
                  text: 'Avec ${shared.join(', ')} : leurs réservations '
                      'bloquent aussi ces créneaux.',
                ),
                const SizedBox(height: EsSpace.s3),
              ],
              if (!q.unlimited)
                _QuotaMeter(q: q, adding: _minutes),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ step 2 (D2)
  Widget _detailsStep(Person me) {
    final c = context.es;
    final clubs = [
      for (final id in me.clubIds) DemoWorld.clubs.firstWhere((x) => x.id == id),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        EsSpace.page,
        EsSpace.s3,
        EsSpace.page,
        EsSpace.s6,
      ),
      children: [
        const SectionTitle('Que venez-vous faire ?'),
        Text(
          'Obligatoire. Elle aide la régie à préparer le studio.',
          style: EsText.bodyS.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: EsSpace.s3),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.9,
          children: [
            for (final a in Activity.values)
              _ActivityCard(
                activity: a,
                selected: activity == a,
                onTap: () => setState(() => activity = a),
              ),
          ],
        ),
        if (clubs.isNotEmpty) ...[
          const SizedBox(height: EsSpace.s5),
          const SectionTitle('Pour qui ?'),
          const SizedBox(height: EsSpace.s2),
          _Choice(
            title: 'Pour moi',
            subtitle: me.title ?? '',
            icon: Icons.person_outline_rounded,
            selected: !forClub,
            onTap: () => setState(() => forClub = false),
          ),
          const SizedBox(height: 10),
          _Choice(
            title: 'Pour ${clubs.first.name}',
            subtitle: 'Vous êtes représentant·e. La demande est au nom du club.',
            icon: Icons.groups_outlined,
            selected: forClub,
            onTap: () => setState(() => forClub = true),
          ),
        ],
        if (_myProjects(me).isNotEmpty) ...[
          const SizedBox(height: EsSpace.s5),
          const SectionTitle('Pour un projet ?'),
          Text(
            'Facultatif. La séance apparaîtra dans le suivi du projet.',
            style: EsText.bodyS.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: EsSpace.s2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Aucun'),
                selected: projectId == null,
                onSelected: (_) => setState(() => projectId = null),
              ),
              for (final p in _myProjects(me))
                ChoiceChip(
                  avatar: const Icon(Icons.layers_outlined, size: 16),
                  label: Text(p.title),
                  selected: projectId == p.id,
                  onSelected: (_) => setState(() => projectId = p.id),
                ),
            ],
          ),
        ],
        const SizedBox(height: EsSpace.s5),
        const SectionTitle('Matériel en plus'),
        Text(
          'Facultatif. Marquez ce qui est indispensable : un article '
          'souhaité mais indisponible n’annule pas la réservation.',
          style: EsText.bodyS.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: EsSpace.s3),
        for (final e in equip)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EquipRow(e: e, onChanged: () => setState(() {})),
          ),
        const SizedBox(height: EsSpace.s4),
        const SectionTitle('Un mot pour les validateurs'),
        const SizedBox(height: EsSpace.s2),
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
          '${e.item.name} × ${e.qty} · '
              '${e.required ? 'indispensable' : 'souhaité'}',
    ];
    final room = DemoWorld.rooms.firstWhere((r) => r.id == studio.roomId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        EsSpace.page,
        EsSpace.s3,
        EsSpace.page,
        EsSpace.s6,
      ),
      children: [
        if (problem != null && problem != SubmitProblem.charterMissing) ...[
          InfoBanner(tone: BannerTone.danger, text: problem.message),
          const SizedBox(height: EsSpace.s3),
        ],
        EsCard(
          padding: EdgeInsets.zero,
          radius: EsRadius.xl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(studio.photo, fit: BoxFit.cover),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            c.bgBrand.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studio.name,
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    _Row(
                      Icons.event_rounded,
                      'Créneau',
                      '${Fmt.longDay(day)}\n${Fmt.range(rangeStart!, rangeEnd!)} '
                          '· ${formatMinutes(_minutes)}',
                    ),
                    _Row(Icons.movie_creation_outlined, 'Activité',
                        activity!.label),
                    _Row(
                      Icons.badge_outlined,
                      'Au nom de',
                      forClub
                          ? DemoWorld.clubs
                              .firstWhere((x) => x.id == me.clubIds.first)
                              .name
                          : me.fullName,
                    ),
                    if (projectId != null)
                      _Row(
                        Icons.layers_outlined,
                        'Projet',
                        _myProjects(me)
                                .where((p) => p.id == projectId)
                                .firstOrNull
                                ?.title ??
                            '—',
                      ),
                    if (items.isNotEmpty)
                      _Row(Icons.inventory_2_outlined, 'Matériel',
                          items.join('\n')),
                    if (note.text.trim().isNotEmpty)
                      _Row(Icons.notes_rounded, 'Note', note.text.trim()),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: EsSpace.s4),
        const SectionTitle('Qui va valider ?'),
        const SizedBox(height: EsSpace.s2),
        EsCard(
          child: Column(
            children: [
              _Level(
                n: 1,
                title: level1Label(type),
                subtitle: 'Validation de la demande',
              ),
              const _Level(
                n: 2,
                title: level2Label,
                subtitle: 'Studio, techniciens et matériel',
              ),
              const _Level(
                n: 3,
                title: 'Validée',
                subtitle: 'Votre QR code d’accès est prêt',
                last: true,
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
        InfoBanner(
          tone: signed ? BannerTone.success : BannerTone.warning,
          icon: signed ? Icons.verified_outlined : Icons.draw_outlined,
          text: signed
              ? 'Règlement intérieur signé (version ${w.policy.charterVersion}).'
              : 'Vous signerez le règlement intérieur juste avant l’envoi.',
        ),
      ],
    );
  }
}

/// "Date choisie : 14 nov. 2026", under the calendar.
class _ChosenDate extends StatelessWidget {
  const _ChosenDate({required this.day, required this.free});
  final DateTime day;
  final int free;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Semantics(
      liveRegion: true,
      child: EsCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconTile(
              free == 0 ? Icons.event_busy_outlined : Icons.event_available_rounded,
              size: 44,
              bg: free == 0 ? c.dangerBg : c.lilac,
              fg: free == 0 ? c.dangerText : c.onLilac,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date choisie : ${Fmt.dayMonthYear(day)}',
                    style: EsText.titleM.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    free == 0
                        ? 'Pas de créneau libre ce jour-là. Choisissez un '
                            'autre jour.'
                        : '$free créneau${free > 1 ? 'x' : ''} '
                            'libre${free > 1 ? 's' : ''} · Touchez '
                            '« Voir les créneaux » pour continuer.',
                    style: EsText.bodyS.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.actionPrimary,
        borderRadius: BorderRadius.circular(EsRadius.pill),
      ),
      child: Text(
        'ÉTAPE ${step + 1}/$total',
        style: EsText.overline.copyWith(color: c.onActionPrimary),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    const labels = ['Date', 'Créneau', 'Détails', 'Envoi'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(EsSpace.page, 8, EsSpace.page, 4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: EsMotion.medium,
                    curve: EsMotion.curve,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i <= step ? c.actionPrimary : c.lilac,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: EsText.labelS.copyWith(
                      color: i <= step ? c.textPrimary : c.textDisabled,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The floating bottom bar: what you picked, and the main action.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.label,
    required this.onPressed,
    required this.loading,
    this.summary,
    this.duration,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? summary;
  final String? duration;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        EsSpace.page,
        EsSpace.s3,
        EsSpace.page,
        EsSpace.s3 + bottom,
      ),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(EsRadius.xl),
        ),
        boxShadow: esShadow(c, strength: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: EsMotion.medium,
            curve: EsMotion.curve,
            child: summary == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const IconTile(Icons.event_available_rounded, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            summary!,
                            style: EsText.titleS
                                .copyWith(color: c.textPrimary),
                          ),
                        ),
                        Tag(
                          label: duration!,
                          background: c.lilac,
                          foreground: c.onLilac,
                        ),
                      ],
                    ),
                  ),
          ),
          EsButton(
            label,
            loading: loading,
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

/// One hour of the day, as a full-width row ("09:00 — 10:00 · Libre").
///
/// Consecutive selected rows join into one block, so a 2-hour booking
/// reads as one piece of time.
class SlotTile extends StatelessWidget {
  const SlotTile({
    super.key,
    required this.slot,
    required this.selected,
    this.onTap,
    this.joinTop = false,
    this.joinBottom = false,
  });
  final Slot slot;
  final bool selected;
  final bool joinTop;
  final bool joinBottom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (Color bg, Color fg, Color sub, IconData? icon, String label) =
        selected
            ? (
                c.actionPrimary,
                c.onActionPrimary,
                c.onActionPrimary,
                Icons.check_circle_rounded,
                'Choisi',
              )
            : switch (slot.state) {
                SlotState.free => (
                    c.bgSurface,
                    c.textPrimary,
                    c.successText,
                    null,
                    'Libre',
                  ),
                SlotState.pending => (
                    c.pendingBg,
                    c.pendingText,
                    c.pendingText,
                    Icons.lock_clock_outlined,
                    'En attente',
                  ),
                SlotState.taken => (
                    c.bgSubtle,
                    c.textDisabled,
                    c.textDisabled,
                    Icons.block_rounded,
                    'Réservé',
                  ),
                SlotState.maintenance => (
                    c.bgSubtle,
                    c.textDisabled,
                    c.pendingText,
                    Icons.build_outlined,
                    'Maintenance',
                  ),
                SlotState.past => (
                    c.bgSubtle,
                    c.textDisabled,
                    c.textDisabled,
                    null,
                    'Passé',
                  ),
              };
    const r = Radius.circular(EsRadius.md);
    final radius = BorderRadius.vertical(
      top: joinTop ? Radius.zero : r,
      bottom: joinBottom ? Radius.zero : r,
    );
    final free = slot.state == SlotState.free && !selected;
    return Padding(
      padding: EdgeInsets.only(bottom: joinBottom ? 0 : 8),
      child: Semantics(
        button: onTap != null,
        selected: selected,
        label: '${Fmt.range(slot.start, slot.end)}, $label',
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: EsMotion.fast,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: free ? Border.all(color: c.border) : null,
            boxShadow: free ? esShadow(c, strength: 0.5) : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: SizedBox(
                height: 54,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${Fmt.time(slot.start)}  —  ${Fmt.time(slot.end)}',
                        style: EsText.numeric.copyWith(
                          color: fg,
                          decoration: slot.state == SlotState.taken &&
                                  !selected
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const Spacer(),
                      if (icon != null) ...[
                        Icon(icon, size: 16, color: sub),
                        const SizedBox(width: 6),
                      ],
                      Text(label, style: EsText.labelS.copyWith(color: sub)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How much of the weekly quota this request would use.
class _QuotaMeter extends StatelessWidget {
  const _QuotaMeter({required this.q, required this.adding});
  final QuotaStatus q;
  final int adding;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final limit = q.limitMinutes!;
    final ok = q.allows(adding);
    final used = q.usedMinutes / limit;
    final add = (adding / limit).clamp(0.0, 1.0 - used.clamp(0.0, 1.0));
    return EsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hourglass_bottom_rounded,
                size: 18,
                color: ok ? c.onLilac : c.dangerText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quota de la semaine',
                  style: EsText.titleS.copyWith(color: c.textPrimary),
                ),
              ),
              Text(
                '${formatMinutes(q.usedMinutes + adding)} / '
                '${formatMinutes(limit)}',
                style: EsText.labelM.copyWith(
                  color: ok ? c.textPrimary : c.dangerText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: LayoutBuilder(
                builder: (context, box) => Stack(
                  children: [
                    Container(color: c.lilac),
                    Container(
                      width: box.maxWidth * used.clamp(0.0, 1.0),
                      color: c.actionPrimary,
                    ),
                    AnimatedPositioned(
                      duration: EsMotion.medium,
                      left: box.maxWidth * used.clamp(0.0, 1.0),
                      top: 0,
                      bottom: 0,
                      width: box.maxWidth * add,
                      child: Container(
                        color: ok ? c.accent : c.dangerText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ok
                ? adding == 0
                    ? 'Il vous reste ${formatMinutes(q.remainingMinutes)} '
                        'cette semaine-là.'
                    : 'Après cette demande, il restera '
                        '${formatMinutes(q.remainingMinutes - adding)}.'
                : 'Cette durée dépasse votre quota : il ne vous reste que '
                    '${formatMinutes(q.remainingMinutes)} cette semaine-là.',
            style: EsText.bodyS.copyWith(
              color: ok ? c.textSecondary : c.dangerText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.selected,
    required this.onTap,
  });
  final Activity activity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final icon = switch (activity) {
      Activity.recording => Icons.mic_rounded,
      Activity.filming => Icons.videocam_rounded,
      Activity.editing => Icons.movie_edit,
      Activity.mixing => Icons.tune_rounded,
    };
    return Semantics(
      selected: selected,
      button: true,
      label: activity.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: EsMotion.fast,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? c.actionPrimary : c.bgSurface,
            borderRadius: BorderRadius.circular(EsRadius.lg),
            border: Border.all(
              color: selected ? c.actionPrimary : c.border,
            ),
            boxShadow: selected ? null : esShadow(c, strength: 0.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: selected ? c.onActionPrimary : c.onLilac,
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: c.onActionPrimary,
                    ),
                ],
              ),
              Text(
                activity.label,
                maxLines: 2,
                style: EsText.titleS.copyWith(
                  color: selected ? c.onActionPrimary : c.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: EsMotion.fast,
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(EsRadius.lg),
          border: Border.all(
            color: selected ? c.actionPrimary : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(EsRadius.lg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  IconTile(icon, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: EsText.titleS.copyWith(color: c.textPrimary),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style:
                                EsText.bodyS.copyWith(color: c.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: EsMotion.fast,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? c.actionPrimary : Colors.transparent,
                      border: Border.all(
                        color: selected ? c.actionPrimary : c.borderStrong,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: c.onActionPrimary,
                          )
                        : null,
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
    return EsCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconTile(icon, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.item.name,
                      style: EsText.titleS.copyWith(color: c.textPrimary),
                    ),
                    Text(
                      e.item.detail,
                      style: EsText.bodyS.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: c.bgSubtle,
                  borderRadius: BorderRadius.circular(EsRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Retirer un',
                                            onPressed: e.qty == 0
                          ? null
                          : () {
                              e.qty--;
                              if (e.qty == 0) e.required = false;
                              onChanged();
                            },
                      icon: const Icon(Icons.remove_rounded, size: 18),
                    ),
                    SizedBox(
                      width: 18,
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
                      icon: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: c.actionPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: EsMotion.medium,
            curve: EsMotion.curve,
            child: e.qty == 0
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(left: 54, top: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.required
                                ? 'Indispensable pour la séance'
                                : 'Souhaité, pas indispensable',
                            style: EsText.labelS.copyWith(
                              color:
                                  e.required ? c.textGold : c.textSecondary,
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
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.textSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: EsText.bodyS.copyWith(color: c.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: EsText.labelM.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// One step of the approval path, on a vertical line.
class _Level extends StatelessWidget {
  const _Level({
    required this.n,
    required this.title,
    required this.subtitle,
    this.last = false,
  });
  final int n;
  final String title;
  final String subtitle;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: last ? c.successBg : c.lilac,
                  shape: BoxShape.circle,
                ),
                child: last
                    ? Icon(Icons.qr_code_2_rounded,
                        size: 16, color: c.successText)
                    : Text(
                        '$n',
                        style: EsText.titleS.copyWith(color: c.onLilac),
                      ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: c.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    last ? title : 'Niveau $n · $title',
                    style: EsText.titleS.copyWith(color: c.textPrimary),
                  ),
                  Text(
                    subtitle,
                    style: EsText.bodyS.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
