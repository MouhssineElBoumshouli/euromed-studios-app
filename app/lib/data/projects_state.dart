/// Projects, their files, thread messages and invitations, held in memory
/// like the bookings.
///
/// Offline (tests), [ProjectsNotifier] works on the demo data below and
/// applies the same rules as the server. Live, [LiveSync] loads the rows
/// this person may see and calls [load].
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
    this.messages = const [],
    this.invites = const [],
    this.loaded = true,
  });
  final List<Project> projects;
  final List<ProjectFile> files;
  final List<ProjectMessage> messages;
  final List<ProjectInvite> invites;

  /// False until the first live load (so a deep link waits instead of
  /// saying "not found").
  final bool loaded;

  List<ProjectFile> filesOf(String projectId) =>
      [for (final f in files) if (f.projectId == projectId) f];

  /// Oldest first.
  List<ProjectMessage> messagesOf(String projectId) => [
        for (final m in messages)
          if (m.projectId == projectId) m,
      ]..sort((a, b) => a.at.compareTo(b.at));

  List<ProjectInvite> pendingInvitesOf(String projectId) => [
        for (final i in invites)
          if (i.projectId == projectId && i.status == InviteStatus.pending) i,
      ];

  List<ProjectInvite> invitesFor(String personId) => [
        for (final i in invites)
          if (i.inviteeId == personId && i.status == InviteStatus.pending) i,
      ]..sort((a, b) => b.at.compareTo(a.at));

  ProjectsState copyWith({
    List<Project>? projects,
    List<ProjectFile>? files,
    List<ProjectMessage>? messages,
    List<ProjectInvite>? invites,
  }) =>
      ProjectsState(
        projects: projects ?? this.projects,
        files: files ?? this.files,
        messages: messages ?? this.messages,
        invites: invites ?? this.invites,
        loaded: loaded,
      );
}

