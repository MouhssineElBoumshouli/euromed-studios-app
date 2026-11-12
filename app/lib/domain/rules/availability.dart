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
  var start = dateOnly(day).add(Duration(hours: policy.openingHour));
  final close = dateOnly(day).add(Duration(hours: policy.closingHour));
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
      for (final b in roomBookings) {
        if (b.overlaps(start, end)) {
          state = b.status == BookingStatus.approved
              ? SlotState.taken
              : SlotState.pending;
          bookingId = b.id;
          studioId = b.studioId;
          break;
        }
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

/// True when every slot between [start] and [end] is free.
bool rangeIsFree(List<Slot> slots, DateTime start, DateTime end) {
  final inside = slots.where(
    (s) => !s.start.isBefore(start) && !s.end.isAfter(end),
  );
  return inside.isNotEmpty && inside.every((s) => s.state.isSelectable);
}

/// Whether [day] is inside the booking window (Q3).
bool isBookableDay(DateTime day, DateTime now, Policy policy) {
  final d = dateOnly(day);
  final today = dateOnly(now);
  return !d.isBefore(today) &&
      d.difference(today).inDays <= policy.maxAdvanceDays &&
      policy.openWeekdays.contains(d.weekday);
}
