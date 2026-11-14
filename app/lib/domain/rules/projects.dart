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

/// Files accepted for upload (Q12 is about where final files go).
const maxFileBytes = 20 * 1024 * 1024;
const allowedFileExtensions = [
  'pdf', 'doc', 'docx', 'txt', 'odt', 'png', 'jpg', 'jpeg',
];
