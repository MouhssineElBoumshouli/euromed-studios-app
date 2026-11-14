import 'package:euromed_studios/data/demo_world.dart';
import 'package:euromed_studios/data/projects_state.dart';
import 'package:euromed_studios/domain/bookings.dart';
import 'package:euromed_studios/domain/projects.dart';
import 'package:euromed_studios/domain/rules/projects.dart';
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
}
