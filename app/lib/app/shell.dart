import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/es_colors.dart';
import '../core/theme/es_text.dart';
import '../core/widgets/es_button.dart';
import '../core/widgets/layout.dart';
import '../data/app_state.dart';
import 'demo_mode.dart';
import 'demo_switcher.dart';
import 'tabs.dart';

/// The frame around every tab screen: demo bar on top, tabs at the bottom.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(currentPersonProvider);
    final tabs = tabsFor(person);
    final index = tabs.indexWhere((t) => location.startsWith(t.path));
    // A role never sees a screen that isn't one of its tabs (route guard).
    final Widget page = index >= 0
        ? child
        : EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Écran non disponible',
            message: 'Cet écran n’est pas accessible avec votre rôle.',
            action: EsButton(
              'Retour à l’accueil',
              expand: false,
              onPressed: () => context.go(tabs.first.path),
            ),
          );

    return Scaffold(
      body: Column(
        children: [
          if (kDemoMode) const DemoBar(),
          // The demo bar already handles the status-bar space.
          Expanded(
            child: kDemoMode
                ? MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: page,
                  )
                : page,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(tabs[i].path),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

/// A slim bar that makes clear this is a demo and lets you switch persona.
class DemoBar extends ConsumerWidget {
  const DemoBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final p = ref.watch(currentPersonProvider);
    final top = MediaQuery.paddingOf(context).top;
    return Semantics(
      button: true,
      label: 'Mode démo. Vous êtes ${p.fullName}. Changer de rôle',
      excludeSemantics: true,
      child: Material(
      color: c.bgBrand,
      child: InkWell(
        onTap: () => showDemoSwitcher(context, ref),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top + 12, 12, 12),
          child: Row(
            children: [
              Icon(Icons.swap_horiz_rounded, size: 18, color: c.brandAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Démo · ${p.displayName} · ${p.title ?? ''}',
                  overflow: TextOverflow.ellipsis,
                  style: EsText.labelS.copyWith(color: c.textOnBrand),
                ),
              ),
              Text(
                'Changer',
                style: EsText.labelM.copyWith(color: c.textOnBrand),
              ),
              Icon(Icons.expand_more_rounded, size: 18, color: c.textOnBrand),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
