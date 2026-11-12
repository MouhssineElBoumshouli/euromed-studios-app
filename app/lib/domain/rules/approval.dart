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

/// Can [person] decide on [booking] right now?
///
/// Nobody decides on their own request (P-02). Level 1 needs a matching
/// approver scope. Level 2 is the Studio Manager; the Administrator can
/// also give final slot validation (R-09).
bool canDecide(Person person, Booking booking) {
  if (person.id == booking.requesterId) return false;
  return switch (booking.status) {
    BookingStatus.pendingEntity => person.has(Role.entityApprover) &&
        person.approverScopes.any(
          (s) => s.covers(booking.requesterType, booking.establishmentId),
        ),
    BookingStatus.pendingStudio =>
      person.has(Role.studioManager) || person.has(Role.admin),
    _ => false,
  };
}

/// The bookings waiting for [person]'s decision, oldest request first.
List<Booking> inboxFor(Person person, List<Booking> bookings) {
  final mine = [
    for (final b in bookings)
      if (canDecide(person, b)) b,
  ];
  DateTime sentAt(Booking b) => b.history
      .lastWhere(
        (e) => e.type == BookingEventType.submitted ||
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
