import '../../core/l10n/tr.dart';
import '../bookings.dart';
import '../people.dart';

/// Who runs sessions at the door: régisseurs, the Studio Manager, admins.
bool canOperate(Person p) =>
    p.has(Role.regisseur) || p.has(Role.studioManager) || p.has(Role.admin);

/// After this long without arriving, the person counts as late, and the
/// régie may record an absence (Q20).
const lateAfter = Duration(minutes: 15);

bool isCheckedIn(Booking b) =>
    b.history.any((e) => e.type == BookingEventType.checkedIn);

/// Why a session can't be checked in now, or null if it can.
///
/// [earlyMinutes] is the admin setting that also opens the QR pass early
/// (Policy.qrGraceMinutes, Q19), so the pass and the door always agree.
String? checkInProblem(Booking b, DateTime now, {required int earlyMinutes}) {
  if (b.status != BookingStatus.approved) {
    return 'La séance n’est pas validée (${tr(b.status.label).toLowerCase()}).';
  }
  if (isCheckedIn(b)) return 'Arrivée déjà enregistrée.';
  if (now.isBefore(b.start.subtract(Duration(minutes: earlyMinutes)))) {
    return earlyMinutes == 0
        ? 'Trop tôt : l’accès ouvre à ${_hm(b.start)}.'
        : 'Trop tôt : l’accès ouvre $earlyMinutes minutes avant le début.';
  }
  if (!now.isBefore(b.end)) return 'Le créneau est terminé.';
  return null;
}

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// A session is closed only after the person came in. Otherwise it is an
/// absence, recorded separately so statistics stay honest.
bool canComplete(Booking b, DateTime now) =>
    b.status == BookingStatus.approved && isCheckedIn(b);

/// Nobody came: once [lateAfter] has passed without a check-in.
bool canMarkNoShow(Booking b, DateTime now) =>
    b.status == BookingStatus.approved &&
    !isCheckedIn(b) &&
    !now.isBefore(b.start.add(lateAfter));

enum SessionPhase { upcoming, ready, inProgress, late, done, missed }

/// Where a validated session stands today, for the régie board.
SessionPhase phaseOf(Booking b, DateTime now, {int earlyMinutes = 15}) {
  if (b.status == BookingStatus.completed) return SessionPhase.done;
  if (b.status == BookingStatus.noShow) return SessionPhase.missed;
  final inside = isCheckedIn(b);
  if (inside) return SessionPhase.inProgress;
  if (!now.isBefore(b.end)) return SessionPhase.missed;
  if (!now.isBefore(b.start.add(lateAfter))) return SessionPhase.late;
  if (!now.isBefore(b.start.subtract(Duration(minutes: earlyMinutes)))) {
    return SessionPhase.ready;
  }
  return SessionPhase.upcoming;
}
