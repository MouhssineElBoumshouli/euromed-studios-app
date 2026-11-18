/// I8 · One line of the activity log: who did what, and when (P-11).
library;

import 'bookings.dart';
import 'projects.dart';

/// An admin action stored in the audit log (role change, rule change…).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.at,
    required this.action,
    required this.summary,
    this.actorId,
    this.targetType,
    this.targetId,
  });
  final String id;
  final DateTime at;

  /// Null when the system did it (nightly job).
  final String? actorId;
  final String action;
  final String? targetType;
  final String? targetId;
  final String summary;
}

enum ActivityCategory {
  booking('Réservations'),
  project('Projets'),
  admin('Administration');

  const ActivityCategory(this.label);
  final String label;
}

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.at,
    required this.category,
    required this.actorId,
    required this.title,
    required this.detail,
    this.route,
  });
  final String id;
  final DateTime at;
  final ActivityCategory category;

  /// Null = the system.
  final String? actorId;
  final String title;
  final String detail;
  final String? route;
}

/// Everything that happened, newest first: booking steps, project steps
/// and admin actions. [describe] names a booking ("ES-2026-0142 · Studio
/// Podcast · jeu. 19 nov."), [nameOf] a person.
List<ActivityItem> activityFeed({
  required List<Booking> bookings,
  required List<Project> projects,
  required List<AuditEntry> audit,
  required String Function(Booking) describe,
  required String Function(String id) nameOf,
}) {
  final out = <ActivityItem>[];
  for (final b in bookings) {
    if (b.isPrivate) continue;
    for (final e in b.history) {
      out.add(
        ActivityItem(
          id: 'b-${b.id}-${e.type.name}-${e.at.millisecondsSinceEpoch}',
          at: e.at,
          category: ActivityCategory.booking,
          actorId: e.actorId,
          title: e.type.label,
          detail: [
            describe(b),
            if (e.comment != null && e.comment!.isNotEmpty) '« ${e.comment} »',
          ].join(' · '),
          route: '/bookings/${b.id}',
        ),
      );
    }
  }
  for (final p in projects) {
    for (final e in p.history) {
      out.add(
        ActivityItem(
          id: 'p-${p.id}-${e.type.name}-${e.at.millisecondsSinceEpoch}',
          at: e.at,
          category: ActivityCategory.project,
          actorId: e.actorId,
          title: projectEventLabel(e, nameOf),
          detail: p.title,
          route: '/projects/${p.id}',
        ),
      );
    }
  }
  for (final a in audit) {
    out.add(
      ActivityItem(
        id: 'a-${a.id}',
        at: a.at,
        category: ActivityCategory.admin,
        actorId: a.actorId,
        title: auditLabel(a.action),
        detail: a.summary,
      ),
    );
  }
  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
}

String projectEventLabel(ProjectEvent e, String Function(String) nameOf) =>
    switch (e.type) {
      ProjectEventType.created => 'Projet créé',
      ProjectEventType.stageChanged =>
        'Étape : ${ProjectStage.values.where((s) => s.name == e.detail).firstOrNull?.label ?? e.detail}',
      ProjectEventType.fileAdded => 'Document ajouté · ${e.detail ?? ''}',
      ProjectEventType.fileRemoved => 'Document retiré · ${e.detail ?? ''}',
      ProjectEventType.postStatus =>
        'Montage : ${PostStatus.values.where((s) => s.name == e.detail).firstOrNull?.label ?? e.detail}',
      ProjectEventType.correction => 'Correction demandée',
      ProjectEventType.qcPassed => 'Contrôle qualité validé',
      ProjectEventType.qcFailed => 'Contrôle qualité : à corriger',
      ProjectEventType.memberInvited =>
        'Invitation · ${nameOf(e.detail ?? '')}',
      ProjectEventType.memberJoined => 'Collaborateur ajouté',
      ProjectEventType.memberLeft => 'Collaborateur parti',
      ProjectEventType.memberRemoved =>
        'Collaborateur retiré · ${nameOf(e.detail ?? '')}',
    };

String auditLabel(String action) => switch (action) {
      'demoReset' => 'Données de démonstration remises à zéro',
      'rolesChanged' => 'Rôles modifiés',
      'scopesChanged' => 'Périmètre de validation modifié',
      'accountDisabled' => 'Compte désactivé',
      'accountEnabled' => 'Compte réactivé',
      'settingsChanged' => 'Règles modifiées',
      'studioChanged' => 'Studio modifié',
      'equipmentChanged' => 'Matériel modifié',
      'charterPublished' => 'Nouvelle charte publiée',
      'maintenancePlanned' => 'Maintenance planifiée',
      'maintenanceRemoved' => 'Maintenance retirée',
      _ => action,
    };