/// Fictional demo projects (same ids and story as the live demo data).
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
        ProjectEvent(
          type: ProjectEventType.memberInvited,
          at: DateTime(2026, 11, 11, 5),
          actorId: 'yasmine',
          detail: 'rami',
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
      createdAt: DateTime(2026, 11, 7, 15),
      history: [
        ProjectEvent(
          type: ProjectEventType.created,
          at: DateTime(2026, 11, 7, 15),
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
      postStatus: PostStatus.correctionRequested,
      ownerId: 'adam',
      createdAt: DateTime(2026, 9, 27, 10),
      history: [
        ProjectEvent(
          type: ProjectEventType.created,
          at: DateTime(2026, 9, 27, 10),
          actorId: 'adam',
        ),
        ProjectEvent(
          type: ProjectEventType.stageChanged,
          at: DateTime(2026, 11, 3, 10),
          actorId: 'adam',
          detail: 'postProduction',
        ),
        ProjectEvent(
          type: ProjectEventType.postStatus,
          at: DateTime(2026, 11, 5, 10),
          actorId: 'haddad',
          detail: 'inProgress',
        ),
        ProjectEvent(
          type: ProjectEventType.correction,
          at: DateTime(2026, 11, 9, 10),
          actorId: 'adam',
          detail: 'Raccourcir la scène 4, remonter le son des dialogues',
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
      sizeBytes: 640,
      uploadedBy: 'yasmine',
      uploadedAt: DateTime(2026, 10, 22, 16),
    ),
    ProjectFile(
      id: 'f2',
      projectId: 'p3',
      kind: FileKind.script,
      name: 'Script court-métrage.pdf',
      path: 'p3/script-court-metrage.pdf',
      sizeBytes: 650,
      uploadedBy: 'adam',
      uploadedAt: DateTime(2026, 9, 29, 18),
    ),
  ];

  static final messages = [
    ProjectMessage(
      id: 'm1',
      projectId: 'p3',
      authorId: 'haddad',
      kind: MessageKind.status,
      body: 'inProgress',
      at: DateTime(2026, 11, 5, 10),
    ),
    ProjectMessage(
      id: 'm2',
      projectId: 'p3',
      authorId: 'haddad',
      kind: MessageKind.message,
      body: 'Premier montage en ligne. Durée actuelle : 8 min 40. Dites-nous '
          'si le rythme vous convient.',
      at: DateTime(2026, 11, 8, 10),
    ),
    ProjectMessage(
      id: 'm3',
      projectId: 'p3',
      authorId: 'adam',
      kind: MessageKind.correction,
      body: 'Merci ! Pouvez-vous raccourcir la scène 4 d’environ 20 secondes '
          'et remonter un peu le son des dialogues ?',
      at: DateTime(2026, 11, 9, 10),
    ),
  ];

  static final invites = [
    ProjectInvite(
      id: 'i1',
      projectId: 'p1',
      projectTitle: 'Podcast « Voix du campus »',
      inviteeId: 'rami',
      invitedBy: 'yasmine',
      status: InviteStatus.pending,
      at: DateTime(2026, 11, 11, 5),
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
          messages: List.of(DemoProjects.messages),
          invites: List.of(DemoProjects.invites),
        );

  int _counter = 100;
  String _id(String prefix) => '$prefix${_counter++}';

  void load(ProjectsState fresh) => state = fresh;

  Project _find(String id) => state.projects.firstWhere(
        (p) => p.id == id,
        orElse: () => throw StateError('not_found'),
      );

  ProjectInvite _invite(String id) => state.invites.firstWhere(
        (i) => i.id == id,
        orElse: () => throw StateError('not_found'),
      );

  void _replace(Project updated) => state = state.copyWith(
        projects: [
          for (final p in state.projects) p.id == updated.id ? updated : p,
        ],
      );

  void _say(String projectId, String by, MessageKind kind, String body,
      DateTime now) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ProjectMessage(
          id: _id('m'),
          projectId: projectId,
          authorId: by,
          kind: kind,
          body: body,
          at: now,
        ),
      ],
    );
  }

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
      id: _id('p'),
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
    state = state.copyWith(projects: [p, ...state.projects]);
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
      p
          .copyWith(stage: next)
          .log(ProjectEventType.stageChanged, by.id, world.now, next.name),
    );
  }

  /// Offline version of add_project_file.
  void addFile(ProjectFile f, {required DateTime now}) {
    final p = _find(f.projectId);
    _replace(p.log(ProjectEventType.fileAdded, f.uploadedBy, now, f.name));
    state = state.copyWith(files: [...state.files, f]);
  }

  void removeFile(String fileId, {required String by, required DateTime now}) {
    final f = state.files.firstWhere(
      (x) => x.id == fileId,
      orElse: () => throw StateError('not_found'),
    );
    _replace(
      _find(f.projectId).log(ProjectEventType.fileRemoved, by, now, f.name),
    );
    state = state.copyWith(
      files: [for (final x in state.files) if (x.id != fileId) x],
    );
  }

  /// Offline version of set_post_status.
  void setPostStatus(
    String id,
    PostStatus to, {
    required Person by,
    required DateTime now,
  }) {
    final p = _find(id);
    if (!canSetPostStatus(by, p, to)) throw StateError('bad_transition');
    _replace(
      p
          .copyWith(
            postStatus: to,
            // Resuming the edit clears the previous check comment.
            clearQcNote: to == PostStatus.inProgress,
            qcNote: to == PostStatus.inProgress ? null : p.qcNote,
          )
          .log(ProjectEventType.postStatus, by.id, now, to.name),
    );
    _say(id, by.id, MessageKind.status, to.name, now);
  }

  /// Offline version of post_project_message.
  void postMessage(
    String id,
    String body, {
    required Person by,
    required DateTime now,
    bool correction = false,
  }) {
    final p = _find(id);
    if (!canMessage(by, p)) throw StateError('not_allowed');
    final text = body.trim();
    if (text.isEmpty) throw StateError('empty');
    if (text.length > maxMessageLength) throw StateError('too_long');
    if (correction) {
      if (!canRequestCorrection(by, p)) throw StateError('no_correction_now');
      final short = text.length > 140 ? text.substring(0, 140) : text;
      _replace(
        p
            .copyWith(postStatus: PostStatus.correctionRequested)
            .log(ProjectEventType.correction, by.id, now, short),
      );
    }
    _say(
      id,
      by.id,
      correction ? MessageKind.correction : MessageKind.message,
      text,
      now,
    );
  }

  /// Offline version of quality_check (P-08).
  void qualityCheck(
    String id, {
    required Person by,
    required bool passed,
    required DateTime now,
    String? note,
    String? deliveryUrl,
  }) {
    final p = _find(id);
    if (!canQualityCheck(by, p)) throw StateError('not_ready');
    if (passed) {
      if (deliveryUrl == null || !isValidDeliveryLink(deliveryUrl)) {
        throw StateError('bad_link');
      }
      _replace(
        p
            .copyWith(
              stage: ProjectStage.archived,
              deliveryUrl: deliveryUrl.trim(),
              deliveredAt: now,
              qcNote: note,
              clearQcNote: true,
            )
            .log(ProjectEventType.qcPassed, by.id, now),
      );
      _say(id, by.id, MessageKind.qcPassed,
          note ?? 'Contrôle qualité validé.', now);
    } else {
      if (note == null || note.trim().isEmpty) {
        throw StateError('reason_required');
      }
      _replace(
        p
            .copyWith(postStatus: PostStatus.correctionRequested, qcNote: note)
            .log(ProjectEventType.qcFailed, by.id, now, note),
      );
      _say(id, by.id, MessageKind.qcFailed, note, now);
    }
  }

  /// Offline version of invite_member.
  void invite(
    String id,
    String personId, {
    required Person by,
    required DateTime now,
  }) {
    final p = _find(id);
    if (p.ownerId != by.id) throw StateError('not_allowed');
    if (p.stage == ProjectStage.archived) throw StateError('archived');
    if (!canInvite(by, p, pending: state.pendingInvitesOf(id).length)) {
      throw StateError('too_many_members');
    }
    if (p.involves(personId)) throw StateError('already_member');
    if (state.pendingInvitesOf(id).any((i) => i.inviteeId == personId)) {
      throw StateError('already_invited');
    }
    state = state.copyWith(
      invites: [
        ...state.invites,
        ProjectInvite(
          id: _id('i'),
          projectId: id,
          projectTitle: p.title,
          inviteeId: personId,
          invitedBy: by.id,
          status: InviteStatus.pending,
          at: now,
        ),
      ],
    );
    _replace(p.log(ProjectEventType.memberInvited, by.id, now, personId));
  }

  /// Offline version of answer_invite.
  void answerInvite(
    String inviteId, {
    required Person by,
    required bool accept,
    required DateTime now,
  }) {
    final inv = _invite(inviteId);
    if (inv.inviteeId != by.id) throw StateError('not_found');
    if (inv.status != InviteStatus.pending) {
      throw StateError('already_answered');
    }
    final target = _find(inv.projectId);
    if (accept && target.stage == ProjectStage.archived) {
      throw StateError('archived');
    }
    if (accept && target.memberIds.length >= maxMembers) {
      throw StateError('too_many_members');
    }
    state = state.copyWith(
      invites: [
        for (final i in state.invites)
          i.id == inviteId
              ? i.withStatus(
                  accept ? InviteStatus.accepted : InviteStatus.declined,
                )
              : i,
      ],
    );
    if (accept) {
      final p = _find(inv.projectId);
      _replace(
        p
            .copyWith(memberIds: [...p.memberIds, by.id])
            .log(ProjectEventType.memberJoined, by.id, now),
      );
    }
  }

  void cancelInvite(String inviteId, {required Person by}) {
    final inv = _invite(inviteId);
    if (inv.status != InviteStatus.pending) throw StateError('not_found');
    if (_find(inv.projectId).ownerId != by.id) throw StateError('not_allowed');
    state = state.copyWith(
      invites: [
        for (final i in state.invites)
          i.id == inviteId ? i.withStatus(InviteStatus.cancelled) : i,
      ],
    );
  }

  /// The owner removes a collaborator, or a collaborator leaves.
  void removeMember(
    String id,
    String personId, {
    required Person by,
    required DateTime now,
  }) {
    final p = _find(id);
    if (!(p.ownerId == by.id || by.id == personId)) {
      throw StateError('not_allowed');
    }
    if (!p.memberIds.contains(personId)) throw StateError('not_member');
    _replace(
      p.copyWith(memberIds: [
        for (final m in p.memberIds)
          if (m != personId) m,
      ]).log(
        by.id == personId
            ? ProjectEventType.memberLeft
            : ProjectEventType.memberRemoved,
        by.id,
        now,
        personId,
      ),
    );
  }
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

/// Invitations waiting for the signed-in person.
final myInvitesProvider = Provider<List<ProjectInvite>>((ref) {
  final me = ref.watch(currentPersonProvider);
  return ref.watch(projectsProvider).invitesFor(me.id);
});
