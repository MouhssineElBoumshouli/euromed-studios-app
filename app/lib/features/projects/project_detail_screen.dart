import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/app_state.dart';
import '../../data/project_service.dart';
import '../../data/projects_state.dart';
import '../../domain/bookings.dart';
import '../../domain/projects.dart';
import '../../domain/rules/projects.dart';
import 'project_sections.dart';
import 'project_widgets.dart';
import '../../data/catalog.dart';
import '../../core/l10n/text.dart';

/// F3–F5 · One project: where it stands, its documents, its sessions,
/// and the step that moves it forward.
class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailState();
}

class _ProjectDetailState extends ConsumerState<ProjectDetailScreen> {
  bool advancing = false;
  bool uploading = false;

  ProjectService get _service => ref.read(projectServiceProvider);

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _advance(Project p) async {
    final next = p.stage.next!;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _ConfirmSheet(
        title: 'Passer en ${tr(next.label).toLowerCase()} ?',
        text: switch (next) {
          ProjectStage.production =>
            'Les documents de préparation sont prêts. Vous pourrez réserver '
                'les séances de tournage ou d’enregistrement.',
          ProjectStage.postProduction =>
            'Les séances sont faites. Le projet passe au montage.',
          _ => '',
        },
        action: 'Passer en ${tr(next.label).toLowerCase()}',
      ),
    );
    if (ok != true) return;
    setState(() => advancing = true);
    try {
      await _service.advance(p.id, by: ref.read(currentPersonProvider));
      _say('Projet passé en ${tr(next.label).toLowerCase()}.');
    } on ProjectProblem catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => advancing = false);
    }
  }

  Future<void> _upload(Project p) async {
    final kind = await showModalBottomSheet<FileKind>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => const _KindSheet(),
    );
    if (kind == null) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedFileExtensions,
      withData: true,
    );
    final f = picked?.files.single;
    if (f == null || f.bytes == null) return;
    if (f.size > maxFileBytes) {
      _say('Fichier trop lourd (20 Mo maximum).');
      return;
    }
    setState(() => uploading = true);
    try {
      await _service.addFile(
        by: ref.read(currentPersonProvider),
        projectId: p.id,
        kind: kind,
        name: f.name,
        bytes: f.bytes!,
      );
      _say('Document ajouté.');
    } on ProjectProblem catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _open(ProjectFile f) async {
    try {
      final url = await _service.linkFor(f);
      if (url == null) {
        _say('Aperçu indisponible en mode démo hors ligne.');
        return;
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ProjectProblem catch (e) {
      _say(e.message);
    }
  }

  Future<void> _remove(ProjectFile f) async {
    try {
      await _service.removeFile(f, by: ref.read(currentPersonProvider));
      _say('Document retiré.');
    } on ProjectProblem catch (e) {
      _say(e.message);
    }
  }

  void _bookFor(Project p) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _StudioSheet(
        onPick: (studioId) {
          Navigator.pop(ctx);
          context.push('/book/$studioId?project=${p.id}');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final me = ref.watch(currentPersonProvider);
    final w = ref.watch(worldProvider);
    final store = ref.watch(projectsProvider);
    final p = store.projects.where((x) => x.id == widget.projectId).firstOrNull;
    final top = MediaQuery.paddingOf(context).top;

    if (p == null && !store.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (p == null || !canSeeProject(me, p)) {
      return Scaffold(
        body: Padding(
          padding: EdgeInsets.fromLTRB(EsSpace.page, top + 12, EsSpace.page, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EsBackButton(onPressed: () => context.go('/projects')),
              const EmptyState(
                icon: Icons.layers_clear_outlined,
                title: 'Projet introuvable',
                message: 'Il a peut-être été retiré, ou vous n’y avez pas '
                    'accès.',
              ),
            ],
          ),
        ),
      );
    }

    final files = store.filesOf(p.id);
    final sessions = [
      for (final b in w.bookings)
        if (b.projectId == p.id && !b.isPrivate) b,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final work = canWorkOn(me, p);
    final mayAdvance = canAdvance(me, p);
    final problem = advanceProblem(p, files, w.bookings);
    final owner = personById(p.ownerId);

    final back = <Widget>[
      Align(
        alignment: Alignment.centerLeft,
        child: EsBackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/projects'),
        ),
      ),
    ];
    final main = <Widget>[
      const SizedBox(height: EsSpace.s4),
      Row(children: [TypeTag(p.type)]),
      const SizedBox(height: 10),
      Text.user(p.title, style: EsText.displayL.copyWith(color: c.textPrimary)),
      if (p.description != null) ...[
        const SizedBox(height: 6),
        Text.user(
          p.description!,
          style: EsText.bodyM.copyWith(color: c.textSecondary),
        ),
      ],
      const SizedBox(height: EsSpace.s3),
      Row(
        children: [
          PeopleStack([p.ownerId, ...p.memberIds], size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              p.memberIds.isEmpty
                  ? 'Porté par ${owner.fullName}'
                  : 'Porté par ${owner.fullName} · '
                      '${p.memberIds.map((m) => personById(m).firstName).join(', ')}',
              style: EsText.bodyS.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
      const SizedBox(height: EsSpace.s5),
      _Pipeline(stage: p.stage),
      const SizedBox(height: EsSpace.s4),
      switch (p.stage) {
        ProjectStage.postProduction => PostProductionPanel(project: p),
        ProjectStage.archived => DeliveryCard(project: p),
        _ => _NextStep(
            project: p,
            problem: problem,
            mayAdvance: mayAdvance,
            busy: advancing,
            onAdvance: () => _advance(p),
          ),
      },
      const SizedBox(height: EsSpace.s5),
      const SectionTitle('Échanges'),
      const SizedBox(height: EsSpace.s2),
      ProjectThread(project: p),
      const SizedBox(height: EsSpace.s5),
    ];
    final aside = <Widget>[
      SectionTitle(
        'Documents',
        actionLabel: work ? 'Ajouter' : null,
        onAction: work && !uploading ? () => _upload(p) : null,
      ),
      const SizedBox(height: EsSpace.s2),
      if (uploading) const LinearProgressIndicator(minHeight: 3),
      if (files.isEmpty)
        InfoBanner(
          icon: Icons.upload_file_rounded,
          title: 'Aucun document',
          text: work
              ? 'Ajoutez le script, le conducteur ou le storyboard. '
                  'Il en faut au moins un avant la production.'
              : 'Le porteur du projet n’a pas encore ajouté de document.',
        )
      else
        EsCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < files.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 64, color: c.border),
                _FileTile(
                  file: files[i],
                  onOpen: () => _open(files[i]),
                  onRemove: p.stage == ProjectStage.preProduction &&
                          (files[i].uploadedBy == me.id || p.ownerId == me.id)
                      ? () => _remove(files[i])
                      : null,
                ),
              ],
            ],
          ),
        ),
      const SizedBox(height: EsSpace.s5),
      SectionTitle(
        'Séances liées',
        actionLabel: work ? 'Réserver' : null,
        onAction: work ? () => _bookFor(p) : null,
      ),
      const SizedBox(height: EsSpace.s2),
      if (sessions.isEmpty)
        InfoBanner(
          icon: Icons.event_outlined,
          title: 'Aucune séance pour ce projet',
          text: work
              ? 'Réservez depuis ce projet : la séance y sera liée '
                  'automatiquement.'
              : 'Les séances réservées pour ce projet apparaîtront ici.',
        )
      else
        EsCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < sessions.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 64, color: c.border),
                _SessionTile(booking: sessions[i]),
              ],
            ],
          ),
        ),
      const SizedBox(height: EsSpace.s5),
      const SectionTitle('Équipe du projet'),
      const SizedBox(height: EsSpace.s2),
      MembersSection(project: p),
      const SizedBox(height: EsSpace.s5),
      const SectionTitle('Historique'),
      const SizedBox(height: EsSpace.s2),
      _History(events: p.history.reversed.toList()),
    ];

    // On a large screen (staff console), documents, sessions, team and
    // history sit in a side column next to the work itself.
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final twoCols = box.maxWidth >= 1000;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              twoCols ? EsSpace.s6 : EsSpace.page,
              top + EsSpace.s3,
              twoCols ? EsSpace.s6 : EsSpace.page,
              EsSpace.s8,
            ),
            children: [
              ...back,
              if (twoCols)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: main,
                      ),
                    ),
                    const SizedBox(width: EsSpace.s6),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: EsSpace.s4),
                          ...aside,
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                ...main,
                const SizedBox(height: EsSpace.s5),
                ...aside,
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The four stages, with the current one highlighted.
class _Pipeline extends StatelessWidget {
  const _Pipeline({required this.stage});
  final ProjectStage stage;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Semantics(
      label: tr('Étape ${stage.index + 1} sur 4 : ${stage.label}'),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in ProjectStage.values)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 2,
                          color: s.index == 0
                              ? Colors.transparent
                              : s.index <= stage.index
                                  ? c.actionPrimary
                                  : c.lilac,
                        ),
                      ),
                      AnimatedContainer(
                        duration: EsMotion.medium,
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: s.index < stage.index
                              ? c.actionPrimary
                              : s == stage
                                  ? c.accent
                                  : c.bgSurface,
                          border: Border.all(
                            color: s.index <= stage.index
                                ? Colors.transparent
                                : c.border,
                          ),
                        ),
                        child: Center(
                          child: s.index < stage.index
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: c.onActionPrimary,
                                )
                              : Text(
                                  '${s.index + 1}',
                                  style: EsText.labelS.copyWith(
                                    color: s == stage
                                        ? Colors.white
                                        : c.textSecondary,
                                  ),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: s.index == ProjectStage.values.length - 1
                              ? Colors.transparent
                              : s.index < stage.index
                                  ? c.actionPrimary
                                  : c.lilac,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.label,
                    textAlign: TextAlign.center,
                    style: EsText.labelS.copyWith(
                      fontSize: 11,
                      color: s == stage ? c.textPrimary : c.textSecondary,
                      fontWeight:
                          s == stage ? FontWeight.w700 : FontWeight.w500,
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

/// What this stage needs, and the button that moves forward.
class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.project,
    required this.problem,
    required this.mayAdvance,
    required this.busy,
    required this.onAdvance,
  });
  final Project project;
  final String? problem;
  final bool mayAdvance;
  final bool busy;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (title, text) = switch (project.stage) {
      ProjectStage.preProduction => (
          'Préparation',
          'Déposez les pièces préparatoires : script, conducteur ou '
              'storyboard.',
        ),
      ProjectStage.production => (
          'Tournage et enregistrement',
          'Réservez vos séances depuis ce projet. Elles s’y ajoutent '
              'automatiquement.',
        ),
      ProjectStage.postProduction => (
          'Montage',
          'Le montage est en cours. Quand il est prêt, l’équipe technique '
              'fait le contrôle qualité avant l’archivage.',
        ),
      ProjectStage.archived => (
          'Projet archivé',
          'Le projet est terminé et validé.',
        ),
    };
    final next = project.stage.next;
    final showButton = mayAdvance && next != null;
    return EsCard(
      color: c.lilac,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Overline('Étape actuelle · ${project.stage.label}'),
          const SizedBox(height: 6),
          Text(title, style: EsText.titleL.copyWith(color: c.textPrimary)),
          const SizedBox(height: 4),
          Text(text, style: EsText.bodyM.copyWith(color: c.textSecondary)),
          if (showButton) ...[
            const SizedBox(height: 14),
            if (problem != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: c.onLilac),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        problem!,
                        style: EsText.bodyS.copyWith(color: c.onLilac),
                      ),
                    ),
                  ],
                ),
              ),
            EsButton(
              'Passer en ${tr(next.label).toLowerCase()}',
              size: EsButtonSize.medium,
              trailingIcon: Icons.arrow_forward_rounded,
              loading: busy,
              onPressed: problem == null && !busy ? onAdvance : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, required this.onOpen, this.onRemove});
  final ProjectFile file;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final kb = file.sizeBytes / 1024;
    final size = kb >= 1024
        ? '${(kb / 1024).toStringAsFixed(1)} Mo'
        : '${kb.round()} Ko';
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            const IconTile(Icons.description_outlined, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EsText.titleS.copyWith(color: c.textPrimary),
                  ),
                  Text(
                    '${file.kind.label} · $size · '
                    '${personById(file.uploadedBy).firstName}, '
                    '${Fmt.relativeDay(file.uploadedAt, DateTime.now())}',
                    style: EsText.bodyS.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: tr('Retirer ${file.name}'),
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline_rounded, color: c.dangerText),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.open_in_new_rounded,
                    size: 18, color: c.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final s = studioById(booking.studioId);
    return InkWell(
      onTap: () => context.push('/bookings/${booking.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            PhotoThumb(s.photo, size: 40, radius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: EsText.titleS.copyWith(color: c.textPrimary),
                  ),
                  Text(
                    '${Fmt.shortDay(booking.start)} · '
                    '${Fmt.range(booking.start, booking.end)}',
                    style: EsText.bodyS.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            StatusChip(booking.status),
          ],
        ),
      ),
    );
  }
}

