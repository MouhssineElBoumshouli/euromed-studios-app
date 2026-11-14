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

enum ProjectEventType { created, stageChanged, fileAdded, fileRemoved }

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

  bool involves(String personId) =>
      ownerId == personId || memberIds.contains(personId);

  Project copyWith({ProjectStage? stage, List<ProjectEvent>? history}) =>
      Project(
        id: id,
        title: title,
        description: description,
        type: type,
        stage: stage ?? this.stage,
        ownerId: ownerId,
        memberIds: memberIds,
        createdAt: createdAt,
        history: history ?? this.history,
      );
}
