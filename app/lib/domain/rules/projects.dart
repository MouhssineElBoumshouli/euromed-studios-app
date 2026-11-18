/// Who may see and move a project, and when it may move to the next stage.
///
/// The same rules run on the server (advance_project), so the app can
/// explain a refusal before the server gives it.
library;

import '../bookings.dart';
import '../people.dart';
import '../projects.dart';

/// Studio staff supervise every project (§3, "supervision globale").
bool supervisesProjects(Person p) =>
    p.has(Role.studioManager) || p.has(Role.admin) || p.has(Role.regisseur);

/// People who can start a project: anyone who can book a studio.
bool canCreateProject(Person p) => p.roles.any((r) => r.isRequester);

bool canSeeProject(Person p, Project pr) =>
    pr.involves(p.id) || supervisesProjects(p);

/// Owner and collaborators work on the project (files, bookings).
bool canWorkOn(Person p, Project pr) =>
    pr.involves(p.id) && pr.stage != ProjectStage.archived;

/// Why [pr] cannot move to the next stage yet, or null if it can.
///
/// - Pre-production → Production: at least one preparation file (R-22).
/// - Production → Post-production: at least one linked session that was
///   validated or held (R-23). Q22 asks UEMF to confirm this.
/// - Post-production → Archive: only after the technical team's quality
///   check (R-25), which is a separate step.
String? advanceProblem(
  Project pr,
  List<ProjectFile> files,
  List<Booking> linked,
) {
  switch (pr.stage) {
    case ProjectStage.preProduction:
      final ready = files.any(
        (f) => f.projectId == pr.id && f.kind.isPreparation,
      );
      return ready
          ? null
          : 'Ajoutez d’abord un script, un conducteur ou un storyboard.';
    case ProjectStage.production:
      final held = linked.any(
        (b) =>
            b.projectId == pr.id &&
            (b.status == BookingStatus.approved ||
                b.status == BookingStatus.completed),
      );
      return held
          ? null
          : 'Il faut au moins une séance validée liée au projet.';
    case ProjectStage.postProduction:
      return 'Le passage en archive se fait après le contrôle qualité de '
          'l’équipe technique.';
    case ProjectStage.archived:
      return 'Le projet est archivé.';
  }
}

/// Owner moves their project forward; studio staff can too.
bool canAdvance(Person p, Project pr) =>
    pr.stage != ProjectStage.archived &&
    pr.stage != ProjectStage.postProduction &&
    (pr.ownerId == p.id || p.has(Role.studioManager) || p.has(Role.admin));

/// The technical team runs editing and the quality check (R-24, R-25).
bool isTechTeam(Person p) =>
    p.has(Role.regisseur) || p.has(Role.studioManager) || p.has(Role.admin);

/// P-07 transitions the technical team may make.
bool canSetPostStatus(Person p, Project pr, PostStatus to) =>
    isTechTeam(p) &&
    pr.stage == ProjectStage.postProduction &&
    switch (to) {
      PostStatus.inProgress => pr.postStatus == PostStatus.notStarted ||
          pr.postStatus == PostStatus.correctionRequested,
      PostStatus.readyForCheck => pr.postStatus == PostStatus.inProgress,
      _ => false,
    };

/// Anyone on the project, and studio staff, can write in its thread.
bool canMessage(Person p, Project pr) =>
    pr.stage != ProjectStage.archived &&
    (pr.involves(p.id) || supervisesProjects(p));

/// R-24: the project's people ask for changes while editing is under way.
bool canRequestCorrection(Person p, Project pr) =>
    pr.involves(p.id) &&
    pr.stage == ProjectStage.postProduction &&
    (pr.postStatus == PostStatus.inProgress ||
        pr.postStatus == PostStatus.readyForCheck);

/// R-25: the technical team checks the edit once it is ready.
bool canQualityCheck(Person p, Project pr) =>
    isTechTeam(p) &&
    pr.stage == ProjectStage.postProduction &&
    pr.postStatus == PostStatus.readyForCheck;

const maxMembers = 10;

/// R-27: the owner invites collaborators until the project is archived.
/// [pending] invitations count towards the limit.
bool canInvite(Person p, Project pr, {int pending = 0}) =>
    pr.ownerId == p.id &&
    pr.stage != ProjectStage.archived &&
    pr.memberIds.length + pending < maxMembers;

/// The people of the technical team who have worked on this project's
/// edit (they posted a status change). They get its corrections and its
/// quality check; with nobody yet, the studio manager does.
Set<String> editorsOf(String projectId, List<ProjectMessage> messages) => {
      for (final m in messages)
        if (m.projectId == projectId && m.kind == MessageKind.status)
          m.authorId,
    };

/// Whether [p] should hear about [pr]'s editing (corrections, checks).
bool followsEdit(Person p, Project pr, List<ProjectMessage> messages) {
  if (!isTechTeam(p)) return false;
  final editors = editorsOf(pr.id, messages);
  return editors.contains(p.id) || p.has(Role.studioManager);
}

const maxMessageLength = 1000;

/// People it makes sense to invite: requesters and the technical team.
bool isInvitable(Person candidate) =>
    candidate.roles.any((r) => r.isRequester) || candidate.has(Role.regisseur);

/// A delivery link must be a secure web address.
bool isValidDeliveryLink(String s) =>
    RegExp(r'^https://[^\s/]+\.[^\s]+$').hasMatch(s.trim());

/// Files accepted for upload (Q12 is about where final files go).
const maxFileBytes = 20 * 1024 * 1024;
const allowedFileExtensions = [
  'pdf',
  'doc',
  'docx',
  'txt',
  'odt',
  'png',
  'jpg',
  'jpeg',
];
