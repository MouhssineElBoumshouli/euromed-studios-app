import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../data/app_state.dart';
import '../../data/project_service.dart';
import '../../domain/projects.dart';
import 'project_widgets.dart';
import '../../core/l10n/text.dart';

/// F2 · New project: a title, one type (R-21, P-06), a short description.
class NewProjectScreen extends ConsumerStatefulWidget {
  const NewProjectScreen({super.key});

  @override
  ConsumerState<NewProjectScreen> createState() => _NewProjectState();
}

class _NewProjectState extends ConsumerState<NewProjectScreen> {
  final title = TextEditingController();
  final description = TextEditingController();
  ProjectType? type;
  bool sending = false;

  static const _hints = {
    ProjectType.teaching: 'Cours en ligne, capsules, MOOC',
    ProjectType.research: 'Entretiens, captations, données',
    ProjectType.culture: 'Podcast, court-métrage, club',
    ProjectType.communication: 'Vidéos et contenus de l’université',
  };

  @override
  void initState() {
    super.initState();
    title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  bool get _ready => title.text.trim().length >= 3 && type != null;

  Future<void> _create() async {
    setState(() => sending = true);
    final m = ScaffoldMessenger.of(context);
    try {
      final id = await ref.read(projectServiceProvider).create(
            by: ref.read(currentPersonProvider),
            title: title.text.trim(),
            type: type!,
            description: description.text.trim().isEmpty
                ? null
                : description.text.trim(),
          );
      if (!mounted) return;
      context.pushReplacement('/projects/$id');
    } on ProjectProblem catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                EsSpace.page,
                top + EsSpace.s3,
                EsSpace.page,
                EsSpace.s6,
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: EsBackButton(
                    close: true,
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/projects'),
                  ),
                ),
                const SizedBox(height: EsSpace.s4),
                Text(
                  'Nouveau projet',
                  style: EsText.displayL.copyWith(color: c.textPrimary),
                ),
                Text(
                  'Vous pourrez ajouter vos documents et réserver ensuite.',
                  style: EsText.bodyM.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: EsSpace.s5),
                TextField(
                  controller: title,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: tr('Titre du projet'),
                    hintText: tr('Ex. : Podcast « Voix du campus »'),
                  ),
                ),
                const SizedBox(height: EsSpace.s3),
                Text(
                  'Type de projet',
                  style: EsText.titleS.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: EsSpace.s2),
                LayoutBuilder(
                  builder: (_, box) {
                    final cols = box.maxWidth > 520 ? 4 : 2;
                    final w = (box.maxWidth - (cols - 1) * 10) / cols;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final t in ProjectType.values)
                          SizedBox(
                            width: w,
                            child: _TypeCard(
                              type: t,
                              hint: _hints[t]!,
                              selected: type == t,
                              onTap: () => setState(() => type = t),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: EsSpace.s4),
                TextField(
                  controller: description,
                  maxLines: 4,
                  maxLength: 600,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: tr('Description (facultatif)'),
                    hintText: tr('Le but, le format, le nombre d’épisodes…'),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              EsSpace.page,
              EsSpace.s3,
              EsSpace.page,
              EsSpace.s3 + bottom,
            ),
            decoration: BoxDecoration(
              color: c.bgSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(EsRadius.xl),
              ),
              boxShadow: esShadow(c, strength: 2),
            ),
            child: EsButton(
              _ready
                  ? 'Créer le projet'
                  : type == null
                      ? 'Choisissez un type'
                      : 'Donnez un titre',
              loading: sending,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: _ready && !sending ? _create : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.hint,
    required this.selected,
    required this.onTap,
  });
  final ProjectType type;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (bg, fg, icon) = typeStyle(c, type);
    return Semantics(
      button: true,
      selected: selected,
      label: tr('${type.label}. $hint'),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(EsRadius.lg),
          child: AnimatedContainer(
            duration: EsMotion.medium,
            curve: EsMotion.curve,
            constraints: const BoxConstraints(minHeight: 128),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? c.lilac : c.bgSurface,
              borderRadius: BorderRadius.circular(EsRadius.lg),
              border: Border.all(
                color: selected ? c.actionPrimary : c.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(EsRadius.sm),
                      ),
                      child: Icon(icon, color: fg, size: 20),
                    ),
                    const Spacer(),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: c.actionPrimary,
                        size: 22,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  type.label,
                  style: EsText.titleS.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: EsText.bodyS.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
