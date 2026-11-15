/// Admin data that only admins load: the audit log (P-11).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/activity.dart';
import 'backend.dart';

class AdminState {
  const AdminState({this.audit = const []});
  final List<AuditEntry> audit;
}

/// Offline demo entries (fictional).
final _demoAudit = [
  AuditEntry(
    id: 'a1',
    at: DateTime(2026, 11, 10, 18, 4),
    actorId: 'idrissi',
    action: 'settingsChanged',
    targetType: 'settings',
    summary: 'Fenêtre de réservation : 21 → 30 jours',
  ),
  AuditEntry(
    id: 'a2',
    at: DateTime(2026, 11, 9, 9, 30),
    actorId: 'idrissi',
    action: 'rolesChanged',
    targetType: 'person',
    targetId: 'haddad',
    summary: 'Samir Haddad : + Régisseur',
  ),
];

class AdminNotifier extends Notifier<AdminState> {
  @override
  AdminState build() =>
      isLive ? const AdminState() : AdminState(audit: List.of(_demoAudit));

  void load(AdminState fresh) => state = fresh;
}

final adminProvider =
    NotifierProvider<AdminNotifier, AdminState>(AdminNotifier.new);
