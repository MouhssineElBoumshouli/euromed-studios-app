/// Read-only views of the state that several screens share.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../domain/bookings.dart';
import '../domain/people.dart';
import '../domain/rules/notifications.dart';
import '../domain/rules/quota.dart';
import '../domain/studios.dart';
import 'app_state.dart';
import 'projects_state.dart';
import 'directory.dart';
import 'catalog.dart';

/// The requester type a person books as by default.
RequesterType defaultRequesterType(Person p) {
  if (p.has(Role.professor)) return RequesterType.professor;
  if (p.has(Role.communication)) return RequesterType.communication;
  if (p.has(Role.externalClient)) return RequesterType.external;
  return RequesterType.student;
}

List<Booking> bookingsOf(WorldState w, String personId) => [
      for (final b in w.bookings)
        if (b.requesterId == personId) b,
    ]..sort((a, b) => a.start.compareTo(b.start));

/// The next approved session that hasn't ended yet.
Booking? nextSession(WorldState w, String personId) {
  final list = [
    for (final b in bookingsOf(w, personId))
      if (b.status == BookingStatus.approved && b.end.isAfter(w.now)) b,
  ];
  return list.isEmpty ? null : list.first;
}

QuotaStatus weeklyQuota(WorldState w, Person p, {DateTime? day}) => quotaFor(
      requesterId: p.id,
      type: defaultRequesterType(p),
      day: day ?? w.now,
      bookings: w.bookings,
      policy: w.policy,
    );

enum LiveState { free, occupied, maintenance }

class LiveRoom {
  const LiveRoom(this.studio, this.state, {this.until});
  final Studio studio;
  final LiveState state;
  final DateTime? until;
}

/// What is happening right now, one line per bookable studio (R-30).
List<LiveRoom> liveStatus(WorldState w) {
  final now = w.now;
  final result = <LiveRoom>[];
  for (final s in Catalog.studios.where((s) => s.bookable)) {
    final m = w.maintenance.where(
      (m) =>
          m.roomId == s.roomId && !m.start.isAfter(now) && m.end.isAfter(now),
    );
    if (m.isNotEmpty) {
      result.add(LiveRoom(s, LiveState.maintenance, until: m.first.end));
      continue;
    }
    final roomIds = {
      for (final x in Catalog.studios)
        if (x.roomId == s.roomId) x.id,
    };
    final busy = w.bookings.where(
      (b) =>
          b.status == BookingStatus.approved &&
          roomIds.contains(b.studioId) &&
          !b.start.isAfter(now) &&
          b.end.isAfter(now),
    );
    result.add(
      busy.isEmpty
          ? LiveRoom(s, LiveState.free)
          : LiveRoom(s, LiveState.occupied, until: busy.first.end),
    );
  }
  return result;
}

/// The signed-in person's notifications, newest first.
final noticesProvider = Provider<List<Notice>>((ref) {
  final w = ref.watch(worldProvider);
  final me = ref.watch(currentPersonProvider);
  final pr = ref.watch(projectsProvider);
  String nameOf(String id) => personById(id).displayName;
  return [
    ...noticesFor(
      me,
      w.bookings,
      w.now,
      people: Directory.people,
      describe: (b) =>
          '${studioById(b.studioId).name} · ${Fmt.shortDay(b.start)} '
          '${Fmt.time(b.start)}',
      nameOf: nameOf,
    ),
    ...projectNoticesFor(
      me,
      pr.projects,
      pr.invites,
      w.now,
      messages: pr.messages,
      nameOf: nameOf,
    ),
  ]..sort((a, b) => b.at.compareTo(a.at));
});

final unreadNoticesProvider = Provider<int>((ref) {
  final w = ref.watch(worldProvider);
  final me = ref.watch(currentPersonProvider);
  return unreadCount(
    ref.watch(noticesProvider),
    w.noticesSeenAt[me.id],
    w.now,
  );
});
