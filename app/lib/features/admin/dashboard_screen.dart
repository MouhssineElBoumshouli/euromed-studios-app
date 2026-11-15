import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell.dart';
import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/layout.dart';
import '../../data/app_state.dart';
import '../../data/demo_world.dart';
import '../../data/projects_state.dart';
import '../../domain/bookings.dart';
import '../../domain/people.dart';
import '../../domain/projects.dart';
import '../../domain/rules/projects.dart';
import '../../domain/rules/stats.dart';
import '../notifications/notifications_screen.dart';

/// I1 · Pilotage: how the studios are doing this week, and what needs
/// attention now. For the admin and the studio manager.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final me = ref.watch(currentPersonProvider);
    final projects = ref.watch(projectsProvider).projects;
    final from = reportWeek(w.now, w.policy);
    final thisWeek = !from.isAfter(w.now);
    final to = DateTime(from.year, from.month, from.day + 7);
    final loads = occupancy(
      DemoWorld.studios,
      w.bookings,
      w.policy,
      from,
      to,
      maintenance: w.maintenance,
    )..sort((a, b) => b.rate.compareTo(a.rate));
    final rate = overallRate(loads);
    final pending = pendingSummary(w.bookings);
    final times = approvalTimes(w.bookings, w.now);
    final absences = noShowRate(w.bookings, w.now);
    final byType = requestsByType(w.bookings, w.now);
    final days = dailyLoad(w.bookings, w.now, w.policy);
    final stages = projectsByStage(projects);
    final toCheck = [
      for (final p in projects)
        if (p.stage == ProjectStage.postProduction &&
            p.postStatus == PostStatus.readyForCheck)
          p,
    ];
    final oldest = [
      for (final b in w.bookings)
        if (b.status.isPending && !b.isPrivate) b,
    ]..sort((a, b) => a.history.last.at.compareTo(b.history.last.at));
    final closures = [
      for (final m in w.maintenance)
        if (m.end.isAfter(w.now)) m,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final wide = isWide(context);

    if (!(me.has(Role.admin) || me.has(Role.studioManager))) {
      return const EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Accès réservé',
        message: 'Le pilotage est réservé à la Direction des Studios et à '
            'l’administration.',
      );
    }

    String hours(Duration d) {
      if (d.inHours < 24) return Fmt.duration(d);
      final days = d.inMinutes / (60 * 24);
      return '${days.toStringAsFixed(1).replaceAll('.', ',')} j';
    }

    final kpis = [
      _Kpi(
        icon: Icons.donut_large_rounded,
        label: 'Occupation',
        value: '${(rate * 100).round()} %',
        sub: thisWeek
            ? 'des heures d’ouverture, cette semaine'
            : 'des heures d’ouverture, semaine prochaine',
        tone: _Tone.brand,
      ),
      _Kpi(
        icon: Icons.inbox_outlined,
        label: 'En attente',
        value: '${pending.total}',
        sub: pending.total == 0
            ? 'Aucune demande'
            : '${pending.atEntity} niveau 1 · ${pending.atStudio} niveau 2',
        tone: pending.total > 0 ? _Tone.warn : _Tone.ok,
        onTap: () => context.go('/validations'),
      ),
      _Kpi(
        icon: Icons.timer_outlined,
        label: 'Délai de validation',
        value: times == null ? '—' : hours(times.median),
        sub: times == null
            ? 'Pas encore de validation sur 30 jours'
            : 'médiane · ${times.count} demande'
                '${times.count > 1 ? 's' : ''} validée'
                '${times.count > 1 ? 's' : ''} (30 j)',
        tone: _Tone.neutral,
      ),
      _Kpi(
        icon: Icons.person_off_outlined,
        label: 'Absences',
        value:
            absences == null ? '—' : '${(absences.rate * 100).round()} %',
        sub: absences == null
            ? 'Aucune séance passée sur 30 jours'
            : '${absences.noShows} sur ${absences.held} séance'
                '${absences.held > 1 ? 's' : ''} (30 j)',
        tone: absences != null && absences.rate > 0.15
            ? _Tone.warn
            : _Tone.neutral,
      ),
    ];

    final occupancyCard = _Panel(
      title: 'Occupation par salle',
      subtitle: '${thisWeek ? 'Cette semaine' : 'Semaine prochaine'} · '
          'à partir du ${Fmt.dayMonth(from)}',
      child: Column(
        children: [
          for (final l in loads) _LoadRow(load: l),
        ],
      ),
    );
    final weekCard = _Panel(
      title: 'Les prochains jours d’ouverture',
      subtitle: 'Séances validées et demandes en attente',
      child: _DayBars(days: days, now: w.now),
    );
    final typeCard = _Panel(
      title: 'Demandes par profil',
      subtitle: '30 derniers jours',
      child: _TypeBars(counts: byType),
    );
    final projectsCard = _Panel(
      title: 'Projets',
      subtitle: '${projects.length} au total',
      action: TextButton(
        onPressed: () => context.go('/projects'),
        child: const Text('Voir'),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in ProjectStage.values)
            _StageCount(stage: s, count: stages[s] ?? 0),
        ],
      ),
    );
    final attention = _Panel(
      title: 'À traiter maintenant',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (oldest.isEmpty && toCheck.isEmpty && closures.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Tout est à jour.',
                style: EsText.bodyM.copyWith(color: c.textSecondary),
              ),
            ),
          for (final b in oldest.take(4))
            _AttentionRow(
              icon: Icons.inbox_outlined,
              tone: b.status == BookingStatus.pendingEntity
                  ? c.pendingText
                  : c.reviewText,
              title: '${personById(b.requesterId).fullName} · '
                  '${studioById(b.studioId).name}',
              detail: '${b.status == BookingStatus.pendingEntity ? 'Niveau 1' : 'Niveau 2'}'
                  ' · attend depuis '
                  '${Fmt.duration(w.now.difference(b.history.last.at))}',
              onTap: () => context.push('/validations/${b.id}'),
            ),
          for (final p in toCheck)
            _AttentionRow(
              icon: Icons.fact_check_outlined,
              tone: c.successText,
              title: p.title,
              detail: isTechTeam(me)
                  ? 'Prêt pour le contrôle qualité'
                  : 'En attente du contrôle qualité',
              onTap: () => context.push('/projects/${p.id}'),
            ),
          for (final m in closures.take(3))
            _AttentionRow(
              icon: Icons.build_outlined,
              tone: c.dangerText,
              title: 'Maintenance · ${_roomName(m.roomId)}',
              detail: '${Fmt.shortDay(m.start)} ${Fmt.range(m.start, m.end)}'
                  ' · ${m.reason}',
            ),
        ],
      ),
    );

    return ListView(
      padding: EdgeInsets.only(bottom: tabBarSpace(context)),
      children: [
        BrandHeader(
          title: 'Pilotage',
          subtitle: 'Mis à jour à ${Fmt.time(w.now)}',
          trailing: wide ? null : const NoticeBell(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EsSpace.page),
          child: LayoutBuilder(
            builder: (_, box) {
              final cols = box.maxWidth >= 1000 ? 4 : 2;
              const gap = 12.0;
              final tileW = (box.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final k in kpis) SizedBox(width: tileW, child: k),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: EsSpace.s4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EsSpace.page),
          child: LayoutBuilder(
            builder: (_, box) {
              if (box.maxWidth < 900) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    attention,
                    occupancyCard,
                    weekCard,
                    typeCard,
                    projectsCard,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [occupancyCard, weekCard, typeCard],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [attention, projectsCard],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static String _roomName(String roomId) {
    final names = [
      for (final s in DemoWorld.studios)
        if (s.roomId == roomId) s.name,
    ];
    return names.isEmpty ? roomId : names.join(' / ');
  }
}

enum _Tone { brand, ok, warn, neutral }

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.tone,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final _Tone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (bg, fg) = switch (tone) {
      _Tone.brand => (c.lilac, c.onLilac),
      _Tone.ok => (c.successBg, c.successText),
      _Tone.warn => (c.pendingBg, c.pendingText),
      _Tone.neutral => (c.bgSubtle, c.textSecondary),
    };
    return EsCard(
      onTap: onTap,
      semanticLabel: '$label : $value. $sub',
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon, size: 34, bg: bg, fg: fg),
              const Spacer(),
              if (onTap != null)
                Icon(Icons.arrow_forward_rounded,
                    size: 18, color: c.textDisabled),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: EsText.displayL.copyWith(color: c.textPrimary, height: 1),
          ),
          const SizedBox(height: 4),
          Text(label, style: EsText.titleS.copyWith(color: c.textPrimary)),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EsText.bodyS.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: EsCard(
        padding: const EdgeInsets.all(16),
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
                        title,
                        style: EsText.titleL.copyWith(color: c.textPrimary),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style:
                              EsText.bodyS.copyWith(color: c.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _LoadRow extends StatelessWidget {
  const _LoadRow({required this.load});
  final RoomLoad load;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final pct = (load.rate * 100).round();
    final h = (load.bookedMinutes / 60).toStringAsFixed(0);
    final open = (load.openMinutes / 60).toStringAsFixed(0);
    return Semantics(
      label: '${load.name} : $pct %, $h heures sur $open',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 170,
              child: Text(
                load.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: EsText.bodyM.copyWith(color: c.textPrimary),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    Container(height: 10, color: c.bgSubtle),
                    FractionallySizedBox(
                      widthFactor: load.rate.toDouble(),
                      child: Container(height: 10, color: c.actionPrimary),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 86,
              child: Text(
                '$pct % · $h h',
                textAlign: TextAlign.right,
                style: EsText.labelS.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBars extends StatelessWidget {
  const _DayBars({required this.days, required this.now});
  final List<({DateTime day, int validated, int waiting})> days;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final top = days.fold(
      1,
      (m, d) => d.validated + d.waiting > m ? d.validated + d.waiting : m,
    );
    const maxH = 110.0;
    return Column(
      children: [
        SizedBox(
          height: maxH + 44,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in days)
                Expanded(
                  child: Semantics(
                    label: '${Fmt.longDay(d.day)} : ${d.validated} '
                        'validées, ${d.waiting} en attente',
                    excludeSemantics: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${d.validated + d.waiting}',
                          style: EsText.labelS
                              .copyWith(color: c.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 22,
                          height: maxH * d.waiting / top,
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: BorderRadius.vertical(
                              top: const Radius.circular(4),
                              bottom: Radius.circular(d.validated == 0 ? 4 : 0),
                            ),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: maxH * d.validated / top,
                          decoration: BoxDecoration(
                            color: c.actionPrimary,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(d.waiting == 0 ? 4 : 0),
                              bottom: const Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          Fmt.shortDay(d.day).split(' ').first,
                          style: EsText.labelS.copyWith(
                            color: d.day.day == now.day
                                ? c.textPrimary
                                : c.textSecondary,
                            fontWeight: d.day.day == now.day
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Dot(color: c.actionPrimary, label: 'Validées'),
            const SizedBox(width: 16),
            _Dot(
              color: c.accent,
              label: 'En attente',
            ),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: EsText.bodyS.copyWith(color: context.es.textSecondary),
          ),
        ],
      );
}

class _TypeBars extends StatelessWidget {
  const _TypeBars({required this.counts});
  final Map<RequesterType, int> counts;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final top = counts.values.fold(1, (m, v) => v > m ? v : m);
    final total = counts.values.fold(0, (s, v) => s + v);
    if (total == 0) {
      return Text(
        'Aucune demande sur la période.',
        style: EsText.bodyM.copyWith(color: c.textSecondary),
      );
    }
    return Column(
      children: [
        for (final e in counts.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    e.key.label,
                    style: EsText.bodyM.copyWith(color: c.textPrimary),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: e.value == 0 ? 0.01 : e.value / top,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${e.value}',
                    textAlign: TextAlign.right,
                    style: EsText.labelS.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StageCount extends StatelessWidget {
  const _StageCount({required this.stage, required this.count});
  final ProjectStage stage;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.bgSubtle,
        borderRadius: BorderRadius.circular(EsRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: EsText.displayM.copyWith(color: c.textPrimary, height: 1),
          ),
          const SizedBox(height: 2),
          Text(stage.label,
              style: EsText.bodyS.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.tone,
    required this.title,
    required this.detail,
    this.onTap,
  });
  final IconData icon;
  final Color tone;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(EsRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tone),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EsText.titleS.copyWith(color: c.textPrimary),
                  ),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: EsText.bodyS.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: c.textDisabled),
          ],
        ),
      ),
    );
  }
}
