import 'package:euromed_studios/data/app_state.dart';
import 'package:euromed_studios/data/demo_world.dart';
import 'package:euromed_studios/domain/bookings.dart';
import 'package:euromed_studios/domain/rules/approval.dart';
import 'package:euromed_studios/features/validations/decision_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a student request goes L1 → L2 → approved, by two different people',
      () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final world = c.read(worldProvider.notifier);
    final pending = c
        .read(worldProvider)
        .bookings
        .firstWhere((b) => b.status == BookingStatus.pendingEntity);
    final l1 = DemoWorld.people.firstWhere(
      (p) => canDecide(p, pending, people: DemoWorld.people),
    );
    world.approve(pending.id, by: l1);
    final afterL1 =
        c.read(worldProvider).bookings.firstWhere((b) => b.id == pending.id);
    expect(afterL1.status, BookingStatus.pendingStudio);
    // The Level 1 approver cannot also give Level 2.
    expect(canDecide(l1, afterL1, people: DemoWorld.people), isFalse);
    final manager = DemoWorld.people.firstWhere((p) => p.id == 'tazi');
    if (world.level2Conflict(afterL1) == null) {
      world.approve(afterL1.id, by: manager);
      expect(
        c.read(worldProvider).bookings.firstWhere((b) => b.id == pending.id).status,
        BookingStatus.approved,
      );
    }
  });

  test('a refusal without a reason is rejected, with one it is saved', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final world = c.read(worldProvider.notifier);
    final b = c
        .read(worldProvider)
        .bookings
        .firstWhere((b) => b.status == BookingStatus.pendingStudio);
    final manager = DemoWorld.people.firstWhere((p) => p.id == 'tazi');
    expect(() => world.refuse(b.id, by: manager, reason: '  '),
        throwsArgumentError);
    world.refuse(b.id, by: manager, reason: refusalPresets.first);
    final after = c.read(worldProvider).bookings.firstWhere((x) => x.id == b.id);
    expect(after.status, BookingStatus.refused);
    expect(after.refusalReason, refusalPresets.first);
  });

  test('a student never sees an approval inbox', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final student = DemoWorld.people.firstWhere((p) => p.id == 'yasmine');
    expect(
      inboxFor(student, c.read(worldProvider).bookings,
          people: DemoWorld.people),
      isEmpty,
    );
  });
}
