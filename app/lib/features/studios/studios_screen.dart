import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../app/shell.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/app_state.dart';
import '../../data/demo_world.dart';
import '../../data/selectors.dart';
import '../../domain/studios.dart';

/// Selected capability filter on the studios list (null = all).
final _filterProvider = StateProvider.autoDispose<Capability?>((ref) => null);
final _queryProvider = StateProvider.autoDispose<String>((ref) => '');

/// C1 · Studios, grouped by zone (R-01), with live status (R-30).
class StudiosScreen extends ConsumerWidget {
  const StudiosScreen({super.key});

  static const _filters = [
    Capability.teleprompter,
    Capability.greenScreen,
    Capability.multicam,
    Capability.streaming,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final filter = ref.watch(_filterProvider);
    final query = ref.watch(_queryProvider).trim().toLowerCase();
    final live = {for (final l in liveStatus(w)) l.studio.id: l};

    bool matches(Studio s) =>
        s.bookable &&
        (filter == null || s.capabilities.contains(filter)) &&
        (query.isEmpty ||
            s.name.toLowerCase().contains(query) ||
            s.description.toLowerCase().contains(query));

    final groups = [
      for (final z in Zone.values)
        (z, DemoWorld.studios.where((s) => s.zone == z && matches(s)).toList()),
    ].where((g) => g.$2.isNotEmpty);

    final total = DemoWorld.studios.where((s) => s.bookable).length;
    final freeNow = live.values.where((l) => l.state == LiveState.free).length;

    return BlobBackground(
      variant: 1,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: BrandHeader(
              title: 'Studios',
              subtitle: '$total espaces · $freeNow libres maintenant',
              bottomPadding: EsSpace.s3,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: EsSpace.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(EsRadius.pill),
                      boxShadow: esShadow(c),
                    ),
                    child: TextField(
                      onChanged: (v) =>
                          ref.read(_queryProvider.notifier).state = v,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un studio…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(EsRadius.pill),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(EsRadius.pill),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(EsRadius.pill),
                          borderSide:
                              BorderSide(color: c.actionPrimary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: EsSpace.s3),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      clipBehavior: Clip.none,
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(
                          label: 'Tous',
                          selected: filter == null,
                          onTap: () =>
                              ref.read(_filterProvider.notifier).state = null,
                        ),
                        for (final f in _filters)
                          _FilterChip(
                            label: f.label,
                            selected: filter == f,
                            onTap: () => ref
                                .read(_filterProvider.notifier)
                                .state = filter == f ? null : f,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (groups.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Aucun studio ne correspond',
                message: 'Essayez un autre mot ou retirez le filtre.',
              ),
            ),
          for (final (zone, studios) in groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  EsSpace.page,
                  EsSpace.s5,
                  EsSpace.page,
                  EsSpace.s3,
                ),
                child: Row(
                  children: [
                    Overline(zone.label),
                    const SizedBox(width: 8),
                    Expanded(child: Divider(color: c.border)),
                  ],
                ),
              ),
            ),
            SliverList.separated(
              itemCount: studios.length,
              separatorBuilder: (_, __) => const SizedBox(height: EsSpace.s4),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: EsSpace.page),
                child: FadeInUp(
                  index: i,
                  child: StudioCard(
                    studio: studios[i],
                    live: live[studios[i].id],
                    onTap: () => context.push('/studios/${studios[i].id}'),
                  ),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: tabBarSpace(context))),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Padding(
      padding: const EdgeInsets.only(right: EsSpace.s2),
      child: Semantics(
        selected: selected,
        button: true,
        child: AnimatedContainer(
          duration: EsMotion.fast,
          decoration: BoxDecoration(
            color: selected ? c.actionPrimary : c.bgSurface,
            borderRadius: BorderRadius.circular(EsRadius.pill),
            border: Border.all(color: selected ? c.actionPrimary : c.border),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                label,
                style: EsText.labelS.copyWith(
                  color: selected ? c.onActionPrimary : c.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData capabilityIcon(Capability c) => switch (c) {
      Capability.audioPro => Icons.graphic_eq_rounded,
      Capability.camerasPro => Icons.videocam_outlined,
      Capability.streaming => Icons.sensors_rounded,
      Capability.multicam => Icons.video_camera_back_outlined,
      Capability.greenScreen => Icons.wallpaper_rounded,
      Capability.teleprompter => Icons.subtitles_outlined,
      Capability.postproduction => Icons.movie_edit,
      Capability.teaching => Icons.school_outlined,
    };

/// A studio with its photo, room and what's happening there right now.
class StudioCard extends StatelessWidget {
  const StudioCard({
    super.key,
    required this.studio,
    required this.onTap,
    this.live,
  });
  final Studio studio;
  final LiveRoom? live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final room = DemoWorld.rooms.firstWhere((r) => r.id == studio.roomId);
    final shared = DemoWorld.studios
        .where((s) => s.roomId == studio.roomId && s.id != studio.id)
        .isNotEmpty;
    return EsCard(
      padding: EdgeInsets.zero,
      radius: EsRadius.xl,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 8,
                child: Hero(
                  tag: 'studio-${studio.id}',
                  child: Image.asset(
                    studio.photo,
                    fit: BoxFit.cover,
                    semanticLabel: 'Photo du ${studio.name}',
                  ),
                ),
              ),
              if (live != null)
                Positioned(top: 12, left: 12, child: LiveLabel(live: live!)),
              if (studio.professorPriority)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Tag(
                    label: 'Priorité enseignants',
                    icon: Icons.school_rounded,
                    background: c.bgSurface,
                    foreground: c.textPrimary,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studio.name,
                        style: EsText.titleL.copyWith(color: c.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          room.name,
                          '${studio.capacity} pers.',
                          if (shared) 'Salle partagée',
                        ].join(' · '),
                        style: EsText.bodyS.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final cap in studio.capabilities.take(4))
                            Tooltip(
                              message: cap.label,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: c.bgSubtle,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(
                                  capabilityIcon(cap),
                                  size: 16,
                                  color: c.textSecondary,
                                  semanticLabel: cap.label,
                                ),
                              ),
                            ),
                          if (studio.capabilities.length > 4)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: c.bgSubtle,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                '+${studio.capabilities.length - 4}',
                                style: EsText.labelS
                                    .copyWith(color: c.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.lilac,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: c.onLilac,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Libre", "Occupé jusqu'à 11:00"… on a frosted pill over the photo.
class LiveLabel extends StatelessWidget {
  const LiveLabel({super.key, required this.live});
  final LiveRoom live;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (String text, Color dot) = switch (live.state) {
      LiveState.free => ('Libre maintenant', c.successFill),
      LiveState.occupied => (
          'Occupé jusqu’à ${Fmt.time(live.until!)}',
          const Color(0xFF7AA2FF),
        ),
      LiveState.maintenance => (
          'Maintenance jusqu’à ${Fmt.time(live.until!)}',
          const Color(0xFFF5B547),
        ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(EsRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiveDot(color: dot, size: 7),
          Text(text, style: EsText.labelS.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
