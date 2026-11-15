import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../data/app_state.dart';
import '../../domain/people.dart';

/// The frame shared by the admin pages: back button, title, a short line
/// of explanation, an access check, and an optional bottom bar.
class AdminPage extends ConsumerWidget {
  const AdminPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.bar,
    this.allow = const {Role.admin},
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? bar;

  /// Who may open the page.
  final Set<Role> allow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final me = ref.watch(currentPersonProvider);
    final ok = allow.any(me.has);
    final top = MediaQuery.paddingOf(context).top;
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
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/admin'),
                  ),
                ),
                const SizedBox(height: EsSpace.s4),
                Text(title,
                    style: EsText.displayL.copyWith(color: c.textPrimary)),
                Text(subtitle,
                    style: EsText.bodyM.copyWith(color: c.textSecondary)),
                const SizedBox(height: EsSpace.s4),
                if (ok)
                  ...children
                else
                  const EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Accès réservé',
                    message: 'Cette page est réservée à l’administration.',
                  ),
              ],
            ),
          ),
          if (ok && bar != null) bar!,
        ],
      ),
    );
  }
}

/// A sticky bottom bar with a summary line and Save / Cancel.
class SaveBar extends StatelessWidget {
  const SaveBar({
    super.key,
    required this.changes,
    required this.onSave,
    required this.onCancel,
    this.problem,
    this.saving = false,
  });
  final List<String> changes;
  final String? problem;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        EsSpace.page,
        EsSpace.s3,
        EsSpace.page,
        EsSpace.s3 + bottom,
      ),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(EsRadius.xl)),
        boxShadow: esShadow(c, strength: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (problem != null || changes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                problem ?? changes.join(' · '),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: EsText.bodyS.copyWith(
                  color: problem != null ? c.dangerText : c.textSecondary,
                ),
              ),
            ),
          Row(
            children: [
              if (changes.isNotEmpty) ...[
                Expanded(
                  child: EsButton(
                    'Annuler',
                    style: EsButtonStyle.secondary,
                    onPressed: saving ? null : onCancel,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: EsButton(
                  changes.isEmpty ? 'Aucune modification' : 'Enregistrer',
                  loading: saving,
                  onPressed: changes.isEmpty || problem != null || saving
                      ? null
                      : onSave,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
