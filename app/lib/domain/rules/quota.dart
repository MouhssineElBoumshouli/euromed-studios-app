/// Weekly hour limits (R-14, Q4). Weeks run Monday 00:00 → Monday 00:00.
library;

import '../bookings.dart';
import '../people.dart';
import '../policy.dart';
import 'availability.dart';

DateTime weekStart(DateTime d) =>
    dateOnly(d).subtract(Duration(days: d.weekday - 1));

class QuotaStatus {
  const QuotaStatus({required this.limitMinutes, required this.usedMinutes});

  /// Null means there is no limit for this requester type.
  final int? limitMinutes;
  final int usedMinutes;

  bool get unlimited => limitMinutes == null;
  int get remainingMinutes =>
      unlimited ? 1 << 30 : (limitMinutes! - usedMinutes).clamp(0, 1 << 30);
  bool allows(int extraMinutes) =>
      unlimited || extraMinutes <= remainingMinutes;
  double get ratio => unlimited || limitMinutes == 0
      ? 0
      : (usedMinutes / limitMinutes!).clamp(0.0, 1.0);
}

/// What [requesterId], booking as [type], has used in the week of [day].
///
/// Pending and approved bookings count, as do sessions already done.
/// Refused and cancelled ones give the time back. Club bookings count
/// against the club, not the person.
QuotaStatus quotaFor({
  required String requesterId,
  required RequesterType type,
  required DateTime day,
  required List<Booking> bookings,
  required Policy policy,
  String? clubId,
}) {
  final from = weekStart(day);
  final to = from.add(const Duration(days: 7));
  var used = 0;
  for (final b in bookings) {
    final counts = b.status.holdsSlot || b.status == BookingStatus.completed;
    final sameOwner = type == RequesterType.club
        ? clubId != null &&
            b.clubId == clubId &&
            b.requesterType == RequesterType.club
        : b.requesterId == requesterId && b.requesterType == type;
    if (counts &&
        sameOwner &&
        !b.start.isBefore(from) &&
        b.start.isBefore(to)) {
      used += b.duration.inMinutes;
    }
  }
  return QuotaStatus(limitMinutes: policy.quotaFor(type), usedMinutes: used);
}

/// "1 h 30", "2 h", "45 min".
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h ${m.toString().padLeft(2, '0')}';
}
