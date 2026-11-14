import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/app_state.dart';
import '../../data/projects_state.dart';
import '../../domain/bookings.dart';
import '../../domain/projects.dart';

/// Colour and icon for each project type.
(Color, Color, IconData) typeStyle(EsColors c, ProjectType t) => switch (t) {
      ProjectType.teaching => (c.reviewBg, c.reviewText, Icons.school_outlined),
      ProjectType.research => (c.lilac, c.onLilac, Icons.science_outlined),
      ProjectType.culture => (
          c.pendingBg,
          c.pendingText,
          Icons.theater_comedy_outlined,
        ),
      ProjectType.communication => (
          c.successBg,
          c.successText,
          Icons.campaign_outlined,
        ),
    };

class TypeTag extends StatelessWidget {
  const TypeTag(this.type, {super.key});
  final ProjectType type;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = typeStyle(context.es, type);
    return Tag(label: type.label, background: bg, foreground: fg, icon: icon);
  }
}

/// Four small bars: done, current, still to come.
class StageBar extends StatelessWidget {
  const StageBar(this.stage, {super.key, this.showLabel = true});
  final ProjectStage stage;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Semantics(
      label: 'Étape ${stage.index + 1} sur 4 : ${stage.label}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final s in ProjectStage.values) ...[
                if (s.index > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: s.index <= stage.index ? c.actionPrimary : c.lilac,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (showLabel) ...[
            const SizedBox(height: 6),
            Text(
              '${stage.index + 1}/4 · ${stage.label}',
              style: EsText.labelS.copyWith(color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Owner and collaborators as overlapping initials.
class PeopleStack extends StatelessWidget {
  const PeopleStack(this.ids, {super.key, this.size = 34});
  final List<String> ids;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final shown = ids.take(4).toList();
    return Semantics(
      label: shown.map((id) => personById(id).fullName).join(', '),
      excludeSemantics: true,
      child: SizedBox(
        height: size,
        width: size + (shown.length - 1) * size * 0.65,
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++)
              Positioned(
                left: i * size * 0.65,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.bgSurface, width: 2),
                  ),
                  child: Avatar(personById(shown[i]).initials, size: size - 4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A project in a list or a board column.
class ProjectCard extends ConsumerWidget {
  const ProjectCard({super.key, required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final files = ref.watch(projectsProvider).filesOf(project.id);
    final sessions = [
      for (final b in w.bookings)
        if (b.projectId == project.id && !b.isPrivate) b,
    ];
    final next = sessions
        .where(
          (b) =>
              b.end.isAfter(w.now) &&
              (b.status == BookingStatus.approved || b.status.isPending),
        )
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final owner = personById(project.ownerId);

    return EsCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/projects/${project.id}'),
      semanticLabel: '${project.title}, ${project.type.label}, '
          'étape ${project.stage.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TypeTag(project.type),
              const Spacer(),
              PeopleStack([project.ownerId, ...project.memberIds]),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            project.title,
            style: EsText.titleM.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            'Porté par ${owner.fullName}',
            style: EsText.bodyS.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 12),
          StageBar(project.stage),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Meta(
                Icons.description_outlined,
                '${files.length} document${files.length > 1 ? 's' : ''}',
              ),
              _Meta(
                Icons.event_outlined,
                '${sessions.length} séance${sessions.length > 1 ? 's' : ''}',
              ),
              if (next.isNotEmpty)
                _Meta(
                  Icons.schedule_rounded,
                  'Prochaine : ${Fmt.relativeDay(next.first.start, w.now)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: c.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: EsText.bodyS.copyWith(color: c.textSecondary)),
      ],
    );
  }
}
