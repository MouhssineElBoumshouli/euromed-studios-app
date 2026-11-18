import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/es_colors.dart';
import '../core/theme/es_text.dart';
import '../core/widgets/layout.dart';
import '../data/app_state.dart';
import '../data/backend.dart';
import '../data/demo_world.dart';
import '../data/live_sync.dart';
import 'login_screen.dart';
import 'tabs.dart';
import '../core/l10n/text.dart';

/// Lets a viewer see the app as any role. Demo only: in the real app,
/// your roles come from your UEMF account.
Future<void> showDemoSwitcher(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final c = sheetContext.es;
      if (isLive) return _LiveSwitcher(outer: context);
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
                'Mode démo. Toutes les personnes sont fictives et sans lien '
                'avec le personnel réel de l’UEMF. Les actions faites ici '
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
                          Icon(Icons.check_circle_rounded,
                              color: c.successFill),
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

/// Live demo: switching role means signing in as another fictional account.
class _LiveSwitcher extends ConsumerWidget {
  const _LiveSwitcher({required this.outer});
  final BuildContext outer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final me = ref.read(currentPersonIdProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              'Changer de compte',
              style: EsText.titleL.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Démo en direct. Toutes les personnes sont fictives. Ce que vous '
              'faites est visible tout de suite sur les autres appareils.',
              style: EsText.bodyS.copyWith(color: c.textSecondary),
            ),
            DemoAccountList(
              currentSlug: me,
              onPick: (slug) async {
                Navigator.of(context).pop();
                if (slug == me) return;
                await liveSync!.signOut();
                await liveSync!.signIn(slug);
              },
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                final messenger = ScaffoldMessenger.of(outer);
                try {
                  await liveSync!.db.rpc('reset_demo');
                  await liveSync!.refresh();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Démo remise à zéro.')),
                  );
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Seule l’administratrice (Sara Idrissi) peut remettre '
                        'la démo à zéro.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Remettre la démo à zéro (administratrice)'),
            ),
            TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await liveSync!.signOut();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Se déconnecter'),
            ),
          ],
        ),
      ),
    );
  }
}
