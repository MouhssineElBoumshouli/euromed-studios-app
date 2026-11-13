import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../data/app_state.dart';
import '../../data/demo_world.dart';
import '../../domain/rules/availability.dart';
import '../../domain/studios.dart';
import 'studios_screen.dart';

/// The next free slots of [studio], starting now, across the next days.
List<Slot> nextFreeSlots(WorldState w, Studio studio, {int count = 3}) {
  final out = <Slot>[];
  for (var d = 0; d <= w.policy.maxAdvanceDays && out.length < count; d++) {
    final day = DateTime(w.now.year, w.now.month, w.now.day + d);
    if (!isBookableDay(day, w.now, w.policy)) continue;
    out.addAll(
      slotsFor(
        studio: studio,
        day: day,
        policy: w.policy,
        allStudios: DemoWorld.studios,
        bookings: w.bookings,
        maintenance: w.maintenance,
        now: w.now,
      ).where((s) => s.state.isSelectable).take(count - out.length),
    );
  }
  return out;
}

/// C2 · Studio detail.
class StudioDetailScreen extends ConsumerWidget {
  const StudioDetailScreen({super.key, required this.studioId});
  final String studioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final s = studioById(studioId);
    final room = DemoWorld.rooms.firstWhere((r) => r.id == s.roomId);
    final shared = DemoWorld.studios
        .where((x) => x.roomId == s.roomId && x.id != s.id)
        .map((x) => x.name)
        .toList();
    final free = nextFreeSlots(w, s);

    final hours = '${w.policy.openingHour.toString().padLeft(2, '0')}:00–'
        '${w.policy.closingHour.toString().padLeft(2, '0')}:00';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            backgroundColor: c.bgApp,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leadingWidth: 72,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: EsBackButton(
                  label: null,
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Hero(
                tag: 'studio-${s.id}',
                child: Image.asset(s.photo, fit: BoxFit.cover),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: BoxDecoration(
                  color: c.bgApp,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(EsRadius.xl),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  EsSpace.page,
                  EsSpace.s6,
                  EsSpace.page,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Overline(s.zone.label),
                    const SizedBox(height: 6),
                    Text(
                      s.name,
                      style: EsText.displayXL.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: EsSpace.s2),
                    Text(
                      s.description,
                      style: EsText.bodyL.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: EsSpace.s5),
                    Row(
                      children: [
                        _Fact(
                          icon: Icons.place_outlined,
                          label: 'Salle',
                          value: room.name,
                        ),
                        const SizedBox(width: 10),
                        _Fact(
                          icon: Icons.groups_outlined,
                          label: 'Capacité',
                          value: '${s.capacity} pers.',
                        ),
                        const SizedBox(width: 10),
                        _Fact(
                          icon: Icons.schedule_rounded,
                          label: 'Horaires',
                          value: hours,
                        ),
                      ],
                    ),
                    const SizedBox(height: EsSpace.s5),
                    if (s.professorPriority) ...[
                      const InfoBanner(
                        icon: Icons.school_outlined,
                        title: 'Priorité aux enseignants',
                        text: 'Les demandes des étudiants restent possibles.',
                      ),
                      const SizedBox(height: EsSpace.s3),
                    ],
                    if (shared.isNotEmpty) ...[
                      InfoBanner(
                        icon: Icons.meeting_room_outlined,
                        title: 'Salle partagée',
                        text: 'Avec ${shared.join(', ')}. Une réservation '
                            'bloque toute la salle.',
                      ),
                      const SizedBox(height: EsSpace.s3),
                    ],
                    const SectionTitle('Ce que permet ce studio'),
                    const SizedBox(height: EsSpace.s2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final cap in s.capabilities)
                          _CapChip(icon: capabilityIcon(cap), label: cap.label),
                        _CapChip(
                          icon: Icons.volume_off_outlined,
                          label: 'Isolation ${s.isolation}/5',
                        ),
                      ],
                    ),
                    if (s.included.isNotEmpty) ...[
                      const SizedBox(height: EsSpace.s4),
                      const SectionTitle('Inclus avec le studio'),
                      const SizedBox(height: EsSpace.s2),
                      EsCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < s.included.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: c.successBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 15,
                                      color: c.successText,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      s.included[i],
                                      style: EsText.bodyM
                                          .copyWith(color: c.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: EsSpace.s4),
                    const SectionTitle('Prochains créneaux libres'),
                    const SizedBox(height: EsSpace.s2),
                    if (free.isEmpty)
                      Text(
                        'Aucun créneau libre dans les 30 prochains jours.',
                        style: EsText.bodyM.copyWith(color: c.textSecondary),
                      )
                    else
                      Row(
                        children: [
                          for (var i = 0; i < free.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(
                              child: EsCard(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 8,
                                ),
                                onTap: () => context.push(
                                  '/book/${s.id}?day='
                                  '${free[i].start.toIso8601String()}',
                                ),
                                semanticLabel: 'Réserver '
                                    '${Fmt.relativeDay(free[i].start, w.now)} '
                                    'à ${Fmt.time(free[i].start)}',
                                child: Column(
                                  children: [
                                    Text(
                                      Fmt.time(free[i].start),
                                      style: EsText.numeric.copyWith(
                                        color: c.textPrimary,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      Fmt.relativeDay(free[i].start, w.now),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: EsText.bodyS
                                          .copyWith(color: c.successText),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: EsSpace.page),
        child: EsButton(
          'Réserver ce studio',
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: () => context.push('/book/${s.id}'),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Expanded(
      child: EsCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Icon(icon, size: 20, color: c.onLilac),
            const SizedBox(height: 6),
            Text(label, style: EsText.bodyS.copyWith(color: c.textSecondary)),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: EsText.titleS.copyWith(color: c.textPrimary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapChip extends StatelessWidget {
  const _CapChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(EsRadius.pill),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c.onLilac),
          const SizedBox(width: 6),
          Text(label, style: EsText.labelS.copyWith(color: c.textPrimary)),
        ],
      ),
    );
  }
}
