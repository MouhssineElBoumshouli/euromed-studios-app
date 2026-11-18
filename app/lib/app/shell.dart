import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/es_colors.dart';
import '../core/theme/es_text.dart';
import '../core/widgets/es_button.dart';
import '../core/widgets/layout.dart';
import '../core/widgets/logo.dart';
import '../data/app_state.dart';
import '../data/backend.dart';
import '../data/selectors.dart' show noticesProvider;
import '../features/notifications/notifications_screen.dart';
import 'demo_mode.dart';
import 'demo_switcher.dart';
import 'tabs.dart';
import '../core/l10n/text.dart';

/// The frame around every tab screen: demo bar on top, tabs at the bottom.
/// Whose feed the live banner last looked at.
String? _bannerPerson;

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(currentPersonProvider);
    // A small banner when something new arrives while the app is open
    // (only for events from the last two minutes, never on sign-in).
    ref.listen(noticesProvider, (before, after) {
      // Never on sign-in, account switch or while loading.
      final who = ref.read(currentPersonIdProvider);
      final switched = _bannerPerson != who;
      _bannerPerson = who;
      if (before == null || switched || before.isEmpty) return;
      if (isLive && liveStatus.value != LiveStatus.ready) return;
      final known = {for (final n in before) n.id};
      final now = ref.read(worldProvider).now;
      final fresh = [
        for (final n in after)
          if (!known.contains(n.id) &&
              now.difference(n.at) < const Duration(minutes: 5))
            n,
      ];
      if (fresh.isEmpty) return;
      final n = fresh.first;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${n.title} · ${n.body}'),
            action: SnackBarAction(
              label: tr('Voir'),
              onPressed: () => context.push(n.route),
            ),
          ),
        );
    });
    // Staff on a computer get the "Espace Studios" workspace: more sections
    // than fit in a phone tab bar.
    final console = isWide(context) && isStaff(person);
    final tabs = console ? consoleTabsFor(person) : tabsFor(person);
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

    if (isWide(context)) {
      // Lists and boards use the room; Home gets two columns; reading
      // screens stay at a comfortable width.
      final maxWidth = console || _roomy.any(location.startsWith)
          ? 1440.0
          : location.startsWith('/home')
              ? 1240.0
              : 760.0;
      return Scaffold(
        body: Row(
          children: [
            SideMenu(
              console: console,
              tabs: tabs,
              selected: index < 0 ? 0 : index,
              onSelect: (i) => context.go(tabs[i].path),
            ),
            Expanded(
              // The soft background shapes cover the whole area, not just
              // the centred column, so nothing looks cut at the sides.
              child: BlobBackground.page(
                child: MediaQuery.removePadding(
                  context: context,
                  // The side menu already sits next to the screen's edge.
                  removeLeft: true,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: page,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          if (kDemoMode) const DemoBar(),
          // Pages read the padding from outside this Scaffold, so the
          // floating tab bar's room is added once, by tabBarSpace().
          // In demo mode the demo bar already covers the status bar.
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: kDemoMode,
              child: page,
            ),
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

const _roomy = ['/studios', '/validations', '/planning', '/dashboard', '/admin'];

/// Shows a full-screen page (detail, booking flow, QR…) as a centered
/// column on computers, instead of stretching it edge to edge.
class WideFrame extends StatelessWidget {
  const WideFrame({super.key, required this.child, this.maxWidth = 720});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!isWide(context)) return child;
    return ColoredBox(
      color: context.es.bgSubtle,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(boxShadow: esShadow(context.es, strength: 2)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Screens at least this wide (computers, tablets in landscape) get the
/// side menu and roomier layouts instead of the phone tab bar.
const wideBreakpoint = 900.0;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= wideBreakpoint;

/// Height the floating tab bar takes at the bottom of the screen, so
/// scrolling content can leave room for it. On computers there is no
/// bottom bar, only a normal margin.
double tabBarSpace(BuildContext context) =>
    (isWide(context) ? EsSpace.s8 : 100) + MediaQuery.paddingOf(context).bottom;

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
                        curve: EsMotion.curve,
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
      label: tr(spec.label),
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
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
            // Long labels ("Maintenance") shrink a little instead of cutting.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                spec.label,
                maxLines: 1,
                softWrap: false,
                style: EsText.labelS.copyWith(
                  color: fg,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// The computer layout's left menu: brand, sections, and who you are.
///
/// Staff get the darker "Espace Studios" version, so their workspace reads
/// as a professional tool, distinct from the students' app.
class SideMenu extends ConsumerWidget {
  const SideMenu({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
    this.console = false,
  });
  final List<TabSpec> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool console;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final me = ref.watch(currentPersonProvider);
    final bg = console ? c.bgBrand : c.bgSurface;
    final text = console ? c.textOnBrand : c.textPrimary;
    final muted = console ? c.textOnBrandMuted : c.textSecondary;
    final selBg = console ? Colors.white.withValues(alpha: 0.12) : c.lilac;
    final selFg = console ? Colors.white : c.onLilac;
    // Stay clear of the status bar and of Android's navigation buttons
    // (tablets draw them over the bottom of the app).
    final insets = MediaQuery.paddingOf(context);
    return Container(
      width: 264 + insets.left,
      decoration: BoxDecoration(
        color: bg,
        border: console ? null : Border(right: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        16 + insets.left,
        28 + insets.top,
        16,
        16 + insets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EuromedStudiosLogo(height: 44, onDark: console),
                      if (console) ...[
                        const SizedBox(height: 10),
                        Text(
                          'ESPACE STUDIOS',
                          style: EsText.overline.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                NoticeBell(onDark: console),
              ],
            ),
          ),
          const SizedBox(height: 32),
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: i == selected ? selBg : Colors.transparent,
                borderRadius: BorderRadius.circular(EsRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(EsRadius.md),
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          i == selected ? tabs[i].selectedIcon : tabs[i].icon,
                          size: 21,
                          color: i == selected ? selFg : muted,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          tabs[i].label,
                          style: EsText.labelM.copyWith(
                            color: i == selected ? selFg : text,
                            fontWeight: i == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          if (kDemoMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: text,
                  side: BorderSide(
                    color: console
                        ? Colors.white.withValues(alpha: 0.3)
                        : c.borderStrong,
                  ),
                  minimumSize: const Size.fromHeight(44),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => showDemoSwitcher(context, ref),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(isLive ? 'Changer de compte' : 'Changer de rôle'),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: console ? c.bgBrandRaised : c.bgSubtle,
              borderRadius: BorderRadius.circular(EsRadius.md),
            ),
            child: Row(
              children: [
                Avatar(me.initials, size: 38, onBrand: console),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EsText.titleS.copyWith(color: text),
                      ),
                      Text(
                        me.title ?? me.roles.first.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EsText.bodyS.copyWith(color: muted),
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
      label: tr('Mode démo. Vous êtes ${p.fullName}. Changer de rôle'),
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
                  '${isLive ? 'En direct' : 'Démo'} · ${p.displayName}'
                  '${p.title == null ? '' : ' · ${p.title}'}',
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
