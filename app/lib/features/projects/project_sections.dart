import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../data/demo_world.dart';
import '../../data/project_service.dart';
import '../../data/projects_state.dart';
import '../../domain/people.dart';
import '../../domain/projects.dart';
import '../../domain/rules/projects.dart';
import '../../data/directory.dart';

/// Runs a project action with a snackbar for the result.
Future<bool> runProjectAction(
  BuildContext context,
  Future<void> Function() action, {
  String? done,
}) async {
  final m = ScaffoldMessenger.of(context);
  try {
    await action();
    if (done != null) m.showSnackBar(SnackBar(content: Text(done)));
    return true;
  } on ProjectProblem catch (e) {
    m.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

(Color, Color, IconData) postStyle(EsColors c, PostStatus s) => switch (s) {
      PostStatus.notStarted => (
          c.neutralBg,
          c.neutralText,
          Icons.hourglass_empty_rounded,
        ),
      PostStatus.inProgress => (
          c.reviewBg,
          c.reviewText,
          Icons.movie_edit,
        ),
      PostStatus.correctionRequested => (
          c.pendingBg,
          c.pendingText,
          Icons.edit_note_rounded,
        ),
      PostStatus.readyForCheck => (
          c.successBg,
          c.successText,
          Icons.fact_check_outlined,
        ),
    };

class PostStatusTag extends StatelessWidget {
  const PostStatusTag(this.status, {super.key});
  final PostStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = postStyle(context.es, status);
    return Tag(label: status.label, background: bg, foreground: fg, icon: icon);
  }
}

// ---------------------------------------------------------------------------
// Post-production (P-07, R-24, R-25)

/// Where editing stands, and what each person can do next.
class PostProductionPanel extends ConsumerStatefulWidget {
  const PostProductionPanel({super.key, required this.project});
  final Project project;

  @override
  ConsumerState<PostProductionPanel> createState() => _PostPanelState();
}

class _PostPanelState extends ConsumerState<PostProductionPanel> {
  bool busy = false;

  Future<void> _set(PostStatus to, String done) async {
    setState(() => busy = true);
    await runProjectAction(
      context,
      () => ref.read(projectServiceProvider).setPostStatus(
            widget.project.id,
            to,
            by: ref.read(currentPersonProvider),
          ),
      done: done,
    );
    if (mounted) setState(() => busy = false);
  }

  Future<void> _check() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => QualityCheckSheet(project: widget.project),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final me = ref.watch(currentPersonProvider);
    final p = widget.project;
    final s = p.postStatus;
    final mine = p.involves(me.id);
    // Who sent it back: the quality check, or someone on the project?
    final lastLoop = p.history.lastWhere(
      (e) =>
          e.type == ProjectEventType.correction ||
          e.type == ProjectEventType.qcFailed,
      orElse: () => ProjectEvent(
        type: ProjectEventType.correction,
        at: p.createdAt,
        actorId: '',
      ),
    );
    final fromCheck = lastLoop.type == ProjectEventType.qcFailed;

    final explain = switch (s) {
      PostStatus.notStarted => mine
          ? 'L’équipe technique va commencer le montage. Vous pourrez suivre '
              'et demander des corrections ici.'
          : 'Le montage n’a pas encore commencé.',
      PostStatus.inProgress => mine
          ? 'Le montage est en cours. Écrivez dans les échanges ci-dessous '
              'pour demander une correction.'
          : 'Le montage est en cours.',
      PostStatus.correctionRequested => switch ((mine, fromCheck)) {
          (true, true) => 'Le contrôle qualité demande des retouches. '
              'L’équipe technique reprend le montage.',
          (true, false) => lastLoop.actorId == me.id
              ? 'Votre demande de correction a été transmise à l’équipe '
                  'technique.'
              : '${personById(lastLoop.actorId).firstName} a demandé une '
                  'correction. L’équipe technique va reprendre le montage.',
          (false, true) => 'Le contrôle qualité n’est pas passé. Reprenez '
              'le montage avec les retours ci-dessous.',
          (false, false) => 'Une correction est demandée. Lisez les '
              'échanges, puis reprenez le montage.',
        },
      PostStatus.readyForCheck => mine
          ? 'Le montage est terminé. L’équipe technique fait le contrôle '
              'qualité avant la livraison.'
          : 'Le montage est prêt. Faites le contrôle qualité.',
    };

    final actions = <Widget>[
      if (canSetPostStatus(me, p, PostStatus.inProgress))
        EsButton(
          s == PostStatus.notStarted
              ? 'Commencer le montage'
              : 'Reprendre le montage',
          icon: Icons.play_arrow_rounded,
          size: EsButtonSize.medium,
          loading: busy,
          onPressed: busy
              ? null
              : () => _set(PostStatus.inProgress, 'Montage en cours.'),
        ),
      if (canSetPostStatus(me, p, PostStatus.readyForCheck))
        EsButton(
          'Montage prêt pour le contrôle',
          icon: Icons.task_alt_rounded,
          size: EsButtonSize.medium,
          loading: busy,
          onPressed: busy
              ? null
              : () => _set(
                    PostStatus.readyForCheck,
                    'Le montage passe au contrôle qualité.',
                  ),
        ),
      if (canQualityCheck(me, p))
        EsButton(
          'Faire le contrôle qualité',
          icon: Icons.fact_check_outlined,
          size: EsButtonSize.medium,
          onPressed: _check,
        ),
    ];

    return EsCard(
      color: c.lilac,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Overline('Montage')),
              PostStatusTag(s),
            ],
          ),
          const SizedBox(height: 12),
          _PostSteps(status: s),
          const SizedBox(height: 12),
          Text(explain, style: EsText.bodyM.copyWith(color: c.textSecondary)),
          if (p.qcNote != null &&
              s == PostStatus.correctionRequested &&
              fromCheck) ...[
            const SizedBox(height: 10),
            InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.fact_check_outlined,
              title: 'Retour du contrôle qualité',
              text: p.qcNote!,
            ),
          ],
          for (final a in actions) ...[const SizedBox(height: 10), a],
        ],
      ),
    );
  }
}

