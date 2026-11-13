/// The actions the app sends to the server.
///
/// Live (the default build): each action calls a server function that
/// checks every rule again (supabase/migrations), then the app reloads.
/// Offline (tests, `LIVE=false`): the same actions run on the in-memory
/// demo world, with a short delay so screens show real loading states.
/// Screens only ever call this service, so they don't care which.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/bookings.dart';
import '../domain/people.dart';
import 'app_state.dart';
import 'backend.dart';
import 'live_sync.dart';

class BookingService {
  BookingService(this._ref);
  final Ref _ref;

  static const _latency = Duration(milliseconds: 450);

  WorldNotifier get _world => _ref.read(worldProvider.notifier);
  SupabaseClient get _db => Supabase.instance.client;

  /// Runs a server function and turns its refusals into the app's errors.
  Future<T> _call<T>(Future<T> Function() run) async {
    try {
      final result = await run();
      await liveSync?.refresh();
      return result;
    } on PostgrestException catch (e) {
      throw _translate(e.message);
    }
  }

  Object _translate(String m) {
    if (m.startsWith('slot_taken')) {
      return const SubmitRejected(SubmitProblem.slotUnavailable);
    }
    if (m.startsWith('quota_exceeded')) {
      return const SubmitRejected(SubmitProblem.overQuota);
    }
    if (m.startsWith('charter_missing')) {
      return const SubmitRejected(SubmitProblem.charterMissing);
    }
    if (m.startsWith('outside_opening_hours') ||
        m.startsWith('in_the_past') ||
        m.startsWith('too_far_ahead')) {
      return const SubmitRejected(SubmitProblem.dayClosed);
    }
    if (m.startsWith('conflict: ')) {
      return BookingConflict(m.substring('conflict: '.length));
    }
    if (m.startsWith('not_a_requester') ||
        m.startsWith('not_club_representative') ||
        m.startsWith('studio_not_bookable')) {
      return const SubmitRejected(SubmitProblem.notAllowed);
    }
    return StateError(m);
  }

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
    if (isLive) {
      return _call(() async {
        final row = await _db.rpc(
          'submit_booking',
          params: {
            'p_studio': studioId,
            'p_start': start.toUtc().toIso8601String(),
            'p_end': end.toUtc().toIso8601String(),
            'p_activity': activity.name,
            'p_club': clubId,
            'p_project': projectId,
            'p_note': note,
            'p_equipment': equipmentToJson(equipment),
          },
        );
        return bookingFromRow(row as Map<String, dynamic>);
      });
    }
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
    if (isLive) {
      await _call(
        () => _db.rpc(
          'approve_booking',
          params: {
            'p_id': bookingId,
            'p_comment': comment,
            'p_equipment': equipment == null ? null : equipmentToJson(equipment),
            'p_technician': technicianId,
          },
        ),
      );
      return;
    }
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
    if (isLive) {
      await _call(
        () => _db.rpc(
          'refuse_booking',
          params: {'p_id': bookingId, 'p_reason': reason},
        ),
      );
      return;
    }
    await Future<void>.delayed(_latency);
    _world.refuse(bookingId, by: by, reason: reason);
  }

  Future<void> cancel(String bookingId, {required Person by, String? reason}) async {
    if (isLive) {
      await _call(
        () => _db.rpc(
          'cancel_booking',
          params: {'p_id': bookingId, 'p_reason': reason},
        ),
      );
      return;
    }
    await Future<void>.delayed(_latency);
    _world.cancel(bookingId, by: by, reason: reason);
  }

  Future<void> checkIn(String bookingId, {required Person by}) async {
    if (isLive) {
      await _call(() => _db.rpc('check_in_booking', params: {'p_id': bookingId}));
      return;
    }
    await Future<void>.delayed(_latency);
    _world.checkIn(bookingId, by: by);
  }

  Future<void> complete(
    String bookingId, {
    required Person by,
    String? report,
  }) async {
    if (isLive) {
      await _call(
        () => _db.rpc(
          'complete_booking',
          params: {'p_id': bookingId, 'p_report': report},
        ),
      );
      return;
    }
    await Future<void>.delayed(_latency);
    _world.complete(bookingId, by: by, report: report);
  }

  Future<void> markNoShow(String bookingId, {required Person by}) async {
    if (isLive) {
      await _call(() => _db.rpc('mark_no_show', params: {'p_id': bookingId}));
      return;
    }
    await Future<void>.delayed(_latency);
    _world.markNoShow(bookingId, by: by);
  }

  /// Marks every notification so far as read.
  Future<void> markNoticesSeen(String personId) async {
    if (isLive) {
      await _call(() => _db.rpc('mark_notifications_seen'));
      _world.markNoticesSeen(personId);
      return;
    }
    _world.markNoticesSeen(personId);
  }

  Future<void> signCharter(String personId) async {
    if (isLive) {
      await _call(() => _db.rpc('sign_charter'));
      return;
    }
    await Future<void>.delayed(_latency);
    _world.signCharter(personId);
  }
}

final bookingServiceProvider = Provider<BookingService>(BookingService.new);
