/// Projects (§4.2 of the Cahier des Charges, R-21 to R-27).
///
/// A project follows a production pipeline in four stages. Bookings made
/// "for this project" are linked to it automatically (R-23).
library;

/// R-21 / P-06: exactly one type per project.
enum ProjectType {
  teaching('Enseignement / MOOC'),
  research('Recherche'),
  culture('Culture'),
  communication('Communication institutionnelle');

  const ProjectType(this.label);
  final String label;
}

/// R-26: the four stages of the pipeline, in order.
enum ProjectStage {
  preProduction('Pré-production'),
  production('Production'),
  postProduction('Post-production'),
  archived('Validation & archive');

  const ProjectStage(this.label);
  final String label;

  ProjectStage? get next =>
      index + 1 < values.length ? values[index + 1] : null;
}

/// R-22: the preparation files a project needs before production.
enum FileKind {
  script('Script'),
  rundown('Conducteur'),
  storyboard('Storyboard'),
  other('Autre document');

  const FileKind(this.label);
  final String label;

  /// Counts as a preparation file for R-22.
  bool get isPreparation => this != FileKind.other;
}

class ProjectFile {
  const ProjectFile({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.uploadedBy,
    required this.uploadedAt,
  });

  final String id;
  final String projectId;
  final FileKind kind;
  final String name;

  /// Where the file is stored (folder = project id).
  final String path;
  final int sizeBytes;
  final String uploadedBy;
  final DateTime uploadedAt;
}

/// P-07: where editing stands during post-production.
enum PostStatus {
  notStarted('Pas commencé'),
  inProgress('Montage en cours'),
  correctionRequested('Correction demandée'),
  readyForCheck('Prêt pour le contrôle');

  const PostStatus(this.label);
  final String label;
}

enum ProjectEventType {
  created,
  stageChanged,
  fileAdded,
  fileRemoved,
  postStatus,
  correction,
  qcPassed,
  qcFailed,
  memberInvited,
  memberJoined,
  memberLeft,
  memberRemoved,
}

/// What a message in the project thread is.
enum MessageKind { message, correction, status, qcFailed, qcPassed }

class ProjectMessage {
  const ProjectMessage({
    required this.id,
    required this.projectId,
    required this.authorId,
    required this.kind,
    required this.body,
    required this.at,
  });
  final String id;
  final String projectId;
  final String authorId;
  final MessageKind kind;

  /// Free text, or the new [PostStatus] name for a status message.
  final String body;
  final DateTime at;
}

enum InviteStatus { pending, accepted, declined, cancelled }

/// R-27: the owner invites a collaborator, who accepts or declines.
class ProjectInvite {
  const ProjectInvite({
    required this.id,
    required this.projectId,
    required this.projectTitle,
    required this.inviteeId,
    required this.invitedBy,
    required this.status,
    required this.at,
  });
  final String id;
  final String projectId;

  /// Copied so the invited person can read it before joining.
  final String projectTitle;
  final String inviteeId;
  final String invitedBy;
  final InviteStatus status;
  final DateTime at;

  ProjectInvite withStatus(InviteStatus s) => ProjectInvite(
        id: id,
        projectId: projectId,
        projectTitle: projectTitle,
        inviteeId: inviteeId,
        invitedBy: invitedBy,
        status: s,
        at: at,
      );
}

class ProjectEvent {
  const ProjectEvent({
    required this.type,
    required this.at,
    required this.actorId,
    this.detail,
  });
  final ProjectEventType type;
  final DateTime at;
  final String actorId;

  /// The new stage name, or the file name.
  final String? detail;
}

class Project {
  const Project({
    required this.id,
    required this.title,
    required this.type,
    required this.stage,
    required this.ownerId,
    required this.createdAt,
    this.description,
    this.memberIds = const [],
    this.history = const [],
    this.postStatus = PostStatus.notStarted,
    this.deliveryUrl,
    this.deliveredAt,
    this.qcNote,
  });

  final String id;
  final String title;
  final String? description;
  final ProjectType type;
  final ProjectStage stage;
  final String ownerId;

  /// Collaborators invited by the owner (R-27).
  final List<String> memberIds;
  final DateTime createdAt;
  final List<ProjectEvent> history;

  /// Editing status, meaningful during post-production (P-07).
  final PostStatus postStatus;

  /// Secure link to the final file, set when the quality check passes.
  final String? deliveryUrl;
  final DateTime? deliveredAt;

  /// The technical team's last quality-check comment.
  final String? qcNote;

  bool involves(String personId) =>
      ownerId == personId || memberIds.contains(personId);

  Project copyWith({
    ProjectStage? stage,
    List<ProjectEvent>? history,
    List<String>? memberIds,
    PostStatus? postStatus,
    String? deliveryUrl,
    DateTime? deliveredAt,
    String? qcNote,
  }) =>
      Project(
        id: id,
        title: title,
        description: description,
        type: type,
        stage: stage ?? this.stage,
        ownerId: ownerId,
        memberIds: memberIds ?? this.memberIds,
        createdAt: createdAt,
        history: history ?? this.history,
        postStatus: postStatus ?? this.postStatus,
        deliveryUrl: deliveryUrl ?? this.deliveryUrl,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        qcNote: qcNote ?? this.qcNote,
      );

  /// Adds one line to the history.
  Project log(
    ProjectEventType type,
    String actorId,
    DateTime at, [
    String? detail,
  ]) =>
      copyWith(
        history: [
          ...history,
          ProjectEvent(type: type, at: at, actorId: actorId, detail: detail),
        ],
      );
}
