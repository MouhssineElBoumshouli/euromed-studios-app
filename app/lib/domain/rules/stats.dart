/// I1 · Figures for the "Pilotage" dashboard, computed from the bookings
/// and projects already in memory. Pure functions: easy to test, same
/// result offline and live.
library;

import '../bookings.dart';
import '../people.dart';
import '../policy.dart';
import '../projects.dart';
import '../studios.dart';

/// Monday 00:00 of the week that contains [now].
DateTime weekStart(DateTime now) {
  final d = DateTime(now.year, now.month, now.day);
  return DateTime(d.year, d.month, d.day - (d.weekday - 1));
}

/// The week to report on: this week, or next week once this week has no
/// open day left (e.g. on a Saturday or Sunday).
DateTime reportWeek(DateTime now, Policy policy) {
  final start = weekStart(now);
  final lastOpen = policy.openWeekdays.isEmpty
      ? 7
      : policy.openWeekdays.reduce((a, b) => a > b ? a : b);
  return now.weekday > lastOpen
      ? DateTime(start.year, start.month, start.day + 7)
      : start;
}

/// The opening window of each open day between [from] and [to].
List<({DateTime start, DateTime end})> openWindows(
  Policy policy,
  DateTime from,
  DateTime to,
) =>
    [
      for (var d = DateTime(from.year, from.month, from.day);
          d.isBefore(to);
          d = DateTime(d.year, d.month, d.day + 1))
        if (policy.openWeekdays.contains(d.weekday))
          (
            start: DateTime(d.year, d.month, d.day, policy.openingHour),
            end: DateTime(d.year, d.month, d.day, policy.closingHour),
          ),
    ];

/// Minutes the studios are open between [from] and [to].
int openMinutes(Policy policy, DateTime from, DateTime to) =>
    openWindows(policy, from, to)
        .fold(0, (s, w) => s + w.end.difference(w.start).inMinutes);

/// A booking that holds the room (counts for occupancy).
bool holdsStudio(Booking b) =>
    b.status == BookingStatus.approved ||
    b.status == BookingStatus.completed ||
    b.status == BookingStatus.noShow;

int _overlap(DateTime s1, DateTime e1, DateTime s2, DateTime e2) {
  final s = s1.isAfter(s2) ? s1 : s2;
  final e = e1.isBefore(e2) ? e1 : e2;
  return e.isAfter(s) ? e.difference(s).inMinutes : 0;
}

/// One physical room: studios that share it can't be used at the same
/// time (R-08), so occupancy is measured per room.
class RoomLoad {
  const RoomLoad({
    required this.roomId,
    required this.studios,
    required this.bookedMinutes,
    required this.openMinutes,
  });
  final String roomId;
  final List<Studio> studios;
  final int bookedMinutes;

  /// Opening hours minus planned maintenance.
  final int openMinutes;

  String get name => studios.map((s) => s.name).join(' / ');
  double get rate =>
      openMinutes == 0 ? 0 : (bookedMinutes / openMinutes).clamp(0, 1);
}

/// Booked share of each room between [from] and [to], counted only
/// inside opening hours, with maintenance taken out of the open time.
List<RoomLoad> occupancy(
  List<Studio> studios,
  List<Booking> bookings,
  Policy policy,
  DateTime from,
  DateTime to, {
  List<MaintenanceBlock> maintenance = const [],
}) {
  final windows = openWindows(policy, from, to);
  final byRoom = <String, List<Studio>>{};
  for (final s in studios) {
    if (s.bookable) byRoom.putIfAbsent(s.roomId, () => []).add(s);
  }
  return [
    for (final e in byRoom.entries)
      () {
        final ids = {for (final s in e.value) s.id};
        var open = 0, booked = 0;
        for (final w in windows) {
          final closed = maintenance
              .where((m) => m.roomId == e.key)
              .fold(0, (s, m) => s + _overlap(m.start, m.end, w.start, w.end));
          open += w.end.difference(w.start).inMinutes - closed;
          booked += bookings
              .where((b) => ids.contains(b.studioId) && holdsStudio(b))
              .fold(0, (s, b) => s + _overlap(b.start, b.end, w.start, w.end));
        }
        return RoomLoad(
          roomId: e.key,
          studios: e.value,
          bookedMinutes: booked,
          openMinutes: open < 0 ? 0 : open,
        );
      }(),
  ];
}

