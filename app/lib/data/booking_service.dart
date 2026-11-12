/// The actions the app sends to the server.
///
/// Today they run against the in-memory demo world, with a short delay so
/// screens show real loading states. Tomorrow the same methods call the
/// UEMF server; screens keep calling this service and don't change.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/bookings.dart';
import '../domain/people.dart';
import 'app_state.dart';

class BookingService {
  BookingService(this._ref);
  final Ref _ref;

  static const _latency = Duration(milliseconds: 450);

  WorldNotifier get _world => _ref.read(worldProvider.notifier);

  Future<Booking> submit({
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
  }) async {
    await Future<void>.delayed(_latency);
    return _world.submit(
      requesterId: requesterId,
      requesterType: requesterType,
      studioId: studioId,
      start: start,
      end: end,
      activity: activity,
      establishmentId: establishmentId,
      clubId: clubId,
      projectId: projectId,
      note: note,
      equipment: equipment,
    );
  }

  Future<void> approve(
    String bookingId, {
    required Person by,
    String? comment,
    List<EquipmentRequest>? equipment,
    String? technicianId,
  }) async {
    await Future<void>.delayed(_latency);
    _world.approve(
      bookingId,
      by: by,
      comment: comment,
      equipment: equipment,
      technicianId: technicianId,
    );
  }

  Future<void> refuse(
    String bookingId, {
    required Person by,
    required String reason,
  }) async {
    await Future<void>.delayed(_latency);
    _world.refuse(bookingId, by: by, reason: reason);
  }

  Future<void> cancel(String bookingId, {required Person by, String? reason}) async {
    await Future<void>.delayed(_latency);
    _world.cancel(bookingId, by: by, reason: reason);
  }

  Future<void> signCharter(String personId) async {
    await Future<void>.delayed(_latency);
    _world.signCharter(personId);
  }
}

final bookingServiceProvider = Provider<BookingService>(BookingService.new);
