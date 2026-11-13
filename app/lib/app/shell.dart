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
      extendBody: true,
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
      bottomNavigationBar: PillTabBar(
        tabs: tabs,
        selected: index < 0 ? 0 : index,
        onSelect: (i) => context.go(tabs[i].path),
      ),
    );
  }
}

/// Height the floating tab bar takes at the bottom of the screen, so
/// scrolling content can leave room for it.
double tabBarSpace(BuildContext context) =>
    96 + MediaQuery.paddingOf(context).bottom;

/// The floating pill tab bar from the original design, refined: the
/// selected tab sits in a lilac capsule that slides between tabs.
class PillTabBar extends StatelessWidget {
  const PillTabBar({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });
  final List<TabSpec> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, 12 + bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(EsRadius.xl),
          boxShadow: esShadow(c, strength: 2.2),
        ),
        child: Material(
          color: c.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EsRadius.xl),
            side: Theme.of(context).brightness == Brightness.dark
                ? BorderSide(color: c.border)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth / tabs.length;
                return SizedBox(
                  height: 60,
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: EsMotion.medium,
                        curve: Curves.easeOutBack,
                        left: w * selected,
                        top: 0,
                        bottom: 0,
                        width: w,
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.lilac,
                            borderRadius: BorderRadius.circular(EsRadius.lg),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < tabs.length; i++)
                            Expanded(
                              child: _PillTab(
                                spec: tabs[i],
                                selected: i == selected,
                                onTap: () => onSelect(i),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  const _PillTab({
    required this.spec,
    required this.selected,
    required this.onTap,
  });
  final TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final fg = selected ? c.onLilac : c.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EsRadius.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: EsMotion.fast,
              child: Icon(
                selected ? spec.selectedIcon : spec.icon,
                key: ValueKey(selected),
                size: 23,
                color: fg,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              spec.label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: EsText.labelS.copyWith(
                color: fg,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
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
      elevation: 0,
      child: InkWell(
        onTap: () => showDemoSwitcher(context, ref),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top + 8, 12, 8),
          child: Row(
            children: [
              Icon(Icons.swap_horiz_rounded, size: 18, color: c.brandAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Démo · ${p.displayName}${p.title == null ? '' : ' · ${p.title}'}',
                  overflow: TextOverflow.ellipsis,
                  style: EsText.labelS.copyWith(color: c.textOnBrand),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(EsRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Changer de rôle',
                      style: EsText.labelS.copyWith(color: c.textOnBrand),
                    ),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: c.textOnBrand,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
