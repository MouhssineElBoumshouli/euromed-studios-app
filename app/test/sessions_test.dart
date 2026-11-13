import 'package:euromed_studios/data/app_state.dart';
import 'package:euromed_studios/data/demo_world.dart';
import 'package:euromed_studios/domain/bookings.dart';
import 'package:euromed_studios/domain/rules/approval.dart';
import 'package:euromed_studios/domain/rules/sessions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Booking session({List<BookingEvent> extra = const []}) => Booking(
      id: 's1',
      reference: 'ES-2026-0900',
      requesterId: 'yasmine',
      requesterType: RequesterType.student,
      studioId: 'podcast',
      start: DateTime(2026, 11, 16, 10),
      end: DateTime(2026, 11, 16, 11),
      activity: Activity.recording,
      status: BookingStatus.approved,
      history: [
        BookingEvent(
          type: BookingEventType.submitted,
          at: DateTime(2026, 11, 10),
          actorId: 'yasmine',
        ),
        ...extra,
      ],
    );

final checkedIn = BookingEvent(
  type: BookingEventType.checkedIn,
  at: DateTime(2026, 11, 16, 10, 2),
  actorId: 'haddad',
);

void main() {
  group('door check', () {
    final b = session();
    test('opens exactly at the early window', () {
      expect(checkInProblem(b, DateTime(2026, 11, 16, 9, 44), earlyMinutes: 15),
          isNotNull);
      expect(checkInProblem(b, DateTime(2026, 11, 16, 9, 45), earlyMinutes: 15),
          isNull);
    });
    test('closes at the end of the slot', () {
      expect(checkInProblem(b, DateTime(2026, 11, 16, 10, 59), earlyMinutes: 15),
          isNull);
      expect(checkInProblem(b, DateTime(2026, 11, 16, 11), earlyMinutes: 15),
          isNotNull);
    });
    test('only once', () {
      expect(
        checkInProblem(session(extra: [checkedIn]), DateTime(2026, 11, 16, 10, 5),
            earlyMinutes: 15),
        isNotNull,
      );
    });
  });

  group('closing and absences', () {
    test('a session closes only after a check-in', () {
      expect(canComplete(session(), DateTime(2026, 11, 16, 12)), isFalse);
      expect(
        canComplete(session(extra: [checkedIn]), DateTime(2026, 11, 16, 10, 30)),
        isTrue,
      );
    });
    test('an absence can be noted 15 minutes after the start, never after a check-in', () {
      expect(canMarkNoShow(session(), DateTime(2026, 11, 16, 10, 14)), isFalse);
      expect(canMarkNoShow(session(), DateTime(2026, 11, 16, 10, 15)), isTrue);
      expect(
        canMarkNoShow(session(extra: [checkedIn]), DateTime(2026, 11, 16, 10, 30)),
        isFalse,
      );
    });
    test('phases follow the clock', () {
      final b = session();
      expect(phaseOf(b, DateTime(2026, 11, 16, 9)), SessionPhase.upcoming);
      expect(phaseOf(b, DateTime(2026, 11, 16, 9, 50)), SessionPhase.ready);
      expect(phaseOf(b, DateTime(2026, 11, 16, 10, 20)), SessionPhase.late);
      expect(phaseOf(b, DateTime(2026, 11, 16, 11)), SessionPhase.missed);
      expect(phaseOf(session(extra: [checkedIn]), DateTime(2026, 11, 16, 10, 20)),
          SessionPhase.inProgress);
    });
    test('a started session can no longer be cancelled', () {
      final me = DemoWorld.people.firstWhere((p) => p.id == 'yasmine');
      final b = session(extra: [checkedIn]);
      expect(canCancel(me, b, DateTime(2026, 11, 16, 9, 50)), isFalse);
    });
  });

  test('students cannot check anyone in', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final student = DemoWorld.people.firstWhere((p) => p.id == 'yasmine');
    final b = c
        .read(worldProvider)
        .bookings
        .firstWhere((x) => x.status == BookingStatus.approved);
    expect(
      () => c.read(worldProvider.notifier).checkIn(b.id, by: student),
      throwsStateError,
    );
  });
}
