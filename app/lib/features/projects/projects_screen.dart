import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/app_state.dart';
import '../../data/projects_state.dart';
import '../../domain/projects.dart';
import '../../domain/rules/projects.dart';
import '../notifications/notifications_screen.dart';
import 'project_sections.dart';
import 'project_widgets.dart';
import '../../core/l10n/text.dart';

/// F1 · Projects: mine and the ones I'm invited to, by stage.
/// On a computer, a board with one column per stage (R-26).
class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  /// null = every stage.
  ProjectStage? filter;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final me = ref.watch(currentPersonProvider);
    final projects = ref.watch(myProjectsProvider);
    final wide = isWide(context);
    final staff = supervisesProjects(me);
    final canCreate = canCreateProject(me);

    final header = BrandHeader(
      title: 'Projets',
      subtitle: staff
          ? 'Tous les projets en cours aux studios'
          : 'Du script à la livraison',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!wide) ...[const NoticeBell(), const SizedBox(width: 8)],
          if (canCreate)
            EsButton(
              'Nouveau',
              icon: Icons.add_rounded,
              expand: false,
              size: EsButtonSize.medium,
              onPressed: () => context.push('/projects/new'),
            ),
        ],
      ),
    );

    final invites = ref.watch(myInvitesProvider);
    final inviteBlock = invites.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.fromLTRB(
              EsSpace.page,
              0,
              EsSpace.page,
              EsSpace.s4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Overline(
                  invites.length == 1
                      ? 'Une invitation'
                      : '${invites.length} invitations',
                ),
                const SizedBox(height: 8),
                for (final i in invites)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InvitationCard(invite: i),
                  ),
              ],
            ),
          );

    final empty = EmptyState(
      icon: Icons.layers_outlined,
      title: 'Aucun projet pour l’instant',
      message: canCreate
          ? 'Créez un projet pour suivre un podcast, un MOOC ou un tournage, '
              'du script jusqu’à la livraison.'
          : 'Les projets des demandeurs apparaîtront ici.',
      action: canCreate
          ? EsButton(
              'Créer un projet',
              icon: Icons.add_rounded,
              expand: false,
              onPressed: () => context.push('/projects/new'),
            )
          : null,
    );

    if (wide) {
      return ListView(
        padding: EdgeInsets.only(bottom: tabBarSpace(context)),
        children: [
          header,
          inviteBlock,
          if (projects.isEmpty)
            empty
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: EsSpace.page),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in ProjectStage.values) ...[
                    if (s.index > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _Column(
                        stage: s,
                        projects: [
                          for (final p in projects)
                            if (p.stage == s) p,
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    }

    final shown = [
      for (final p in projects)
        if (filter == null || p.stage == filter) p,
    ];
    return ListView(
      padding: EdgeInsets.only(bottom: tabBarSpace(context)),
      children: [
        header,
        inviteBlock,
        if (projects.isEmpty)
          empty
        else ...[
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: EsSpace.page),
              children: [
                _FilterChip(
                  label: 'Tous · ${projects.length}',
                  selected: filter == null,
                  onTap: () => setState(() => filter = null),
                ),
                for (final s in ProjectStage.values)
                  _FilterChip(
                    label: '${s.label} · '
                        '${projects.where((p) => p.stage == s).length}',
                    selected: filter == s,
                    onTap: () => setState(() => filter = s),
                  ),
              ],
            ),
          ),
          const SizedBox(height: EsSpace.s3),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(EsSpace.page),
              child: Text(
                'Aucun projet à cette étape.',
                textAlign: TextAlign.center,
                style: EsText.bodyM.copyWith(color: c.textSecondary),
              ),
            ),
          for (var i = 0; i < shown.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                EsSpace.page,
                0,
                EsSpace.page,
                EsSpace.s3,
              ),
              child: FadeInUp(
                index: i,
                child: ProjectCard(project: shown[i]),
              ),
            ),
        ],
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.stage, required this.projects});
  final ProjectStage stage;
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.bgSubtle,
        borderRadius: BorderRadius.circular(EsRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${stage.index + 1}. ${stage.label}',
                    style: EsText.titleS.copyWith(color: c.textPrimary),
                  ),
                ),
                Tag(
                  label: '${projects.length}',
                  background: c.bgSurface,
                  foreground: c.textSecondary,
                ),
              ],
            ),
          ),
          if (projects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Rien ici',
                textAlign: TextAlign.center,
                style: EsText.bodyS.copyWith(color: c.textDisabled),
              ),
            ),
          for (final p in projects)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ProjectCard(project: p),
            ),
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
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        labelStyle: EsText.labelS.copyWith(
          color: selected ? c.onActionPrimary : c.textPrimary,
        ),
        selectedColor: c.actionPrimary,
        backgroundColor: c.bgSurface,
        side: BorderSide(color: selected ? c.actionPrimary : c.border),
        shape: const StadiumBorder(),
      ),
    );
  }
}
