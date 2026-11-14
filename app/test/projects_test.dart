import 'package:euromed_studios/data/demo_world.dart';
import 'package:euromed_studios/data/projects_state.dart';
import 'package:euromed_studios/domain/bookings.dart';
import 'package:euromed_studios/domain/projects.dart';
import 'package:euromed_studios/domain/rules/notifications.dart';
import 'package:euromed_studios/domain/rules/projects.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final people = {for (final p in DemoWorld.people) p.id: p};
  final p1 = DemoProjects.projects.firstWhere((p) => p.id == 'p1');
  final p2 = DemoProjects.projects.firstWhere((p) => p.id == 'p2');
  final p3 = DemoProjects.projects.firstWhere((p) => p.id == 'p3');

  group('who sees a project', () {
    test('owner and collaborators see it', () {
      expect(canSeeProject(people['yasmine']!, p1), isTrue);
      expect(canSeeProject(people['adam']!, p1), isTrue);
    });
    test('another student does not', () {
      expect(canSeeProject(people['rami']!, p1), isFalse);
    });
    test('studio staff see every project', () {
      expect(canSeeProject(people['tazi']!, p2), isTrue);
    });
    test('level-1 approvers are not project supervisors', () {
      expect(canSeeProject(people['benjelloun']!, p1), isFalse);
    });
  });

  group('moving to the next stage', () {
    test('pre-production needs a preparation file (R-22)', () {
      expect(advanceProblem(p2, const [], const []), isNotNull);
      final other = ProjectFile(
        id: 'x',
        projectId: 'p2',
        kind: FileKind.other,
        name: 'notes.txt',
        path: 'p2/notes.txt',
        sizeBytes: 10,
        uploadedBy: 'rami',
        uploadedAt: DateTime(2026, 11, 10),
      );
      expect(advanceProblem(p2, [other], const []), isNotNull);
      final script = ProjectFile(
        id: 'y',
        projectId: 'p2',
        kind: FileKind.script,
        name: 'script.pdf',
        path: 'p2/script.pdf',
        sizeBytes: 10,
        uploadedBy: 'rami',
        uploadedAt: DateTime(2026, 11, 10),
      );
      expect(advanceProblem(p2, [script], const []), isNull);
    });

    test('production needs a validated session linked to the project', () {
      final linked = DemoWorld.bookings
          .where((b) => b.projectId == 'p1')
          .toList();
      final approved = linked.any(
        (b) =>
            b.status == BookingStatus.approved ||
            b.status == BookingStatus.completed,
      );
      expect(advanceProblem(p1, const [], linked) == null, approved);
    });

    test('post-production waits for the quality check', () {
      expect(advanceProblem(p3, const [], const []), isNotNull);
      expect(canAdvance(people['adam']!, p3), isFalse);
    });

    test('only the owner or studio management may advance', () {
      expect(canAdvance(people['yasmine']!, p1), isTrue);
      expect(canAdvance(people['adam']!, p1), isFalse);
      expect(canAdvance(people['tazi']!, p1), isTrue);
    });
  });

  test('approvers cannot create projects; requesters can', () {
    expect(canCreateProject(people['yasmine']!), isTrue);
    expect(canCreateProject(people['amrani']!), isFalse);
  });

  group('post-production and quality check (P-07, P-08)', () {
    late ProviderContainer box;
    late ProjectsNotifier store;
    final now = DateTime(2026, 11, 11, 10);
    final haddad = people['haddad']!;
    final adam = people['adam']!;
    Project p3() => box.read(projectsProvider).projects
        .firstWhere((p) => p.id == 'p3');

    setUp(() {
      box = ProviderContainer();
      store = box.read(projectsProvider.notifier);
    });
    tearDown(() => box.dispose());

    test('only the technical team moves the editing status', () {
      expect(
        () => store.setPostStatus('p3', PostStatus.inProgress,
            by: adam, now: now),
        throwsStateError,
      );
      store.setPostStatus('p3', PostStatus.inProgress, by: haddad, now: now);
      expect(p3().postStatus, PostStatus.inProgress);
    });

    test('ready for check only from "in progress"', () {
      expect(
        () => store.setPostStatus('p3', PostStatus.readyForCheck,
            by: haddad, now: now),
        throwsStateError,
      );
    });

    test('the owner asks for a correction while editing', () {
      store.setPostStatus('p3', PostStatus.inProgress, by: haddad, now: now);
      store.postMessage('p3', 'Plus de son', by: adam, now: now,
          correction: true);
      expect(p3().postStatus, PostStatus.correctionRequested);
      final last = box.read(projectsProvider).messagesOf('p3').last;
      expect(last.kind, MessageKind.correction);
    });

    test('someone outside the project cannot write in the thread', () {
      expect(
        () => store.postMessage('p3', 'Bonjour', by: people['rami']!,
            now: now),
        throwsStateError,
      );
    });

    test('a failed check needs a reason and sends back to corrections', () {
      store.setPostStatus('p3', PostStatus.inProgress, by: haddad, now: now);
      store.setPostStatus('p3', PostStatus.readyForCheck, by: haddad,
          now: now);
      expect(
        () => store.qualityCheck('p3', by: haddad, passed: false, now: now),
        throwsStateError,
      );
      store.qualityCheck('p3', by: haddad, passed: false, now: now,
          note: 'Son trop bas');
      expect(p3().postStatus, PostStatus.correctionRequested);
      expect(p3().stage, ProjectStage.postProduction);
    });

    test('a passed check needs a secure link, then archives', () {
      store.setPostStatus('p3', PostStatus.inProgress, by: haddad, now: now);
      store.setPostStatus('p3', PostStatus.readyForCheck, by: haddad,
          now: now);
      expect(
        () => store.qualityCheck('p3', by: haddad, passed: true, now: now,
            deliveryUrl: 'http://exemple.ma/film'),
        throwsStateError,
      );
      expect(
        () => store.qualityCheck('p3', by: adam, passed: true, now: now,
            deliveryUrl: 'https://exemple.ma/film'),
        throwsStateError,
      );
      store.qualityCheck('p3', by: haddad, passed: true, now: now,
          deliveryUrl: 'https://exemple.ma/film');
      expect(p3().stage, ProjectStage.archived);
      expect(p3().deliveryUrl, 'https://exemple.ma/film');
      expect(canMessage(adam, p3()), isFalse);
    });
  });

  group('members (R-27)', () {
    late ProviderContainer box;
    late ProjectsNotifier store;
    final now = DateTime(2026, 11, 11, 10);
    Project p2() => box.read(projectsProvider).projects
        .firstWhere((p) => p.id == 'p2');

    setUp(() {
      box = ProviderContainer();
      store = box.read(projectsProvider.notifier);
    });
    tearDown(() => box.dispose());

    test('owner invites, the person accepts and joins', () {
      store.invite('p2', 'yasmine', by: people['rami']!, now: now);
      final inv = box.read(projectsProvider).invitesFor('yasmine').single;
      expect(
        () => store.answerInvite(inv.id, by: people['adam']!, accept: true,
            now: now),
        throwsStateError,
      );
      store.answerInvite(inv.id, by: people['yasmine']!, accept: true,
          now: now);
      expect(p2().memberIds, contains('yasmine'));
      expect(box.read(projectsProvider).invitesFor('yasmine'), isEmpty);
    });

    test('only the owner invites, and not twice', () {
      expect(
        () => store.invite('p1', 'nadia', by: people['adam']!, now: now),
        throwsStateError,
      );
      store.invite('p2', 'nadia', by: people['rami']!, now: now);
      expect(
        () => store.invite('p2', 'nadia', by: people['rami']!, now: now),
        throwsStateError,
      );
    });

    test('a collaborator can leave; the owner can remove', () {
      store.removeMember('p1', 'adam', by: people['adam']!, now: now);
      final p1 = box.read(projectsProvider).projects
          .firstWhere((p) => p.id == 'p1');
      expect(p1.memberIds, isNot(contains('adam')));
    });
  });

  test('notices: invitation for the invitee, check for the tech team', () {
    final invites = DemoProjects.invites;
    final forRami = projectNoticesFor(people['rami']!,
        DemoProjects.projects, invites, DateTime(2026, 11, 11, 10),
        nameOf: (id) => id);
    expect(forRami.where((n) => n.actionable), isNotEmpty);

    final ready = DemoProjects.projects
        .firstWhere((p) => p.id == 'p3')
        .copyWith(postStatus: PostStatus.readyForCheck);
    final forHaddad = projectNoticesFor(people['haddad']!, [ready],
        const [], DateTime(2026, 11, 11, 10), nameOf: (id) => id);
    expect(forHaddad.any((n) => n.title == 'Contrôle qualité à faire'),
        isTrue);
  });
}
