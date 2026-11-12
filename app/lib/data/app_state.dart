/// App state for the demo, held in memory.
///
/// Screens only talk to these providers. When the real server arrives,
/// [WorldNotifier] is swapped for one that calls the server; the screens
/// do not change.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/bookings.dart';
import '../domain/people.dart';
import '../domain/policy.dart';
import '../domain/rules/approval.dart';
import '../domain/rules/availability.dart';
import '../domain/rules/quota.dart';
import '../domain/studios.dart';
import 'demo_world.dart';

/// Why a request cannot be sent. Each one has its own screen or message.
enum SubmitProblem {
  notAllowed('Vous ne pouvez pas réserver à ce titre.'),
  charterMissing('Signez d’abord le règlement intérieur.'),
  dayClosed('Ce jour ou cet horaire n’est pas réservable.'),
  slotUnavailable('Ce créneau n’est plus libre.'),
  overQuota('Votre quota de la semaine ne suffit pas pour cette durée.');

  const SubmitProblem(this.message);
  final String message;
}

class SubmitRejected implements Exception {
  const SubmitRejected(this.problem);
  final SubmitProblem problem;
  @override
  String toString() => 'SubmitRejected(${problem.name})';
}

class BookingConflict implements Exception {
  const BookingConflict(this.message);
  final String message;
  @override
  String toString() => 'BookingConflict($message)';
}

class WorldState {
  const WorldState({
    required this.now,
    required this.policy,
    required this.bookings,
    required this.maintenance,
    required this.signedCharterVersion,
    this.charterSignedAt = const {},
  });

  final DateTime now;
  final Policy policy;
  final List<Booking> bookings;
  final List<MaintenanceBlock> maintenance;

  /// Charter version signed, per person id (R-13).
  final Map<String, String> signedCharterVersion;

  /// When each person signed, for the record (Q11).
  final Map<String, DateTime> charterSignedAt;

  WorldState copyWith({
    List<Booking>? bookings,
    Map<String, String>? signedCharterVersion,
    Map<String, DateTime>? charterSignedAt,
    Policy? policy,
  }) =>
      WorldState(
        now: now,
        policy: policy ?? this.policy,
        bookings: bookings ?? this.bookings,
        maintenance: maintenance,
        signedCharterVersion: signedCharterVersion ?? this.signedCharterVersion,
        charterSignedAt: charterSignedAt ?? this.charterSignedAt,
      );
}

class WorldNotifier extends Notifier<WorldState> {
  @override
  WorldState build() => WorldState(
        now: DemoWorld.now,
        policy: DemoWorld.policy,
        bookings: List.of(DemoWorld.bookings),
        maintenance: List.of(DemoWorld.maintenance),
        signedCharterVersion: {
          for (final p in DemoWorld.people)
            p.id: DemoWorld.policy.charterVersion,
        },
      );

  int _refCounter = 147;

  Booking _find(String id) => state.bookings.firstWhere((b) => b.id == id);

  void _replace(Booking updated) {
    state = state.copyWith(
      bookings: [
        for (final b in state.bookings) b.id == updated.id ? updated : b,
      ],
    );
  }

  /// Checks a request against every rule before it is sent.
  /// Returns null when it may be sent.
  SubmitProblem? check({
    required String requesterId,
    required RequesterType requesterType,
    required String studioId,
    required DateTime start,
    required DateTime end,
    String? clubId,
  }) {
    final p = personById(requesterId);
    final allowedType = switch (requesterType) {
      RequesterType.student => p.has(Role.student),
      RequesterType.club =>
        p.has(Role.clubRepresentative) && clubId != null && p.clubIds.contains(clubId),
      RequesterType.professor => p.has(Role.professor),
      RequesterType.communication => p.has(Role.communication),
      RequesterType.external => p.has(Role.externalClient),
    };
    if (!allowedType) return SubmitProblem.notAllowed;
    if (state.signedCharterVersion[requesterId] != state.policy.charterVersion) {
      return SubmitProblem.charterMissing;
    }
    final studio = studioById(studioId);
    if (!studio.bookable ||
        !start.isAfter(state.now) ||
        !isBookableDay(start, state.now, state.policy)) {
      return SubmitProblem.dayClosed;
    }
    final slots = slotsFor(
      studio: studio,
      day: start,
      policy: state.policy,
      allStudios: DemoWorld.studios,
      bookings: state.bookings,
      maintenance: state.maintenance,
      now: state.now,
    );
    if (!rangeIsFree(slots, start, end)) return SubmitProblem.slotUnavailable;
    final quota = quotaFor(
      requesterId: requesterId,
      type: requesterType,
      day: start,
      bookings: state.bookings,
      policy: state.policy,
      clubId: clubId,
    );
    if (!quota.allows(end.difference(start).inMinutes)) {
      return SubmitProblem.overQuota;
    }
    return null;
  }

