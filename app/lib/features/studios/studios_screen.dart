import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/layout.dart';
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

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'STUDIOS',
                  style: EsText.displayL.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: EsSpace.s3),
                TextField(
                  onChanged: (v) => ref.read(_queryProvider.notifier).state = v,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un studio',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: EsSpace.s3),
                SizedBox(
                  height: 36,
                  child: ListView(
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
                          onTap: () => ref.read(_filterProvider.notifier).state =
                              filter == f ? null : f,
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Overline(zone.label),
            ),
          ),
          SliverList.separated(
            itemCount: studios.length,
            separatorBuilder: (_, __) => const SizedBox(height: EsSpace.s3),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: StudioCard(
                studio: studios[i],
                live: live[studios[i].id],
                onTap: () => context.push('/studios/${studios[i].id}'),
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: EsSpace.s8)),
      ],
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
        child: Material(
          color: selected ? c.bgBrand : c.bgSurface,
          shape: StadiumBorder(
            side: BorderSide(color: selected ? c.bgBrand : c.border),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                label,
                style: EsText.labelS.copyWith(
                  color: selected ? c.textOnBrand : c.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
        .map((s) => s.name)
        .toList();
    return EsCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 7,
            child: Image.asset(
              studio.photo,
              fit: BoxFit.cover,
              semanticLabel: 'Photo du ${studio.name}',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(EsSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        studio.name,
                        style: EsText.titleM.copyWith(color: c.textPrimary),
                      ),
                    ),
                    if (live != null) LiveLabel(live: live!),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    room.name,
                    '${studio.capacity} pers.',
                    if (studio.professorPriority) 'Priorité enseignants',
                    if (shared.isNotEmpty) 'Salle partagée',
                  ].join(' · '),
                  style: EsText.bodyS.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LiveLabel extends StatelessWidget {
  const LiveLabel({super.key, required this.live});
  final LiveRoom live;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (String text, Color color) = switch (live.state) {
      LiveState.free => ('Libre maintenant', c.successText),
      LiveState.occupied => (
          'Occupé jusqu’à ${Fmt.time(live.until!)}',
          c.textLink,
        ),
      LiveState.maintenance => (
          'Maintenance jusqu’à ${Fmt.time(live.until!)}',
          c.pendingText,
        ),
    };
    return Text(text, style: EsText.labelS.copyWith(color: color));
  }
}
