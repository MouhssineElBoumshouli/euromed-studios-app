import '../bookings.dart';
import '../people.dart';

/// Who runs sessions at the door: régisseurs, the Studio Manager, admins.
bool canOperate(Person p) =>
    p.has(Role.regisseur) || p.has(Role.studioManager) || p.has(Role.admin);

/// People may arrive this early and still be checked in.
const checkInEarly = Duration(minutes: 15);

bool isCheckedIn(Booking b) =>
    b.history.any((e) => e.type == BookingEventType.checkedIn);

/// Why a session can't be checked in now, or null if it can.
String? checkInProblem(Booking b, DateTime now) {
  if (b.status != BookingStatus.approved) {
    return 'La séance n’est pas validée (${b.status.label.toLowerCase()}).';
  }
  if (isCheckedIn(b)) return 'Arrivée déjà enregistrée.';
  if (now.isBefore(b.start.subtract(checkInEarly))) {
    return 'Trop tôt : l’accès ouvre 15 minutes avant le début.';
  }
  if (!now.isBefore(b.end)) return 'Le créneau est terminé.';
  return null;
}

/// A session can be closed once the person came in, or once it is over.
bool canComplete(Booking b, DateTime now) =>
    b.status == BookingStatus.approved &&
    (isCheckedIn(b) || !now.isBefore(b.end));

enum SessionPhase { upcoming, ready, inProgress, late, done, missed }

/// Where a validated session stands today, for the régie board.
SessionPhase phaseOf(Booking b, DateTime now) {
  if (b.status == BookingStatus.completed) return SessionPhase.done;
  final inside = isCheckedIn(b);
  if (inside) return SessionPhase.inProgress;
  if (!now.isBefore(b.end)) return SessionPhase.missed;
  if (now.isAfter(b.start.add(const Duration(minutes: 10)))) {
    return SessionPhase.late;
  }
  if (!now.isBefore(b.start.subtract(checkInEarly))) return SessionPhase.ready;
  return SessionPhase.upcoming;
}