  /// Sends a new request after checking every rule. It immediately holds
  /// the slot for everyone (R-15). Throws [SubmitRejected] if a rule fails.
  Booking submit({
    required String requesterId,
    required RequesterType requesterType,
    required String studioId,
    required DateTime start,
    required DateTime end,
    required Activity activity,
    String? establishmentId,
    String? clubId,
    String? projectId,
    String? note,
    List<EquipmentRequest> equipment = const [],
  }) {
    final problem = check(
      requesterId: requesterId,
      requesterType: requesterType,
      studioId: studioId,
      start: start,
      end: end,
      clubId: clubId,
    );
    if (problem != null) throw SubmitRejected(problem);
    final n = _refCounter++;
    final booking = Booking(
      id: 'n$n',
      reference: 'ES-${state.now.year}-${n.toString().padLeft(4, '0')}',
      requesterId: requesterId,
      requesterType: requesterType,
      establishmentId: establishmentId,
      clubId: clubId,
      studioId: studioId,
      start: start,
      end: end,
      activity: activity,
      status: BookingStatus.pendingEntity,
      projectId: projectId,
      note: note,
      equipment: equipment,
      history: [
        BookingEvent(
          type: BookingEventType.submitted,
          at: state.now,
          actorId: requesterId,
        ),
      ],
    );
    state = state.copyWith(bookings: [...state.bookings, booking]);
    return booking;
  }

  void approve(
    String bookingId, {
    required Person by,
    String? comment,
    List<EquipmentRequest>? equipment,
    String? technicianId,
  }) {
    final b = _find(bookingId);
    if (!canDecide(by, b, people: DemoWorld.people)) {
      throw StateError('${by.id} cannot decide on ${b.id}');
    }
    final level1 = b.status == BookingStatus.pendingEntity;
    if (!level1) {
      final conflict = level2Conflict(b);
      if (conflict != null) throw BookingConflict(conflict);
    }
    _replace(
      b.copyWith(
        status: nextAfterApproval(b.status),
        equipment: equipment,
        technicianId: technicianId,
        history: [
          ...b.history,
          BookingEvent(
            type: level1
                ? BookingEventType.entityApproved
                : BookingEventType.studioApproved,
            at: state.now,
            actorId: by.id,
            comment: comment,
          ),
        ],
      ),
    );
  }

  /// A refusal always needs a reason (R-19).
  void refuse(String bookingId, {required Person by, required String reason}) {
    final b = _find(bookingId);
    if (!canDecide(by, b, people: DemoWorld.people)) {
      throw StateError('${by.id} cannot decide on ${b.id}');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError('A refusal needs a reason');
    }
    _replace(
      b.copyWith(
        status: BookingStatus.refused,
        refusalReason: reason,
        history: [
          ...b.history,
          BookingEvent(
            type: BookingEventType.refused,
            at: state.now,
            actorId: by.id,
            comment: reason,
          ),
        ],
      ),
    );
  }

  /// What blocks final (Level 2) approval, in words, or null (R-18):
  /// another approved booking in the same room, or maintenance.
  String? level2Conflict(Booking b) {
    final roomId = studioById(b.studioId).roomId;
    final roomStudios = {
      for (final s in DemoWorld.studios)
        if (s.roomId == roomId) s.id,
    };
    for (final o in state.bookings) {
      if (o.id != b.id &&
          o.status == BookingStatus.approved &&
          roomStudios.contains(o.studioId) &&
          o.overlaps(b.start, b.end)) {
        return 'Déjà validé pour ${studioById(o.studioId).name} '
            '(${o.reference}) sur ce créneau.';
      }
    }
    for (final m in state.maintenance) {
      if (m.roomId == roomId && m.start.isBefore(b.end) && b.start.isBefore(m.end)) {
        return 'Maintenance prévue : ${m.reason}.';
      }
    }
    return null;
  }

  /// Only the requester (or an admin), only before the session starts.
  void cancel(String bookingId, {required Person by, String? reason}) {
    final b = _find(bookingId);
    if (!canCancel(by, b, state.now)) {
      throw StateError('${by.id} cannot cancel ${b.id}');
    }
    _replace(
      b.copyWith(
        status: BookingStatus.cancelled,
        history: [
          ...b.history,
          BookingEvent(
            type: BookingEventType.cancelled,
            at: state.now,
            actorId: by.id,
            comment: reason,
          ),
        ],
      ),
    );
  }

  /// Records the signature with the person and the time (R-13, Q11).
  void signCharter(String personId) {
    state = state.copyWith(
      signedCharterVersion: {
        ...state.signedCharterVersion,
        personId: state.policy.charterVersion,
      },
      charterSignedAt: {...state.charterSignedAt, personId: state.now},
    );
  }

  void updatePolicy(Policy policy) => state = state.copyWith(policy: policy);

  /// Puts the demo back to its starting story.
  void reset() => state = build();
}

final worldProvider =
    NotifierProvider<WorldNotifier, WorldState>(WorldNotifier.new);

/// Who is using the app. In the demo, the role switcher changes it.
final currentPersonIdProvider = StateProvider<String>((ref) => 'yasmine');

final currentPersonProvider = Provider<Person>((ref) {
  final id = ref.watch(currentPersonIdProvider);
  return DemoWorld.people.firstWhere((p) => p.id == id);
});

Person personById(String id) => DemoWorld.people.firstWhere((p) => p.id == id);

Studio studioById(String id) => DemoWorld.studios.firstWhere((s) => s.id == id);

EquipmentItem equipmentById(String id) =>
    DemoWorld.equipment.firstWhere((e) => e.id == id);

Establishment? establishmentById(String? id) =>
    id == null ? null : DemoWorld.establishments.firstWhere((e) => e.id == id);
