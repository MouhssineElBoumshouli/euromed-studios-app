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
import '../domain/studios.dart';
import 'demo_world.dart';

class WorldState {
  const WorldState({
    required this.now,
    required this.policy,
    required this.bookings,
    required this.maintenance,
    required this.signedCharterVersion,
  });

  final DateTime now;
  final Policy policy;
  final List<Booking> bookings;
  final List<MaintenanceBlock> maintenance;

  /// Charter version signed, per person id (R-13).
  final Map<String, String> signedCharterVersion;

  WorldState copyWith({
    List<Booking>? bookings,
    Map<String, String>? signedCharterVersion,
    Policy? policy,
  }) =>
      WorldState(
        now: now,
        policy: policy ?? this.policy,
        bookings: bookings ?? this.bookings,
        maintenance: maintenance,
        signedCharterVersion: signedCharterVersion ?? this.signedCharterVersion,
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

  /// Sends a new request. It immediately holds the slot (R-15).
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
    final booking = Booking(
      id: 'n$_refCounter',
      reference: 'ES-2026-0${_refCounter++}',
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
    if (!canDecide(by, b)) {
      throw StateError('${by.id} cannot decide on ${b.id}');
    }
    final level1 = b.status == BookingStatus.pendingEntity;
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
    if (!canDecide(by, b)) {
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

  void cancel(String bookingId, {required Person by, String? reason}) {
    final b = _find(bookingId);
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

  void signCharter(String personId) {
    state = state.copyWith(
      signedCharterVersion: {
        ...state.signedCharterVersion,
        personId: state.policy.charterVersion,
      },
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