/// Overall booked share across all rooms.
double overallRate(List<RoomLoad> loads) {
  final open = loads.fold(0, (s, l) => s + l.openMinutes);
  final booked = loads.fold(0, (s, l) => s + l.bookedMinutes);
  return open == 0 ? 0 : (booked / open).clamp(0, 1).toDouble();
}

class PendingSummary {
  const PendingSummary({
    required this.atEntity,
    required this.atStudio,
    this.oldest,
  });
  final int atEntity;
  final int atStudio;

  /// The request waiting the longest (by its last step).
  final Booking? oldest;
  int get total => atEntity + atStudio;
}

PendingSummary pendingSummary(List<Booking> bookings) {
  final pending = [
    for (final b in bookings)
      if (b.status.isPending && !b.isPrivate && b.history.isNotEmpty) b,
  ]..sort((a, b) => a.history.last.at.compareTo(b.history.last.at));
  return PendingSummary(
    atEntity:
        pending.where((b) => b.status == BookingStatus.pendingEntity).length,
    atStudio:
        pending.where((b) => b.status == BookingStatus.pendingStudio).length,
    oldest: pending.isEmpty ? null : pending.first,
  );
}

/// Time from request to final approval, for approvals in the last
/// [days] days. Null when there are none yet.
({Duration average, Duration median, int count})? approvalTimes(
  List<Booking> bookings,
  DateTime now, {
  int days = 30,
}) {
  final since = now.subtract(Duration(days: days));
  final waits = <Duration>[];
  for (final b in bookings) {
    BookingEvent? sent, done;
    for (final e in b.history) {
      if (e.type == BookingEventType.submitted) sent ??= e;
      if (e.type == BookingEventType.studioApproved) done = e;
    }
    if (sent != null && done != null && done.at.isAfter(since)) {
      waits.add(done.at.difference(sent.at));
    }
  }
  if (waits.isEmpty) return null;
  waits.sort();
  final total = waits.fold(Duration.zero, (s, d) => s + d);
  final mid = waits.length ~/ 2;
  final median =
      waits.length.isOdd ? waits[mid] : (waits[mid - 1] + waits[mid]) ~/ 2;
  return (
    average: total ~/ waits.length,
    median: median,
    count: waits.length,
  );
}

/// Share of held sessions where nobody came, over the last [days] days.
/// Null when no session was held yet.
({double rate, int noShows, int held})? noShowRate(
  List<Booking> bookings,
  DateTime now, {
  int days = 30,
}) {
  final since = now.subtract(Duration(days: days));
  var noShows = 0, held = 0;
  for (final b in bookings) {
    if (b.start.isBefore(since) || b.start.isAfter(now)) continue;
    if (b.status == BookingStatus.noShow) {
      noShows++;
      held++;
    } else if (b.status == BookingStatus.completed) {
      held++;
    }
  }
  if (held == 0) return null;
  return (rate: noShows / held, noShows: noShows, held: held);
}

/// Requests sent in the last [days] days, per requester type.
Map<RequesterType, int> requestsByType(
  List<Booking> bookings,
  DateTime now, {
  int days = 30,
}) {
  final since = now.subtract(Duration(days: days));
  final out = {for (final t in RequesterType.values) t: 0};
  for (final b in bookings) {
    if (b.isPrivate) continue;
    final sent = b.history
        .where((e) => e.type == BookingEventType.submitted)
        .firstOrNull
        ?.at;
    if (sent != null && sent.isAfter(since)) {
      out[b.requesterType] = out[b.requesterType]! + 1;
    }
  }
  return out;
}

/// Sessions (validated or waiting) on each of the next [days] open days.
List<({DateTime day, int validated, int waiting})> dailyLoad(
  List<Booking> bookings,
  DateTime now,
  Policy policy, {
  int days = 5,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final open = <DateTime>[];
  for (var i = 0; open.length < days && i < 21; i++) {
    final d = DateTime(today.year, today.month, today.day + i);
    if (policy.openWeekdays.contains(d.weekday)) open.add(d);
  }
  return [
    for (final d in open)
      () {
        final same = bookings.where(
          (b) =>
              !b.isPrivate &&
              b.start.year == d.year &&
              b.start.month == d.month &&
              b.start.day == d.day,
        );
        return (
          day: d,
          validated: same.where(holdsStudio).length,
          waiting: same.where((b) => b.status.isPending).length,
        );
      }(),
  ];
}

Map<ProjectStage, int> projectsByStage(List<Project> projects) => {
      for (final s in ProjectStage.values)
        s: projects.where((p) => p.stage == s).length,
    };