class _History extends StatefulWidget {
  const _History({required this.events});
  final List<ProjectEvent> events;

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  bool all = false;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final events = widget.events;
    String line(ProjectEvent e) {
      final who = personById(e.actorId).firstName;
      return switch (e.type) {
        ProjectEventType.created => '$who a créé le projet',
        ProjectEventType.stageChanged =>
          '$who a passé le projet en ${(tr(ProjectStage.values.where((s) => s.name == e.detail).firstOrNull?.label) ?? e.detail ?? '').toLowerCase()}',
        ProjectEventType.fileAdded => '$who a ajouté « ${e.detail} »',
        ProjectEventType.fileRemoved => '$who a retiré « ${e.detail} »',
        ProjectEventType.postStatus =>
          '$who : ${(tr(PostStatus.values.where((s) => s.name == e.detail).firstOrNull?.label) ?? e.detail ?? '').toLowerCase()}',
        ProjectEventType.correction => '$who a demandé une correction',
        ProjectEventType.qcPassed =>
          '$who a validé le contrôle qualité et livré le projet',
        ProjectEventType.qcFailed => '$who a renvoyé le montage en correction',
        ProjectEventType.memberInvited =>
          '$who a invité ${personById(e.detail ?? '').fullName}',
        ProjectEventType.memberJoined => '$who a rejoint le projet',
        ProjectEventType.memberLeft => '$who a quitté le projet',
        ProjectEventType.memberRemoved =>
          '$who a retiré ${personById(e.detail ?? '').fullName}',
      };
    }

