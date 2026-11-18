/// I3 · The rules for changing someone's access. The server function
/// set_person_access applies the same checks.
library;

import '../people.dart';

/// What each role lets a person do, in one line (shown to the admin).
const roleHelp = {
  Role.student: 'Réserve des créneaux, dans la limite de son quota.',
  Role.professor: 'Réserve des créneaux pour ses cours et recherches.',
  Role.communication: 'Réserve pour la communication de l’université.',
  Role.clubRepresentative: 'Réserve au nom d’un club étudiant.',
  Role.externalClient: 'Client hors UEMF : chaque demande passe par la '
      'Vice-Présidence.',
  Role.entityApprover: 'Valide les demandes au niveau 1, dans son périmètre.',
  Role.studioManager: 'Valide au niveau 2, pilote les studios et les projets.',
  Role.regisseur: 'Accueille les séances, fait le montage et le contrôle '
      'qualité.',
  Role.admin: 'Règle l’application, les accès et consulte le journal.',
};

/// The order and grouping of roles on the admin screen.
const roleGroups = <(String, List<Role>)>[
  (
    'Demandeurs',
    [
      Role.student,
      Role.professor,
      Role.communication,
      Role.clubRepresentative,
      Role.externalClient,
    ]
  ),
  ('Validation', [Role.entityApprover]),
  ('Équipe des studios', [Role.studioManager, Role.regisseur]),
  ('Administration', [Role.admin]),
];

/// Why this change can't be saved, or null. Same codes as the server.
String? accessProblem({
  required Person by,
  required Person target,
  required Set<Role> roles,
  required List<ApproverScope> scopes,
  required List<String> clubs,
  required bool active,
  required List<Person> everyone,
}) {
  if (!by.has(Role.admin)) return 'not_allowed';
  if (roles.isEmpty) return 'no_role';
  if (roles.contains(Role.entityApprover) && scopes.isEmpty) {
    return 'scope_required';
  }
  if (roles.contains(Role.clubRepresentative) && clubs.isEmpty) {
    return 'club_required';
  }
  final losesAdmin = !active || !roles.contains(Role.admin);
  if (target.id == by.id && losesAdmin) return 'self_lockout';
  if (losesAdmin &&
      target.has(Role.admin) &&
      !everyone
          .any((p) => p.id != target.id && p.active && p.has(Role.admin))) {
    return 'last_admin';
  }
  return null;
}

/// The sentence for each refusal code.
String accessProblemText(String code) => switch (code) {
      'not_allowed' => 'Seule l’administration peut modifier les accès.',
      'no_role' => 'Gardez au moins un rôle.',
      'scope_required' => 'Choisissez au moins un type de demande à valider.',
      'club_required' => 'Choisissez au moins un club.',
      'self_lockout' =>
        'Vous ne pouvez pas retirer votre propre accès administrateur.',
      'last_admin' => 'Il doit toujours rester au moins un administrateur '
          'actif.',
      'stale' => 'Cet accès a été modifié entre-temps. Rechargez la page, '
          'puis recommencez.',
      'bad_scope' => 'Périmètre de validation invalide.',
      _ => 'La modification n’a pas pu être enregistrée. Réessayez.',
    };

/// What changes, in plain words ("+ Régisseur · − Étudiant·e").
List<String> accessChanges(
  Person before, {
  required Set<Role> roles,
  required List<ApproverScope> scopes,
  required List<String> clubs,
  required bool active,
}) {
  String key(ApproverScope s) =>
      '${s.requesterType.name}/${s.establishmentId ?? ''}';
  final added = [
    for (final r in Role.values)
      if (roles.contains(r) && !before.has(r)) r
  ];
  final removed = [
    for (final r in Role.values)
      if (!roles.contains(r) && before.has(r)) r
  ];
  final beforeScopes = {
    if (before.has(Role.entityApprover)) ...before.approverScopes.map(key),
  };
  final afterScopes = {
    if (roles.contains(Role.entityApprover)) ...scopes.map(key),
  };
  final beforeClubs = {
    if (before.has(Role.clubRepresentative)) ...before.clubIds,
  };
  final afterClubs = {
    if (roles.contains(Role.clubRepresentative)) ...clubs,
  };
  return [
    if (added.isNotEmpty) '+ ${added.map((r) => r.label).join(', ')}',
    if (removed.isNotEmpty) '− ${removed.map((r) => r.label).join(', ')}',
    if (beforeScopes.length != afterScopes.length ||
        !beforeScopes.containsAll(afterScopes))
      'périmètre de validation modifié',
    if (beforeClubs.length != afterClubs.length ||
        !beforeClubs.containsAll(afterClubs))
      'clubs modifiés',
    if (active != before.active)
      active ? 'compte réactivé' : 'compte désactivé',
  ];
}
