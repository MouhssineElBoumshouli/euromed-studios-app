import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/es_colors.dart';
import '../core/theme/es_text.dart';
import '../data/app_state.dart';
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
    var index = tabs.indexWhere((t) => location.startsWith(t.path));
    if (index < 0) index = 0;

    return Scaffold(
      body: Column(
        children: [
          const DemoBar(),
          // The demo bar already handles the status-bar space.
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
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
    return Material(
      color: c.bgBrandRaised,
      child: InkWell(
        onTap: () => showDemoSwitcher(context, ref),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top + 6, 12, 6),
          child: Row(
            children: [
              Icon(Icons.theater_comedy_outlined,
                  size: 16, color: c.brandAccent),
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
                style: EsText.labelS.copyWith(color: c.brandAccent),
              ),
              Icon(Icons.expand_more_rounded, size: 18, color: c.brandAccent),
            ],
          ),
        ),
      ),
    );
  }
}
