import 'package:flutter/material.dart';

import '../domain/people.dart';

/// One bottom-tab destination.
class TabSpec {
  const TabSpec(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _home =
    TabSpec('/home', 'Accueil', Icons.home_outlined, Icons.home_rounded);
const _studios = TabSpec(
  '/studios',
  'Studios',
  Icons.mic_none_rounded,
  Icons.mic_rounded,
);
const _bookings = TabSpec(
  '/bookings',
  'Sessions',
  Icons.calendar_today_outlined,
  Icons.calendar_today_rounded,
);
const _projects = TabSpec(
  '/projects',
  'Projets',
  Icons.layers_outlined,
  Icons.layers_rounded,
);
const _profile = TabSpec(
  '/profile',
  'Profil',
  Icons.person_outline_rounded,
  Icons.person_rounded,
);
const _validations = TabSpec(
  '/validations',
  'Validations',
  Icons.task_alt_outlined,
  Icons.task_alt_rounded,
);
const _planning = TabSpec(
  '/planning',
  'Planning',
  Icons.calendar_view_week_outlined,
  Icons.calendar_view_week_rounded,
);
const _regie = TabSpec(
  '/regie',
  'Régie',
  Icons.monitor_heart_outlined,
  Icons.monitor_heart_rounded,
);
const _scanner = TabSpec(
  '/scanner',
  'Scanner',
  Icons.qr_code_scanner_rounded,
  Icons.qr_code_scanner_rounded,
);
const _maintenance = TabSpec(
  '/maintenance',
  'Maintenance',
  Icons.build_outlined,
  Icons.build_rounded,
);
const _dashboard = TabSpec(
  '/dashboard',
  'Pilotage',
  Icons.space_dashboard_outlined,
  Icons.space_dashboard_rounded,
);
const _admin = TabSpec(
  '/admin',
  'Gestion',
  Icons.tune_rounded,
  Icons.tune_rounded,
);

/// The bottom tabs a person sees (blueprint §1). The strongest role wins.
List<TabSpec> tabsFor(Person p) {
  if (p.has(Role.admin)) {
    return const [_dashboard, _planning, _admin, _validations, _profile];
  }
  if (p.has(Role.studioManager)) {
    return const [_home, _validations, _planning, _projects, _profile];
  }
  if (p.has(Role.regisseur)) {
    // The scanner stays one tap away from Régie.
    return const [_regie, _planning, _projects, _maintenance, _profile];
  }
  final requester = p.roles.any((r) => r.isRequester);
  if (p.has(Role.entityApprover) && requester) {
    return const [_home, _studios, _bookings, _validations, _profile];
  }
  if (p.has(Role.entityApprover)) {
    return const [_validations, _studios, _profile];
  }
  return const [_home, _studios, _bookings, _projects, _profile];
}

/// People who run or approve things: they get the "Espace Studios"
/// workspace on a computer.
bool isStaff(Person p) =>
    p.has(Role.admin) ||
    p.has(Role.studioManager) ||
    p.has(Role.regisseur) ||
    p.has(Role.entityApprover);

/// Sections of the computer workspace (no 5-tab limit there).
List<TabSpec> consoleTabsFor(Person p) {
  if (p.has(Role.admin)) {
    return const [_dashboard, _validations, _planning, _regie, _studios, _projects, _admin, _profile];
  }
  if (p.has(Role.studioManager)) {
    return const [_home, _validations, _planning, _regie, _studios, _projects, _profile];
  }
  if (p.has(Role.regisseur)) {
    return const [_regie, _scanner, _planning, _projects, _maintenance, _studios, _profile];
  }
  final requester = p.roles.any((r) => r.isRequester);
  return [
    _validations,
    if (requester) ...const [_home, _bookings],
    _studios,
    _profile,
  ];
}
