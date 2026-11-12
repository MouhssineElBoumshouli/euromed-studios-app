/// People, roles and organizations (requirements R-02 to R-09, P-01, P-03).
library;

/// A UEMF school or department a person belongs to.
class Establishment {
  const Establishment({required this.id, required this.short, required this.name});
  final String id;
  final String short;
  final String name;
}

/// What a person does in the app. One person can hold several (P-01).
enum Role {
  student('Étudiant·e'),
  professor('Enseignant·e-chercheur·e'),
  communication('Équipe Communication'),
  clubRepresentative('Représentant·e de club'),
  externalClient('Client externe'),
  entityApprover('Validateur niveau 1'),
  studioManager('Responsable des Studios'),
  regisseur('Régisseur · équipe technique'),
  admin('Administrateur');

  const Role(this.label);
  final String label;

  bool get isRequester => const {
        Role.student,
        Role.professor,
        Role.communication,
        Role.clubRepresentative,
        Role.externalClient,
      }.contains(this);
}

/// Who a booking is made for. Decides who approves at Level 1 (R-17).
enum RequesterType {
  student('Étudiant'),
  club('Club étudiant'),
  professor('Professeur'),
  communication('Communication'),
  external('Client externe');

  const RequesterType(this.label);
  final String label;
}

/// The part of Level 1 approval a person is responsible for.
class ApproverScope {
  const ApproverScope(this.requesterType, {this.establishmentId});
  final RequesterType requesterType;

  /// Null means "all establishments" (e.g. Communication, Vice-Présidence).
  final String? establishmentId;

  bool covers(RequesterType type, String? establishment) =>
      type == requesterType &&
      (establishmentId == null || establishmentId == establishment);
}

class Person {
  const Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.roles,
    this.establishmentId,
    this.title,
    this.approverScopes = const [],
    this.clubIds = const [],
  });

  final String id;
  final String firstName;
  final String lastName;
  final Set<Role> roles;
  final String? establishmentId;

  /// Job title shown under the name, e.g. "Responsable Vie Étudiante".
  final String? title;
  final List<ApproverScope> approverScopes;

  /// Clubs this person may book for (as representative).
  final List<String> clubIds;

  String get displayName => '$firstName ${lastName.isEmpty ? '' : '${lastName[0]}.'}'.trim();
  String get fullName => '$firstName $lastName'.trim();
  String get initials =>
      '${firstName.isEmpty ? '' : firstName[0]}${lastName.isEmpty ? '' : lastName[0]}'
          .toUpperCase();

  bool has(Role r) => roles.contains(r);
}

/// A student club (a group, never a shared login: P-03).
class Club {
  const Club({required this.id, required this.name});
  final String id;
  final String name;
}
