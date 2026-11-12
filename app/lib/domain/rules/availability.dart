/// Which time slots can be booked (R-10, R-15, Q1, Q3).
///
/// A slot is blocked when any booking in the same *room* holds it, not
/// only bookings of the same studio: Plateau TV and Euromed Radio share
/// Area 2, so booking one blocks the other.
library;

import '../bookings.dart';
import '../policy.dart';
import '../studios.dart';

enum SlotState {
  free('Libre'),
  pending('En attente'),
  taken('Pris'),
  maintenance('Maintenance'),
  past('Passé');

  const SlotState(this.label);
  final String label;

  bool get isSelectable => this == SlotState.free;
}

class Slot {
  const Slot({
    required this.start,
    required this.end,
    required this.state,
    this.blockingBookingId,
    this.blockingStudioId,
  });
  final DateTime start;
  final DateTime end;
  final SlotState state;

  /// The booking that blocks this slot, if any.
  final String? blockingBookingId;

  /// The studio of that booking (may differ from the one asked about).
  final String? blockingStudioId;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// All the slots of [day] for [studio], with their state.
List<Slot> slotsFor({
  required Studio studio,
  required DateTime day,
  required Policy policy,
  required List<Studio> allStudios,
  required List<Booking> bookings,
  required List<MaintenanceBlock> maintenance,
  required DateTime now,
}) {
  if (!policy.openWeekdays.contains(day.weekday) || !studio.bookable) {
    return const [];
  }
  final roomStudioIds = {
    for (final s in allStudios)
      if (s.roomId == studio.roomId) s.id,
  };
  final roomBookings = [
    for (final b in bookings)
      if (b.status.holdsSlot && roomStudioIds.contains(b.studioId)) b,
  ];
  final roomMaintenance = [
    for (final m in maintenance)
      if (m.roomId == studio.roomId) m,
  ];

  final slots = <Slot>[];
  // Built from calendar fields, not by adding hours to midnight, so a
  // clock change never shifts the opening hours.
  var start = DateTime(day.year, day.month, day.day, policy.openingHour);
  final close = DateTime(day.year, day.month, day.day, policy.closingHour);
  final step = Duration(minutes: policy.slotMinutes);
  while (!start.add(step).isAfter(close)) {
    final end = start.add(step);
    SlotState state = SlotState.free;
    String? bookingId;
    String? studioId;

    if (start.isBefore(now)) {
      state = SlotState.past;
    } else if (roomMaintenance.any(
      (m) => m.start.isBefore(end) && start.isBefore(m.end),
    )) {
      state = SlotState.maintenance;
    } else {
      // An approved booking wins over a pending one on the same slot.
      for (final b in roomBookings) {
        if (!b.overlaps(start, end)) continue;
        final approved = b.status == BookingStatus.approved;
        if (state == SlotState.free || approved) {
          state = approved ? SlotState.taken : SlotState.pending;
          bookingId = b.id;
          studioId = b.studioId;
        }
        if (approved) break;
      }
    }
    slots.add(
      Slot(
        start: start,
        end: end,
        state: state,
        blockingBookingId: bookingId,
        blockingStudioId: studioId,
      ),
    );
    start = end;
  }
  return slots;
}

/// True when [start]–[end] is covered exactly, with no gap, by slots that
/// are all free. A range that starts before opening, ends after closing
/// or falls between slot boundaries is not free.
bool rangeIsFree(List<Slot> slots, DateTime start, DateTime end) {
  if (!start.isBefore(end)) return false;
  final inside = [
    for (final s in slots)
      if (!s.start.isBefore(start) && !s.end.isAfter(end)) s,
  ];
  if (inside.isEmpty) return false;
  if (inside.first.start != start || inside.last.end != end) return false;
  for (var i = 1; i < inside.length; i++) {
    if (inside[i].start != inside[i - 1].end) return false;
  }
  return inside.every((s) => s.state.isSelectable);
}

/// Days between two calendar dates, immune to clock changes.
int _calendarDays(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

/// Whether [day] is inside the booking window (Q3).
bool isBookableDay(DateTime day, DateTime now, Policy policy) {
  final diff = _calendarDays(now, day);
  return diff >= 0 &&
      diff <= policy.maxAdvanceDays &&
      policy.openWeekdays.contains(day.weekday);
}