    return EsCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (final e in all ? events : events.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line(e),
                      style: EsText.bodyS.copyWith(color: c.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Fmt.dateTime(e.at),
                    style: EsText.bodyS.copyWith(color: c.textDisabled),
                  ),
                ],
              ),
            ),
          if (!all && events.length > 6)
            TextButton(
              onPressed: () => setState(() => all = true),
              child: Text('Voir tout l’historique (${events.length})'),
            ),
        ],
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.text,
    required this.action,
  });
  final String title;
  final String text;
  final String action;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(EsSpace.page, 0, EsSpace.page, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: EsText.displayM.copyWith(color: c.textPrimary)),
            const SizedBox(height: 6),
            Text(text, style: EsText.bodyM.copyWith(color: c.textSecondary)),
            const SizedBox(height: 18),
            EsButton(action, onPressed: () => Navigator.pop(context, true)),
            const SizedBox(height: 8),
            EsButton(
              'Annuler',
              style: EsButtonStyle.ghost,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindSheet extends StatelessWidget {
  const _KindSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(EsSpace.page, 0, EsSpace.page, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quel document ?',
              style: EsText.displayM.copyWith(color: c.textPrimary),
            ),
            Text(
              'PDF, Word, texte ou image · 20 Mo maximum',
              style: EsText.bodyS.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 10),
            for (final k in FileKind.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: IconTile(
                  k == FileKind.other
                      ? Icons.attach_file_rounded
                      : Icons.description_outlined,
                  size: 40,
                ),
                title: Text(k.label, style: EsText.titleS),
                subtitle: k.isPreparation
                    ? const Text('Compte comme pièce préparatoire')
                    : null,
                onTap: () => Navigator.pop(context, k),
              ),
          ],
        ),
      ),
    );
  }
}

class _StudioSheet extends StatelessWidget {
  const _StudioSheet({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final studios = [
      for (final s in Catalog.studios)
        if (s.bookable) s
    ];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(EsSpace.page, 0, EsSpace.page, 16),
          children: [
            Text(
              'Quel studio ?',
              style: EsText.displayM.copyWith(color: c.textPrimary),
            ),
            Text(
              'La séance sera liée au projet.',
              style: EsText.bodyS.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 10),
            for (final s in studios)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: PhotoThumb(s.photo, size: 44, radius: 12),
                title: Text(s.name, style: EsText.titleS),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onPick(s.id),
              ),
          ],
        ),
      ),
    );
  }
}
