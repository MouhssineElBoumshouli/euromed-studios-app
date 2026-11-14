/// Projects and their files, held in memory like the bookings.
///
/// Offline (tests), [ProjectsNotifier] works on the demo projects below.
/// Live, [LiveSync] loads the rows this person may see and calls [load].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/people.dart';
import '../domain/projects.dart';
import '../domain/rules/projects.dart';
import 'app_state.dart';
import 'backend.dart';

class ProjectsState {
  const ProjectsState({
    this.projects = const [],
    this.files = const [],
    this.loaded = true,
  });
  final List<Project> projects;
  final List<ProjectFile> files;

  /// False until the first live load (so a deep link waits instead of
  /// saying "not found").
  final bool loaded;

  List<ProjectFile> filesOf(String projectId) =>
      [for (final f in files) if (f.projectId == projectId) f];
}

/// Fictional demo projects (same ids as the live demo data).
abstract final class DemoProjects {
  static final projects = [
    Project(
      id: 'p1',
      title: 'Podcast « Voix du campus »',
      description: 'Une série de 6 épisodes avec des étudiants et des '
          'enseignants sur la vie au campus.',
      type: ProjectType.culture,
      stage: ProjectStage.production,
      ownerId: 'yasmine',
      memberIds: const ['adam'],
      createdAt: DateTime(2026, 10, 20, 11),
      history: [
        ProjectEvent(
          type: ProjectEventType.created,
          at: DateTime(2026, 10, 20, 11),
          actorId: 'yasmine',
        ),
        ProjectEvent(
          type: ProjectEventType.fileAdded,
          at: DateTime(2026, 10, 22, 16),
          actorId: 'yasmine',
          detail: 'Conducteur épisode 1.pdf',
        ),
        ProjectEvent(
          type: ProjectEventType.stageChanged,
          at: DateTime(2026, 10, 23, 9),
          actorId: 'yasmine',
          detail: 'production',
        ),
      ],
    ),
    Project(
      id: 'p2',
      title: 'MOOC « Introduction à l’IA »',
      description: 'Huit capsules vidéo de 10 minutes pour le cours en ligne '
          'de première année.',
      type: ProjectType.teaching,
      stage: ProjectStage.preProduction,
      ownerId: 'rami',
      createdAt: DateTime(2026, 11, 9, 15),
      history: [
        ProjectEvent(
          type: ProjectEventType.created,
          at: DateTime(2026, 11, 9, 15),
          actorId: 'rami',
        ),
      ],
    ),
    Project(
      id: 'p3',
      title: 'Court-métrage du Club Audiovisuel',
      description: 'Un court-métrage de fiction de 8 minutes tourné au '
          'Plateau TV et sur fond vert.',
      type: ProjectType.culture,
      stage: ProjectStage.postProduction,
      ownerId: 'adam',
      createdAt: DateTime(2026, 9, 28, 10),
      history: [
        ProjectEvent(
          type: ProjectEventType.created,
          at: DateTime(2026, 9, 28, 10),
          actorId: 'adam',
        ),
      ],
    ),
  ];

  static final files = [
    ProjectFile(
      id: 'f1',
      projectId: 'p1',
      kind: FileKind.rundown,
      name: 'Conducteur épisode 1.pdf',
      path: 'p1/conducteur-episode-1.pdf',
      sizeBytes: 182400,
      uploadedBy: 'yasmine',
      uploadedAt: DateTime(2026, 10, 22, 16),
    ),
    ProjectFile(
      id: 'f2',
      projectId: 'p3',
      kind: FileKind.script,
      name: 'Script court-métrage.pdf',
      path: 'p3/script-court-metrage.pdf',
      sizeBytes: 241000,
      uploadedBy: 'adam',
      uploadedAt: DateTime(2026, 9, 30, 18),
    ),
  ];
}

class ProjectsNotifier extends Notifier<ProjectsState> {
  @override
  ProjectsState build() => isLive
      ? const ProjectsState(loaded: false)
      : ProjectsState(
          projects: List.of(DemoProjects.projects),
          files: List.of(DemoProjects.files),
        );

  int _counter = 10;

  void load(ProjectsState fresh) => state = fresh;

  Project _find(String id) => state.projects.firstWhere((p) => p.id == id);

  void _replace(Project updated) => state = ProjectsState(
        projects: [
          for (final p in state.projects) p.id == updated.id ? updated : p,
        ],
        files: state.files,
      );

  /// Offline version of create_project.
  Project create({
    required Person by,
    required String title,
    required ProjectType type,
    String? description,
    required DateTime now,
  }) {
    if (!canCreateProject(by)) throw StateError('not_a_requester');
    final p = Project(
      id: 'p${_counter++}',
      title: title,
      description: description,
      type: type,
      stage: ProjectStage.preProduction,
      ownerId: by.id,
      createdAt: now,
      history: [
        ProjectEvent(type: ProjectEventType.created, at: now, actorId: by.id),
      ],
    );
    state = ProjectsState(projects: [p, ...state.projects], files: state.files);
    return p;
  }

  /// Offline version of advance_project.
  void advance(String id, {required Person by, required WorldState world}) {
    final p = _find(id);
    if (!canAdvance(by, p)) throw StateError('not_allowed');
    final problem = advanceProblem(p, state.files, world.bookings);
    if (problem != null) throw StateError(problem);
    final next = p.stage.next!;
    _replace(
      p.copyWith(
        stage: next,
        history: [
          ...p.history,
          ProjectEvent(
            type: ProjectEventType.stageChanged,
            at: world.now,
            actorId: by.id,
            detail: next.name,
          ),
        ],
      ),
    );
  }

  /// Offline version of add_project_file.
  void addFile(ProjectFile f, {required DateTime now}) {
    final p = _find(f.projectId);
    state = ProjectsState(
      projects: [
        for (final x in state.projects)
          x.id == p.id
              ? x.copyWith(
                  history: [
                    ...x.history,
                    ProjectEvent(
                      type: ProjectEventType.fileAdded,
                      at: now,
                      actorId: f.uploadedBy,
                      detail: f.name,
                    ),
                  ],
                )
              : x,
      ],
      files: [...state.files, f],
    );
  }

  void removeFile(String fileId) => state = ProjectsState(
        projects: state.projects,
        files: [for (final f in state.files) if (f.id != fileId) f],
      );
}

final projectsProvider =
    NotifierProvider<ProjectsNotifier, ProjectsState>(ProjectsNotifier.new);

/// The projects the signed-in person may see, newest first.
final myProjectsProvider = Provider<List<Project>>((ref) {
  final me = ref.watch(currentPersonProvider);
  final all = ref.watch(projectsProvider).projects;
  return [
    for (final p in all)
      if (canSeeProject(me, p)) p,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});
