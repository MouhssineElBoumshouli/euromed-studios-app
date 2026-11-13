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
import '../../data/demo_world.dart';
import '../../domain/rules/availability.dart';
import '../../domain/studios.dart';

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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: c.bgBrand,
            foregroundColor: c.textOnBrand,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filled(
                tooltip: 'Retour',
                style: IconButton.styleFrom(
                  backgroundColor: c.bgSurface,
                  foregroundColor: c.textPrimary,
                ),
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 20,
                bottom: 16,
                end: 20,
              ),
              title: Text(
                s.name.toUpperCase(),
                style: EsText.displayM.copyWith(color: c.textOnBrand),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(s.photo, fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.35, 1],
                        colors: [
                          c.bgBrand.withValues(alpha: 0),
                          c.bgBrand.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            sliver: SliverList.list(
              children: [
                Overline('${s.zone.label} · ${room.name}'),
                const SizedBox(height: EsSpace.s3),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Tag(
                      label: 'Isolation ${'★' * s.isolation}',
                      background: c.bgSurface,
                      foreground: c.textPrimary,
                    ),
                    for (final cap in s.capabilities)
                      Tag(
                        label: cap.label,
                        background: c.bgSurface,
                        foreground: c.textPrimary,
                      ),
                  ],
                ),
                const SizedBox(height: EsSpace.s4),
                Text(
                  s.description,
                  style: EsText.bodyM.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: EsSpace.s4),
                if (s.professorPriority) ...[
                  const InfoBanner(
                    icon: Icons.school_outlined,
                    text: 'Priorité aux enseignants pour ce studio. Les '
                        'demandes des étudiants restent possibles.',
                  ),
                  const SizedBox(height: EsSpace.s3),
                ],
                if (shared.isNotEmpty) ...[
                  InfoBanner(
                    icon: Icons.meeting_room_outlined,
                    text: 'Salle partagée avec ${shared.join(', ')}. '
                        'Une réservation bloque toute la salle.',
                  ),
                  const SizedBox(height: EsSpace.s4),
                ],
                if (s.included.isNotEmpty)
                  EsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inclus avec le studio',
                          style: EsText.titleS.copyWith(color: c.textPrimary),
                        ),
                        const SizedBox(height: EsSpace.s2),
                        for (final item in s.included)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: c.successText,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: EsText.bodyM.copyWith(
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          'Capacité : ${s.capacity} personnes',
                          style: EsText.bodyS.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: EsSpace.s4),
                const SectionTitle('Prochains créneaux libres'),
                if (free.isEmpty)
                  Text(
                    'Aucun créneau libre dans les 30 prochains jours.',
                    style: EsText.bodyM.copyWith(color: c.textSecondary),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in free)
                        ActionChip(
                          label: Text(
                            '${Fmt.relativeDay(f.start, w.now)} ${Fmt.time(f.start)}',
                          ),
                          onPressed: () => context.push(
                            '/book/${s.id}?day=${f.start.toIso8601String()}',
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: c.bgSurface,
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: EsButton(
            'Réserver ce studio',
            onPressed: () => context.push('/book/${s.id}'),
          ),
        ),
      ),
    );
  }
}