/// Montage → Prêt → Contrôle, with a correction loop shown in amber.
class _PostSteps extends StatelessWidget {
  const _PostSteps({required this.status});
  final PostStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final step = switch (status) {
      PostStatus.notStarted => 0,
      PostStatus.inProgress || PostStatus.correctionRequested => 1,
      PostStatus.readyForCheck => 2,
    };
    const labels = ['À commencer', 'Montage', 'Contrôle'];
    final loop = status == PostStatus.correctionRequested;
    return Semantics(
      label: 'Montage : ${status.label}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: i <= step ? c.actionPrimary : c.bgSurface,
                ),
              ),
            Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < step
                        ? c.actionPrimary
                        : i == step
                            ? (loop ? c.pendingText : c.accent)
                            : c.bgSurface,
                  ),
                  child: Icon(
                    i < step
                        ? Icons.check_rounded
                        : i == step && loop
                            ? Icons.replay_rounded
                            : Icons.circle,
                    size: i < step || (i == step && loop) ? 15 : 7,
                    color: i <= step ? Colors.white : c.textDisabled,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: EsText.labelS.copyWith(
                    fontSize: 11,
                    color: i == step ? c.textPrimary : c.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// R-25 / P-08: pass with a delivery link, or send back with a reason.
class QualityCheckSheet extends ConsumerStatefulWidget {
  const QualityCheckSheet({super.key, required this.project});
  final Project project;

  @override
  ConsumerState<QualityCheckSheet> createState() => _QcState();
}

class _QcState extends ConsumerState<QualityCheckSheet> {
  bool? passed;
  final link = TextEditingController();

  /// One box per verdict, so a failure reason never leaks into a delivery.
  final passNote = TextEditingController();
  final failNote = TextEditingController();
  bool busy = false;

  TextEditingController get note => passed == true ? passNote : failNote;

  @override
  void initState() {
    super.initState();
    for (final t in [link, passNote, failNote]) {
      t.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    link.dispose();
    passNote.dispose();
    failNote.dispose();
    super.dispose();
  }

  bool get _ready => switch (passed) {
        true => isValidDeliveryLink(link.text),
        false => failNote.text.trim().isNotEmpty,
        null => false,
      };

  Future<void> _send() async {
    if (passed! && !await _confirmArchive()) return;
    if (!mounted) return;
    setState(() => busy = true);
    final ok = await runProjectAction(
      context,
      () => ref.read(projectServiceProvider).qualityCheck(
            widget.project.id,
            by: ref.read(currentPersonProvider),
            passed: passed!,
            note: note.text.trim().isEmpty ? null : note.text.trim(),
            deliveryUrl: passed! ? link.text.trim() : null,
          ),
      done: passed!
          ? 'Projet validé et livré.'
          : 'Renvoyé en correction.',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => busy = false);
    }
  }

  /// Archiving can't be undone: say so before doing it.
  Future<bool> _confirmArchive() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valider et archiver ?'),
        content: const Text(
          'Le projet sera archivé et le lien du fichier final envoyé à '
          'l’équipe du projet. Les échanges passeront en lecture seule. '
          'Cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Valider et livrer'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        EsSpace.page,
        0,
        EsSpace.page,
        EsSpace.s5 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Contrôle qualité',
              style: EsText.displayM.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Vérifiez l’image et le son avant de livrer « '
              '${widget.project.title} ».',
              style: EsText.bodyM.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: EsSpace.s4),
            Row(
              children: [
                Expanded(
                  child: _Verdict(
                    icon: Icons.verified_outlined,
                    label: 'Validé',
                    selected: passed == true,
                    color: c.successText,
                    onTap: () => setState(() => passed = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Verdict(
                    icon: Icons.replay_rounded,
                    label: 'À corriger',
                    selected: passed == false,
                    color: c.pendingText,
                    onTap: () => setState(() => passed = false),
                  ),
                ),
              ],
            ),
            if (passed == true) ...[
              const SizedBox(height: EsSpace.s4),
              TextField(
                controller: link,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Lien sécurisé du fichier final',
                  hintText: 'https://…',
                  helperText: 'Visible par l’équipe du projet et les '
                      'studios (voir Q12).',
                  errorText: link.text.isNotEmpty &&
                          !isValidDeliveryLink(link.text)
                      ? 'Le lien doit commencer par https://'
                      : null,
                ),
              ),
              const SizedBox(height: EsSpace.s3),
              TextField(
                controller: passNote,
                maxLines: 2,
                maxLength: 600,
                decoration: const InputDecoration(
                  labelText: 'Un mot pour le porteur (facultatif)',
                ),
              ),
            ],
            if (passed == false) ...[
              const SizedBox(height: EsSpace.s4),
              TextField(
                controller: failNote,
                maxLines: 4,
                maxLength: 600,
                decoration: const InputDecoration(
                  labelText: 'Ce qu’il faut corriger',
                  hintText: 'Ex. : niveau sonore trop bas sur la scène 2, '
                      'générique à refaire',
                  alignLabelWithHint: true,
                ),
              ),
            ],
            const SizedBox(height: EsSpace.s3),
            EsButton(
              switch (passed) {
                true => 'Valider et livrer',
                false => 'Renvoyer en correction',
                null => 'Choisissez un résultat',
              },
              loading: busy,
              onPressed: _ready && !busy ? _send : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EsRadius.lg),
        child: AnimatedContainer(
          duration: EsMotion.fast,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : c.bgSurface,
            borderRadius: BorderRadius.circular(EsRadius.lg),
            border: Border.all(
              color: selected ? color : c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(label, style: EsText.titleS.copyWith(color: c.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delivery (R-25)

class DeliveryCard extends StatelessWidget {
  const DeliveryCard({super.key, required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final url = project.deliveryUrl;
    return EsCard(
      color: c.successBg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, color: c.successText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Projet validé et livré',
                  style: EsText.titleL.copyWith(color: c.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            project.deliveredAt == null
                ? 'Le contrôle qualité est validé.'
                : 'Contrôle qualité validé le '
                    '${Fmt.dateTime(project.deliveredAt!)}.',
            style: EsText.bodyM.copyWith(color: c.textSecondary),
          ),
          if (project.qcNote != null) ...[
            const SizedBox(height: 8),
            Text(
              '« ${project.qcNote} »',
              style: EsText.bodyM.copyWith(
                color: c.textPrimary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (url != null) ...[
            const SizedBox(height: 14),
            EsButton(
              'Ouvrir le fichier final',
              icon: Icons.download_rounded,
              size: EsButtonSize.medium,
              onPressed: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lien copié.')),
                  );
                }
              },
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Copier le lien'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thread (R-24)

class ProjectThread extends ConsumerStatefulWidget {
  const ProjectThread({super.key, required this.project});
  final Project project;

  @override
  ConsumerState<ProjectThread> createState() => _ThreadState();
}

class _ThreadState extends ConsumerState<ProjectThread> {
  final text = TextEditingController();
  bool correction = false;
  bool sending = false;
  bool showAll = false;

  @override
  void initState() {
    super.initState();
    text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = text.text.trim();
    if (body.isEmpty) return;
    setState(() => sending = true);
    final ok = await runProjectAction(
      context,
      () => ref.read(projectServiceProvider).postMessage(
            widget.project.id,
            body,
            by: ref.read(currentPersonProvider),
            correction: correction && canRequestCorrection(
              ref.read(currentPersonProvider),
              widget.project,
            ),
          ),
      done: correction ? 'Demande de correction envoyée.' : null,
    );
    if (!mounted) return;
    setState(() {
      sending = false;
      if (ok) {
        text.clear();
        correction = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final me = ref.watch(currentPersonProvider);
    final p = widget.project;
    final all = ref.watch(projectsProvider).messagesOf(p.id);
    final shown = showAll || all.length <= 6 ? all : all.sublist(all.length - 6);
    final canWrite = canMessage(me, p);
    final canCorrect = canRequestCorrection(me, p);
    final asCorrection = correction && canCorrect;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (all.isEmpty)
          InfoBanner(
            icon: Icons.forum_outlined,
            title: 'Pas encore d’échange',
            text: canWrite
                ? 'Posez une question à l’équipe technique ou partagez une '
                    'consigne. Tout le monde sur le projet la verra.'
                : 'Les échanges du projet apparaîtront ici.',
          )
        else
          EsCard(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (shown.length < all.length)
                  TextButton(
                    onPressed: () => setState(() => showAll = true),
                    child: Text(
                      'Voir les ${all.length - shown.length} messages '
                      'précédents',
                    ),
                  ),
                for (final m in shown)
                  _MessageTile(
                    message: m,
                    me: me,
                    now: ref.watch(worldProvider).now,
                  ),
              ],
            ),
          ),
        if (!canWrite && p.stage == ProjectStage.archived && all.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Projet archivé : les échanges sont en lecture seule.',
              style: EsText.bodyS.copyWith(color: c.textSecondary),
            ),
          ),
        if (canWrite) ...[
          const SizedBox(height: 10),
          EsCard(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: text,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: asCorrection
                              ? 'Décrivez la correction à faire…'
                              : 'Écrire un message…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          // The limit shows only when it gets close.
                          counterText: text.text.length > 850 ? null : '',
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: asCorrection
                          ? 'Envoyer la demande de correction'
                          : 'Envoyer',
                      onPressed: text.text.trim().isEmpty || sending
                          ? null
                          : _send,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            asCorrection ? c.pendingText : c.actionPrimary,
                        minimumSize: const Size(44, 44),
                      ),
                      icon: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                    ),
                  ],
                ),
                if (canCorrect)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      avatar: Icon(
                        Icons.edit_note_rounded,
                        size: 18,
                        color: asCorrection ? Colors.white : c.pendingText,
                      ),
                      label: const Text('Demande de correction'),
                      selected: asCorrection,
                      showCheckmark: false,
                      selectedColor: c.pendingText,
                      labelStyle: EsText.labelS.copyWith(
                        color: asCorrection ? Colors.white : c.textPrimary,
                      ),
                      onSelected: (v) => setState(() => correction = v),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.me,
    required this.now,
  });
  final ProjectMessage message;
  final Person me;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final m = message;
    final author = personById(m.authorId);
    final when = Fmt.dateTime(m.at);

    // Status changes and verdicts are small centred events.
    if (m.kind == MessageKind.status) {
      final s = PostStatus.values.where((x) => x.name == m.body).firstOrNull;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Divider(color: c.border)),
            Flexible(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${author.firstName} · ${s?.label ?? m.body} · '
                  '${Fmt.ago(m.at, now)}',
                  textAlign: TextAlign.center,
                  style: EsText.bodyS.copyWith(color: c.textSecondary),
                ),
              ),
            ),
            Expanded(child: Divider(color: c.border)),
          ],
        ),
      );
    }

    final (Color? bg, Color? fg, String? badge, IconData? icon) = switch (m.kind) {
      MessageKind.correction => (
          c.pendingBg,
          c.pendingText,
          'Demande de correction',
          Icons.edit_note_rounded,
        ),
      MessageKind.qcFailed => (
          c.dangerBg,
          c.dangerText,
          'Contrôle qualité : à corriger',
          Icons.replay_rounded,
        ),
      MessageKind.qcPassed => (
          c.successBg,
          c.successText,
          'Contrôle qualité validé',
          Icons.verified_rounded,
        ),
      _ => (null, null, null, null),
    };
    final mine = m.authorId == me.id;
    final staffRole = isTechTeam(author) ? ' · Équipe technique' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(author.initials, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: mine ? 'Vous' : author.fullName,
                              style:
                                  EsText.titleS.copyWith(color: c.textPrimary),
                            ),
                            TextSpan(
                              text: staffRole,
                              style: EsText.bodyS
                                  .copyWith(color: c.textSecondary),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: when,
                      child: Text(
                        Fmt.ago(m.at, now),
                        style: EsText.bodyS.copyWith(color: c.textDisabled),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: bg == null
                      ? EdgeInsets.zero
                      : const EdgeInsets.all(10),
                  decoration: bg == null
                      ? null
                      : BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(EsRadius.md),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (badge != null) ...[
                        Row(
                          children: [
                            Icon(icon, size: 15, color: fg),
                            const SizedBox(width: 5),
                            Text(
                              badge,
                              style: EsText.labelS.copyWith(color: fg),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      SelectableText(
                        m.body,
                        style: EsText.bodyM.copyWith(color: c.textPrimary),
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// Members (R-27)

class MembersSection extends ConsumerWidget {
  const MembersSection({super.key, required this.project});
  final Project project;

  Future<bool> _confirm(BuildContext context, String title, String text,
      String action) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final c = ctx.es;
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(EsSpace.page, 0, EsSpace.page, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title,
                    style: EsText.displayM.copyWith(color: c.textPrimary)),
                const SizedBox(height: 6),
                Text(text,
                    style: EsText.bodyM.copyWith(color: c.textSecondary)),
                const SizedBox(height: 18),
                EsButton(
                  action,
                  style: EsButtonStyle.destructive,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
                const SizedBox(height: 8),
                EsButton(
                  'Annuler',
                  style: EsButtonStyle.ghost,
                  onPressed: () => Navigator.pop(ctx, false),
                ),
              ],
            ),
          ),
        );
      },
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final me = ref.watch(currentPersonProvider);
    final p = project;
    final pending = ref.watch(projectsProvider).pendingInvitesOf(p.id);
    final service = ref.read(projectServiceProvider);
    final owner = p.ownerId == me.id;
    final archived = p.stage == ProjectStage.archived;

    Widget row({
      required String personId,
      required String role,
      Widget? trailing,
      bool pendingInvite = false,
    }) {
      final person = personById(personId);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Opacity(
              opacity: pendingInvite ? 0.55 : 1,
              child: Avatar(person.initials, size: 36),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    personId == me.id
                        ? '${person.fullName} (vous)'
                        : person.fullName,
                    style: EsText.titleS.copyWith(color: c.textPrimary),
                  ),
                  Text(
                    role,
                    style: EsText.bodyS.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );
    }

    return EsCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(personId: p.ownerId, role: 'Porteur du projet'),
          for (final m in p.memberIds)
            row(
              personId: m,
              role: isTechTeam(personById(m))
                  ? 'Collaborateur · équipe technique'
                  : 'Collaborateur',
              trailing: archived
                  ? null
                  : owner
                      ? IconButton(
                          tooltip: 'Retirer ${personById(m).fullName}',
                          icon: Icon(
                            Icons.person_remove_outlined,
                            color: c.dangerText,
                          ),
                          onPressed: () async {
                            if (!await _confirm(
                              context,
                              'Retirer ${personById(m).firstName} ?',
                              'Cette personne n’aura plus accès au projet. '
                                  'Ses séances déjà réservées restent liées.',
                              'Retirer du projet',
                            )) {
                              return;
                            }
                            if (!context.mounted) return;
                            await runProjectAction(
                              context,
                              () => service.removeMember(p.id, m, by: me),
                              done: 'Collaborateur retiré.',
                            );
                          },
                        )
                      : m == me.id
                          ? TextButton(
                              onPressed: () async {
                                if (!await _confirm(
                                  context,
                                  'Quitter le projet ?',
                                  'Vous n’aurez plus accès à ce projet. Le '
                                      'porteur pourra vous inviter à nouveau.',
                                  'Quitter le projet',
                                )) {
                                  return;
                                }
                                if (!context.mounted) return;
                                final left = await runProjectAction(
                                  context,
                                  () => service.removeMember(p.id, m, by: me),
                                  done: 'Vous avez quitté le projet.',
                                );
                                // The project is no longer visible to me.
                                if (left && context.mounted) {
                                  context.go('/projects');
                                }
                              },
                              child: Text(
                                'Quitter',
                                style: TextStyle(color: c.dangerText),
                              ),
                            )
                          : null,
            ),
          if (owner)
            for (final i in pending)
              row(
                personId: i.inviteeId,
                role: 'Invitation envoyée · ${Fmt.ago(i.at, ref.watch(worldProvider).now)}',
                pendingInvite: true,
                trailing: TextButton(
                  onPressed: () => runProjectAction(
                    context,
                    () => service.cancelInvite(i.id, by: me),
                    done: 'Invitation annulée.',
                  ),
                  child: const Text('Annuler'),
                ),
              ),
          if (canInvite(me, p, pending: pending.length)) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => InvitePeopleSheet(project: p),
                ),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Inviter un collaborateur'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Search the directory and invite someone (R-27).
class InvitePeopleSheet extends ConsumerStatefulWidget {
  const InvitePeopleSheet({super.key, required this.project});
  final Project project;

  @override
  ConsumerState<InvitePeopleSheet> createState() => _InviteState();
}

class _InviteState extends ConsumerState<InvitePeopleSheet> {
  final search = TextEditingController();
  String? sending;

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
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
    final store = ref.watch(projectsProvider);
    final p = store.projects.firstWhere(
      (x) => x.id == widget.project.id,
      orElse: () => widget.project,
    );
    final invited = {for (final i in store.pendingInvitesOf(p.id)) i.inviteeId};
    final q = _fold(search.text.trim());
    final people = [
      for (final person in Directory.people)
        if (isInvitable(person) &&
            !p.involves(person.id) &&
            (q.isEmpty ||
                _fold(person.fullName).contains(q) ||
                _fold(person.title ?? '').contains(q)))
          person,
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: EsSpace.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Inviter un collaborateur',
                      style: EsText.displayM.copyWith(color: c.textPrimary),
                    ),
                    Text(
                      'Un étudiant moniteur, un enseignant ou un membre de '
                      'l’équipe technique. Il devra accepter.',
                      style: EsText.bodyS.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: search,
                      autofocus: false,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Rechercher un nom',
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              Flexible(
                child: people.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Personne ne correspond à « ${search.text} ».',
                          textAlign: TextAlign.center,
                          style:
                              EsText.bodyM.copyWith(color: c.textSecondary),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(
                          EsSpace.page,
                          0,
                          EsSpace.page,
                          16,
                        ),
                        children: [
                          for (final person in people)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Avatar(person.initials, size: 40),
                              title: Text(
                                person.fullName,
                                style: EsText.titleS,
                              ),
                              subtitle: Text(
                                person.title ??
                                    person.roles.map((r) => r.label).join(', '),
                              ),
                              trailing: invited.contains(person.id)
                                  ? Tag(
                                      label: 'Invité·e',
                                      background: c.lilac,
                                      foreground: c.onLilac,
                                    )
                                  : sending == person.id
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : TextButton(
                                          onPressed: sending != null
                                              ? null
                                              : () async {
                                                  setState(
                                                    () => sending = person.id,
                                                  );
                                                  await runProjectAction(
                                                    context,
                                                    () => ref
                                                        .read(
                                                          projectServiceProvider,
                                                        )
                                                        .invite(
                                                          p.id,
                                                          person.id,
                                                          by: me,
                                                        ),
                                                    done:
                                                        'Invitation envoyée à '
                                                        '${person.firstName}.',
                                                  );
                                                  if (mounted) {
                                                    setState(
                                                      () => sending = null,
                                                    );
                                                  }
                                                },
                                          child: const Text('Inviter'),
                                        ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An invitation waiting for me, with Accept / Decline.
class InvitationCard extends ConsumerStatefulWidget {
  const InvitationCard({super.key, required this.invite});
  final ProjectInvite invite;

  @override
  ConsumerState<InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<InvitationCard> {
  bool busy = false;

  Future<void> _answer(bool accept) async {
    setState(() => busy = true);
    await runProjectAction(
      context,
      () => ref.read(projectServiceProvider).answerInvite(
            widget.invite.id,
            by: ref.read(currentPersonProvider),
            accept: accept,
          ),
      done: accept
          ? 'Vous avez rejoint « ${widget.invite.projectTitle} ».'
          : 'Invitation refusée.',
    );
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final i = widget.invite;
    final from = personById(i.invitedBy);
    return EsCard(
      color: c.lilac,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(from.initials, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.projectTitle,
                      style: EsText.titleM.copyWith(color: c.textPrimary),
                    ),
                    Text(
                      '${from.fullName} vous invite à collaborer · '
                      '${Fmt.ago(i.at, ref.watch(worldProvider).now)}',
                      style: EsText.bodyS.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: EsButton(
                  'Refuser',
                  style: EsButtonStyle.secondary,
                  size: EsButtonSize.medium,
                  onPressed: busy ? null : () => _answer(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EsButton(
                  'Accepter',
                  size: EsButtonSize.medium,
                  loading: busy,
                  onPressed: busy ? null : () => _answer(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
