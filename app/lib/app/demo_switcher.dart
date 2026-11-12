import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/es_colors.dart';
import '../core/theme/es_text.dart';
import '../core/widgets/layout.dart';
import '../data/app_state.dart';
import '../data/demo_world.dart';
import 'tabs.dart';

/// Lets a viewer see the app as any role. Demo only: in the real app,
/// your roles come from your UEMF account.
Future<void> showDemoSwitcher(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final c = sheetContext.es;
      final current = ref.read(currentPersonIdProvider);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                'Voir l’application en tant que…',
                style: EsText.titleL.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Mode démo : données fictives. Les actions faites ici '
                '(réserver, valider…) sont visibles par les autres rôles.',
                style: EsText.bodyS.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: 16),
              for (final p in DemoWorld.people)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: EsCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    onTap: () {
                      ref.read(currentPersonIdProvider.notifier).state = p.id;
                      Navigator.of(sheetContext).pop();
                      context.go(tabsFor(p).first.path);
                    },
                    child: Row(
                      children: [
                        Avatar(p.initials, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.fullName,
                                style: EsText.titleS.copyWith(
                                  color: c.textPrimary,
                                ),
                              ),
                              Text(
                                p.title ?? p.roles.first.label,
                                style: EsText.bodyS.copyWith(
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (p.id == current)
                          Icon(Icons.check_circle_rounded, color: c.successFill),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  ref.read(worldProvider.notifier).reset();
                  Navigator.of(sheetContext).pop();
                },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Remettre la démo à zéro'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
