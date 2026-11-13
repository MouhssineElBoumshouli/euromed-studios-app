/// Who approves what (R-16 to R-19, P-02).
library;

import '../bookings.dart';
import '../people.dart';

/// Where a Level 1 request goes, in words, for the requester (R-17).
String level1Label(RequesterType t) => switch (t) {
      RequesterType.student => 'Vie Étudiante de l’établissement',
      RequesterType.club => 'Vie Étudiante (Affaires Estudiantines)',
      RequesterType.professor => 'Doyen ou Directeur de l’établissement',
      RequesterType.communication => 'Direction de la Communication',
      RequesterType.external => 'Vice-Présidence Exécutive',
    };

const level2Label = 'Direction des Studios';

bool _coversLevel1(Person p, Booking b) =>
    p.has(Role.entityApprover) &&
    p.approverScopes.any((s) => s.covers(b.requesterType, b.establishmentId));

/// Whether [person] already decided an earlier level of [booking].
bool _decidedEarlier(Person person, Booking booking) => booking.history.any(
      (e) =>
          e.actorId == person.id &&
          (e.type == BookingEventType.entityApproved ||
              e.type == BookingEventType.studioApproved),
    );

/// True when the requester is themselves the Level 1 approver for this kind
/// of request (e.g. a director booking for their own school). P-02 forbids
/// self-approval, so the request goes to the Administrator instead (Q18).
bool needsLevel1Fallback(Booking b, List<Person> people) {
  final eligible = people.where(
    (p) => p.id != b.requesterId && _coversLevel1(p, b),
  );
  return eligible.isEmpty;
}

/// Can [person] decide on [booking] right now?
///
/// - Nobody decides on their own request (P-02).
/// - The two levels are separate: whoever approved Level 1 cannot also
///   give Level 2 (R-16, "séquentiel strict").
/// - Level 1 needs a matching approver scope; if nobody else covers it,
///   the Administrator decides (Q18 fallback).
/// - Level 2 is the Studio Manager; the Administrator can also give final
///   slot validation (R-09).
bool canDecide(Person person, Booking booking, {List<Person> people = const []}) {
  if (booking.isPrivate) return false;
  if (person.id == booking.requesterId) return false;
  if (_decidedEarlier(person, booking)) return false;
  return switch (booking.status) {
    BookingStatus.pendingEntity => _coversLevel1(person, booking) ||
        (person.has(Role.admin) &&
            people.isNotEmpty &&
            needsLevel1Fallback(booking, people)),
    BookingStatus.pendingStudio =>
      person.has(Role.studioManager) || person.has(Role.admin),
    _ => false,
  };
}

/// The bookings waiting for [person]'s decision, oldest request first.
List<Booking> inboxFor(
  Person person,
  List<Booking> bookings, {
  List<Person> people = const [],
}) {
  final mine = [
    for (final b in bookings)
      if (canDecide(person, b, people: people)) b,
  ];
  DateTime sentAt(Booking b) => b.history
      .lastWhere(
        (e) =>
            e.type == BookingEventType.submitted ||
            e.type == BookingEventType.entityApproved,
        orElse: () => b.history.first,
      )
      .at;
  mine.sort((a, b) => sentAt(a).compareTo(sentAt(b)));
  return mine;
}

/// The next status after an approval at the current level.
BookingStatus nextAfterApproval(BookingStatus s) => switch (s) {
      BookingStatus.pendingEntity => BookingStatus.pendingStudio,
      BookingStatus.pendingStudio => BookingStatus.approved,
      _ => throw StateError('Nothing to approve in status $s'),
    };

/// Can [person] cancel [booking]? The requester (or an admin) may, while it
/// is pending or approved and has not started yet.
bool canCancel(Person person, Booking booking, DateTime now) =>
    (person.id == booking.requesterId || person.has(Role.admin)) &&
    (booking.status.isPending || booking.status == BookingStatus.approved) &&
    booking.start.isAfter(now);
