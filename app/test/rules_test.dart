import 'package:euromed_studios/data/app_state.dart';
import 'package:euromed_studios/data/demo_world.dart';
import 'package:euromed_studios/domain/bookings.dart';
import 'package:euromed_studios/domain/people.dart';
import 'package:euromed_studios/domain/rules/approval.dart';
import 'package:euromed_studios/domain/rules/availability.dart';
import 'package:euromed_studios/domain/rules/quota.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DemoWorld.now; // Wed 11 Nov 2026, 10:05
  final policy = DemoWorld.policy;

  List<Slot> slots(String studioId, DateTime day, {List<Booking>? bookings}) =>
      slotsFor(
        studio: studioById(studioId),
        day: day,
        policy: policy,
        allStudios: DemoWorld.studios,
        bookings: bookings ?? DemoWorld.bookings,
        maintenance: DemoWorld.maintenance,
        now: now,
      );

  Slot at(List<Slot> s, int hour) => s.firstWhere((x) => x.start.hour == hour);

  group('Availability (R-10, R-15, Q1, Q3)', () {
    test('a day has one slot per opening hour (9:00–18:00)', () {
      expect(slots('podcast', DateTime(2026, 11, 16)).length, 9);
    });

    test('weekends are closed', () {
      expect(slots('podcast', DateTime(2026, 11, 15)), isEmpty); // Sunday
    });

    test('an approved booking makes the slot taken', () {
      final s = slots('plateau_tv', DateTime(2026, 11, 12));
      expect(at(s, 14).state, SlotState.taken);
    });

    test('a pending request locks the slot as "En attente"', () {
      final s = slots('podcast', DateTime(2026, 11, 16));
      expect(at(s, 10).state, SlotState.pending);
    });

    test('studios in the same room block each other (Plateau TV ↔ Radio)', () {
      final s = slots('radio', DateTime(2026, 11, 12));
      expect(at(s, 14).state, SlotState.taken);
      expect(at(s, 14).blockingStudioId, 'plateau_tv');
    });

    test('studios in other rooms are not blocked', () {
      final s = slots('chroma', DateTime(2026, 11, 12));
      expect(at(s, 14).state, SlotState.free);
    });

    test('slots that already started are past', () {
      final s = slots('chroma', DateTime(2026, 11, 11));
      expect(at(s, 9).state, SlotState.past);
      expect(at(s, 10).state, SlotState.past); // 10:00 < 10:05
      expect(at(s, 11).state, SlotState.free);
    });

    test('maintenance blocks every studio of the room', () {
      final s = slots('speedmooc', DateTime(2026, 11, 11));
      expect(at(s, 14).state, SlotState.maintenance);
      expect(at(s, 16).state, SlotState.maintenance);
      expect(at(s, 17).state, SlotState.free);
    });

    test('refused and cancelled bookings free the slot', () {
      final withRefusal = [
        for (final x in DemoWorld.bookings)
          x.id == 'b3' ? x.copyWith(status: BookingStatus.refused) : x,
      ];
      final before = slots('chroma', DateTime(2026, 11, 18));
      final after =
          slots('chroma', DateTime(2026, 11, 18), bookings: withRefusal);
      expect(at(before, 9).state, SlotState.pending);
      expect(at(after, 9).state, SlotState.free);
    });

    test('non-bookable spaces have no slots', () {
      expect(slots('salon_vip', DateTime(2026, 11, 16)), isEmpty);
    });

    test('booking window: today to 30 days ahead, working days only', () {
      expect(isBookableDay(DateTime(2026, 11, 11), now, policy), isTrue);
      expect(isBookableDay(DateTime(2026, 11, 10), now, policy), isFalse);
      expect(
          isBookableDay(DateTime(2026, 11, 14), now, policy), isFalse); // Sat
      expect(isBookableDay(DateTime(2026, 12, 14), now, policy), isFalse);
    });

    test('rangeIsFree needs every slot in the range to be free', () {
      final s = slots('chroma', DateTime(2026, 11, 16));
      expect(
        rangeIsFree(s, DateTime(2026, 11, 16, 9), DateTime(2026, 11, 16, 11)),
        isTrue,
      );
      final p = slots('podcast', DateTime(2026, 11, 16));
      expect(
        rangeIsFree(p, DateTime(2026, 11, 16, 9), DateTime(2026, 11, 16, 11)),
        isFalse,
      );
    });
  });

  group('Weekly quota (R-14)', () {
    test('Yasmine has used 1 h of 2 h this week', () {
      final q = quotaFor(
        requesterId: 'yasmine',
        type: RequesterType.student,
        day: now,
        bookings: DemoWorld.bookings,
        policy: policy,
      );
      expect(q.limitMinutes, 120);
      expect(q.usedMinutes, 60);
      expect(q.allows(60), isTrue);
      expect(q.allows(90), isFalse);
    });

    test('next week Yasmine is already at 2 h (pending requests count)', () {
      final q = quotaFor(
        requesterId: 'yasmine',
        type: RequesterType.student,
        day: DateTime(2026, 11, 16),
        bookings: DemoWorld.bookings,
        policy: policy,
      );
      expect(q.usedMinutes, 120);
      expect(q.remainingMinutes, 0);
    });

    test('refused bookings give the time back', () {
      final q = quotaFor(
        requesterId: 'yasmine',
        type: RequesterType.student,
        day: DateTime(2026, 11, 6),
        bookings: DemoWorld.bookings,
        policy: policy,
      );
      expect(q.usedMinutes, 60); // b4 completed; b5 refused not counted
    });

    test('professors have no limit by default', () {
      final q = quotaFor(
        requesterId: 'rami',
        type: RequesterType.professor,
        day: now,
        bookings: DemoWorld.bookings,
        policy: policy,
      );
      expect(q.unlimited, isTrue);
    });

    test('weeks start on Monday', () {
      expect(weekStart(DateTime(2026, 11, 13, 10)), DateTime(2026, 11, 9));
      expect(weekStart(DateTime(2026, 11, 9)), DateTime(2026, 11, 9));
    });

    test('formatMinutes', () {
      expect(formatMinutes(90), '1 h 30');
      expect(formatMinutes(120), '2 h');
      expect(formatMinutes(45), '45 min');
    });
  });

  group('Approval (R-16 to R-19, P-02)', () {
    Booking b(String id) => DemoWorld.bookings.firstWhere((x) => x.id == id);

    test('Level 1 for students goes to Vie Étudiante', () {
      expect(canDecide(personById('amrani'), b('b3')), isTrue);
      expect(canDecide(personById('lahlou'), b('b3')), isFalse);
      expect(canDecide(personById('tazi'), b('b3')), isFalse);
    });

    test('Level 1 for professors goes to their own director only', () {
      expect(canDecide(personById('benjelloun'), b('b10')), isTrue);
      expect(canDecide(personById('amrani'), b('b10')), isFalse);
    });

    test('Level 2 goes to the studio manager, or the admin', () {
      expect(canDecide(personById('tazi'), b('b2')), isTrue);
      expect(canDecide(personById('idrissi'), b('b2')), isTrue);
      expect(canDecide(personById('amrani'), b('b2')), isFalse);
    });

    test('nobody approves their own request', () {
      const self = Person(
        id: 'yasmine',
        firstName: 'Y',
        lastName: 'M',
        roles: {Role.studioManager},
      );
      expect(canDecide(self, b('b2')), isFalse);
    });

    test('approved, refused or finished requests cannot be decided', () {
      expect(canDecide(personById('tazi'), b('b1')), isFalse);
      expect(canDecide(personById('tazi'), b('b5')), isFalse);
    });

    test('inbox lists only what the person can decide, oldest first', () {
      final inbox = inboxFor(personById('tazi'), DemoWorld.bookings);
      expect(inbox.map((x) => x.id), ['b8', 'b2']);
      final amrani = inboxFor(personById('amrani'), DemoWorld.bookings);
      expect(amrani.map((x) => x.id), ['b3', 'b12']);
    });
  });

  group('World actions', () {
    test('submit → approve L1 → approve L2 → validated', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(worldProvider.notifier);
      final booking = n.submit(
        requesterId: 'yasmine',
        requesterType: RequesterType.student,
        establishmentId: 'eidia',
        studioId: 'chroma',
        start: DateTime(2026, 11, 11, 15),
        end: DateTime(2026, 11, 11, 16),
        activity: Activity.filming,
      );
      expect(booking.status, BookingStatus.pendingEntity);

      n.approve(booking.id, by: personById('amrani'));
      Booking get() =>
          c.read(worldProvider).bookings.firstWhere((x) => x.id == booking.id);
      expect(get().status, BookingStatus.pendingStudio);

      n.approve(booking.id, by: personById('tazi'), technicianId: 'haddad');
      expect(get().status, BookingStatus.approved);
      expect(get().history.length, 3);
      expect(get().technicianId, 'haddad');
    });

    test('refusing without a reason is not allowed', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(worldProvider.notifier);
      expect(
        () => n.refuse('b3', by: personById('amrani'), reason: '  '),
        throwsArgumentError,
      );
      n.refuse('b3', by: personById('amrani'), reason: 'Projet hors périmètre');
      final b3 = c.read(worldProvider).bookings.firstWhere((x) => x.id == 'b3');
      expect(b3.status, BookingStatus.refused);
      expect(b3.refusalReason, 'Projet hors périmètre');
    });

    test('a person who cannot decide is rejected', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(worldProvider.notifier);
      expect(
        () => n.approve('b3', by: personById('tazi')),
        throwsStateError,
      );
    });
  });
}
