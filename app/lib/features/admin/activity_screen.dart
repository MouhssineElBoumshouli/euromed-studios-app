import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../data/admin_state.dart';
import '../../data/app_state.dart';
import '../../data/projects_state.dart';
import '../../domain/activity.dart';
import '../../domain/people.dart';
import '../../core/l10n/text.dart';

/// I8 · Activity log: who did what, and when (P-11). Admins only.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  ActivityCategory? category;
  final search = TextEditingController();
  int shown = 60;

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() => shown = 60));
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final me = ref.watch(currentPersonProvider);
    final w = ref.watch(worldProvider);
    final top = MediaQuery.paddingOf(context).top;

    Widget frame(List<Widget> children) => Scaffold(
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              EsSpace.page,
              top + EsSpace.s3,
              EsSpace.page,
              EsSpace.s8,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: EsBackButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/admin'),
                ),
              ),
              const SizedBox(height: EsSpace.s4),
              Text(
                'Journal d’activité',
                style: EsText.displayL.copyWith(color: c.textPrimary),
              ),
              Text(
                'Qui a fait quoi, et quand. Les actions d’administration sont '
                'enregistrées et ne peuvent pas être modifiées.',
                style: EsText.bodyM.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: EsSpace.s4),
              ...children,
            ],
          ),
        );

    if (!me.has(Role.admin)) {
      return frame(const [
        EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Accès réservé',
          message: 'Le journal d’activité est réservé à l’administration.',
        ),
      ]);
    }

    final all = activityFeed(
      bookings: w.bookings,
      projects: ref.watch(projectsProvider).projects,
      audit: ref.watch(adminProvider).audit,
      describe: (b) => '${b.reference} · ${studioById(b.studioId).name} · '
          '${Fmt.shortDay(b.start)} ${Fmt.time(b.start)}',
      nameOf: (id) => personById(id).fullName,
    );
    final q = _fold(search.text.trim());
    final items = [
      for (final i in all)
        if ((category == null || i.category == category) &&
            (q.isEmpty ||
                _fold(i.title).contains(q) ||
                _fold(i.detail).contains(q) ||
                (i.actorId != null &&
                    _fold(personById(i.actorId!).fullName).contains(q))))
          i,
    ];
    final page = items.take(shown).toList();

    // Group by day.
    final groups = <DateTime, List<ActivityItem>>{};
    for (final i in page) {
      groups.putIfAbsent(DateTime(i.at.year, i.at.month, i.at.day), () => [])
          .add(i);
    }

    return frame([
      TextField(
        controller: search,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search_rounded),
          hintText: tr('Rechercher une personne, une référence, un projet'),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: Text('Tout · ${all.length}'),
            selected: category == null,
            onSelected: (_) => setState(() => category = null),
          ),
          for (final cat in ActivityCategory.values)
            ChoiceChip(
              label: Text(
                '${cat.label} · '
                '${all.where((i) => i.category == cat).length}',
              ),
              selected: category == cat,
              onSelected: (_) => setState(() => category = cat),
            ),
        ],
      ),
      const SizedBox(height: EsSpace.s3),
      if (items.isEmpty)
        EmptyState(
          icon: Icons.manage_search_rounded,
          title: 'Aucune activité',
          message: q.isEmpty && category == null
              ? 'Les actions apparaîtront ici au fil de l’eau.'
              : 'Rien ne correspond à cette recherche.',
        ),
      for (final g in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Overline(
            g.key == DateTime(w.now.year, w.now.month, w.now.day)
                ? 'Aujourd’hui'
                : Fmt.longDay(g.key),
          ),
        ),
        EsCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < g.value.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 62, color: c.border),
                _Row(item: g.value[i]),
              ],
            ],
          ),
        ),
      ],
      if (items.length > shown)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
            child: TextButton(
              onPressed: () => setState(() => shown += 60),
              child: Text('Afficher plus (${items.length - shown} restantes)'),
            ),
          ),
        ),
    ]);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});
  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final actor = item.actorId == null ? null : personById(item.actorId!);
    final (icon, bg, fg) = switch (item.category) {
      ActivityCategory.booking => (Icons.event_note_outlined, c.reviewBg, c.reviewText),
      ActivityCategory.project => (Icons.layers_outlined, c.lilac, c.onLilac),
      ActivityCategory.admin => (Icons.admin_panel_settings_outlined, c.pendingBg, c.pendingText),
    };
    return InkWell(
      onTap: item.route == null ? null : () => context.push(item.route!),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(icon, size: 34, bg: bg, fg: fg),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: EsText.titleS.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.detail,
                    style: EsText.bodyS.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    actor == null ? 'Système' : actor.fullName,
                    style: EsText.labelS.copyWith(color: c.textDisabled),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Fmt.time(item.at),
              style: EsText.labelS.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
