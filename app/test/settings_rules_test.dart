import 'package:euromed_studios/data/demo_world.dart';
import 'package:euromed_studios/domain/bookings.dart';
import 'package:euromed_studios/domain/policy.dart';
import 'package:euromed_studios/domain/rules/settings_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = RulesDraft.of(const Policy());
  final people = {for (final p in DemoWorld.people) p.id: p};

  test('default rules are valid', () => expect(rulesProblem(base), isNull));

  test('hours must make sense', () {
    expect(rulesProblem(base.copyWith(openingHour: 18, closingHour: 9)),
        'bad_hours');
    expect(rulesProblem(base.copyWith(closingHour: 24)), 'bad_hours');
  });

  test('the day holds a whole number of slots', () {
    expect(rulesProblem(base.copyWith(slotMinutes: 45)), 'bad_slot');
    // 9 h–18 h = 9 hours: 2-hour slots don't fit.
    expect(rulesProblem(base.copyWith(slotMinutes: 120)), 'slot_misfit');
    expect(
      rulesProblem(base.copyWith(slotMinutes: 120, closingHour: 17)),
      isNull,
    );
  });

  test('limits are bounded', () {
    expect(rulesProblem(base.copyWith(maxAdvanceDays: 0)), 'bad_advance');
    expect(rulesProblem(base.copyWith(studentQuotaMinutes: 45)), 'bad_quota');
    expect(rulesProblem(base.copyWith(qrGraceMinutes: 90)), 'bad_grace');
  });

  test('changes are described like in the activity log', () {
    final c = rulesChanges(base, base.copyWith(studentQuotaMinutes: 180));
    expect(c.single, 'Quota étudiant : 2 → 3 h/semaine');
    expect(rulesChanges(base, base), isEmpty);
  });

  test('maintenance: manager or admin, future, with a reason, no overlap', () {
    final now = DateTime(2026, 11, 16, 8);
    final start = DateTime(2026, 11, 17, 9);
    final end = DateTime(2026, 11, 17, 12);
    String? check({String by = 'tazi', String reason = 'Réparation',
            List<MaintenanceBlock> existing = const []}) =>
        maintenanceProblem(
          by: people[by]!,
          start: start,
          end: end,
          reason: reason,
          now: now,
          existing: existing,
        );
    expect(check(), isNull);
    expect(check(by: 'yasmine'), 'not_allowed');
    expect(check(reason: 'x'), 'reason_required');
    expect(
      check(existing: [
        MaintenanceBlock(
          roomId: 'area1',
          start: DateTime(2026, 11, 17, 11),
          end: DateTime(2026, 11, 17, 13),
          reason: 'déjà',
        ),
      ]),
      'overlap',
    );
  });

  test('charter versions', () {
    expect(charterVersionProblem('2.0', '1.0'), isNull);
    expect(charterVersionProblem('1.0', '1.0'), 'same_version');
    expect(charterVersionProblem('v2', '1.0'), 'bad_version');
  });
}
