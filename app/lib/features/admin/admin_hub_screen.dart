import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/admin_state.dart';
import '../../data/app_state.dart';
import '../../domain/people.dart';
import '../notifications/notifications_screen.dart';

/// I3–I9 · Gestion: everything an admin can adjust, in one place.
class AdminHubScreen extends ConsumerWidget {
  const AdminHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final me = ref.watch(currentPersonProvider);
    final audit = ref.watch(adminProvider).audit;

    if (!me.has(Role.admin)) {
      return const EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Accès réservé',
        message: 'La gestion est réservée à l’administration.',
      );
    }

    final sections = <_Section>[
      _Section(
        icon: Icons.manage_accounts_outlined,
        title: 'Utilisateurs et rôles',
        text: 'Rôles, périmètres de validation, clubs.',
        route: '/admin/users',
      ),
      _Section(
        icon: Icons.rule_rounded,
        title: 'Règles',
        text: 'Horaires, durée des créneaux, quotas, fenêtre de réservation.',
        route: '/admin/rules',
      ),
      _Section(
        icon: Icons.meeting_room_outlined,
        title: 'Studios et maintenance',
        text: 'Studios ouverts à la réservation, fermetures pour maintenance.',
        route: '/admin/studios',
      ),
      _Section(
        icon: Icons.inventory_2_outlined,
        title: 'Matériel',
        text: 'Catalogue et quantités disponibles.',
        route: '/admin/equipment',
      ),
      _Section(
        icon: Icons.gavel_rounded,
        title: 'Charte d’utilisation',
        text: 'Publier une nouvelle version : chacun la signe à nouveau.',
        route: '/admin/charter',
      ),
      _Section(
        icon: Icons.history_rounded,
        title: 'Journal d’activité',
        text: audit.isEmpty
            ? 'Qui a fait quoi, et quand.'
            : 'Qui a fait quoi, et quand · ${audit.length} actions '
                'd’administration',
        route: '/admin/activity',
        ready: true,
      ),
    ];

    return ListView(
      padding: EdgeInsets.only(bottom: tabBarSpace(context)),
      children: [
        BrandHeader(
          title: 'Gestion',
          subtitle: 'Réglages des studios et des accès',
          trailing: isWide(context) ? null : const NoticeBell(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EsSpace.page),
          child: LayoutBuilder(
            builder: (_, box) {
              final cols = box.maxWidth >= 900 ? 3 : box.maxWidth >= 560 ? 2 : 1;
              final w = (box.maxWidth - 12 * (cols - 1)) / cols;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final s in sections)
                    SizedBox(
                      width: w,
                      child: EsCard(
                        padding: const EdgeInsets.all(16),
                        semanticLabel: '${s.title}. ${s.text}',
                        onTap: s.ready ? () => context.push(s.route) : null,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconTile(s.icon, size: 42),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    style: EsText.titleM
                                        .copyWith(color: c.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.text,
                                    style: EsText.bodyS
                                        .copyWith(color: c.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (s.ready)
                              Icon(
                                Icons.chevron_right_rounded,
                                color: c.textDisabled,
                              )
                            else
                              Tag(
                                label: 'Bientôt',
                                background: c.bgSubtle,
                                foreground: c.textSecondary,
                              ),
                          ],
                        ),
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
}

class _Section {
  const _Section({
    required this.icon,
    required this.title,
    required this.text,
    required this.route,
    this.ready = false,
  });
  final IconData icon;
  final String title;
  final String text;
  final String route;

  /// Sections still being built show "Bientôt" and can't be opened.
  final bool ready;
}

