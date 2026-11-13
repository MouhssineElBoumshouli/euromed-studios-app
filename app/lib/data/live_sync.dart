/// Keeps the app's world in step with the shared database.
///
/// After sign-in it loads everything this person may see, then listens to
/// one tiny "something changed" row. When any booking changes anywhere,
/// every open app reloads within a second, so a student's phone and the
/// studio manager's laptop always show the same thing.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/bookings.dart';
import '../domain/people.dart';
import '../domain/policy.dart';
import 'app_state.dart';
import 'backend.dart';
import 'demo_world.dart';

/// Set by main() when the app runs against the server.
LiveSync? liveSync;

class LiveSync {
  LiveSync(this.container);
  final ProviderContainer container;

  SupabaseClient get db => Supabase.instance.client;
  RealtimeChannel? _channel;
  Timer? _clock;
  Timer? _debounce;
  bool _entering = false;

  Future<void> start() async {
    liveStatus.value = db.auth.currentSession == null
        ? LiveStatus.signedOut
        : LiveStatus.loading;
    db.auth.onAuthStateChange.listen((e) {
      if (e.session == null) {
        _stop();
        liveStatus.value = LiveStatus.signedOut;
      } else if (e.event == AuthChangeEvent.signedIn ||
          e.event == AuthChangeEvent.initialSession) {
        _enter();
      }
    });
  }

  Future<void> signIn(String slug) => db.auth.signInWithPassword(
        email: demoEmail(slug),
        password: kDemoPassword,
      );

  Future<void> signOut() => db.auth.signOut();

  Future<void> _enter() async {
    if (_entering || liveStatus.value == LiveStatus.ready) return;
    _entering = true;
    liveStatus.value = LiveStatus.loading;
    try {
      final me = await db
          .from('profiles')
          .select('slug')
          .eq('id', db.auth.currentUser!.id)
          .single();
      container.read(currentPersonIdProvider.notifier).state =
          me['slug'] as String;
      await refresh();
      _channel = db
          .channel('world')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'world_version',
            callback: (_) => _scheduleRefresh(),
          )
          .subscribe();
      // Keeps "now" moving (QR windows, live status) and catches up if a
      // realtime message was missed.
      _clock = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
      liveStatus.value = LiveStatus.ready;
    } catch (_) {
      await db.auth.signOut();
    } finally {
      _entering = false;
    }
  }

  void _stop() {
    _clock?.cancel();
    _debounce?.cancel();
    if (_channel != null) db.removeChannel(_channel!);
    _channel = null;
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), refresh);
  }

  Map<String, String> _slugById = {};

  /// Reloads everything this person may see.
  Future<void> refresh() async {
    final now = DateTime.now();
    if (_slugById.isEmpty) {
      final people = await db.from('profiles').select('id, slug');
      _slugById = {
        for (final p in people) p['id'] as String: p['slug'] as String,
      };
    }
    final results = await Future.wait<dynamic>([
      Future<dynamic>.value(db.from('settings').select().single()),
      Future<dynamic>.value(db.from('bookings').select()),
      Future<dynamic>.value(db.rpc(
        'busy_slots',
        params: {
          'p_from': now.subtract(const Duration(days: 45)).toUtc().toIso8601String(),
          'p_to': now.add(const Duration(days: 60)).toUtc().toIso8601String(),
        },
      )),
      Future<dynamic>.value(db.from('maintenance').select()),
      Future<dynamic>.value(db.from('charter_signatures').select()),
    ]);
    final settings = results[0] as Map<String, dynamic>;
    final known = {for (final s in DemoWorld.studios) s.id};
    final visible = [
      for (final r in results[1] as List)
        if (known.contains(r['studio_id'])) bookingFromRow(r as Map<String, dynamic>),
    ];
    final seen = {for (final b in visible) b.id};
    final busy = [
      for (final r in results[2] as List)
        if (!seen.contains(r['id']) && known.contains(r['studio_id']))
          _privateFromRow(r as Map<String, dynamic>),
    ];
    final quota = settings['student_quota_minutes'] as int?;
    final policy = Policy(
      openingHour: settings['opening_hour'] as int,
      closingHour: settings['closing_hour'] as int,
      slotMinutes: settings['slot_minutes'] as int,
      maxAdvanceDays: settings['max_advance_days'] as int,
      weeklyQuotaMinutes: {if (quota != null) RequesterType.student: quota},
      qrGraceMinutes: settings['qr_grace_minutes'] as int,
      charterVersion: settings['charter_version'] as String,
    );
    final signed = <String, String>{};
    final signedAt = <String, DateTime>{};
    for (final r in results[4] as List) {
      final slug = _slugById[r['person_id']];
      if (slug == null) continue;
      if (r['version'] == policy.charterVersion || !signed.containsKey(slug)) {
        signed[slug] = r['version'] as String;
        signedAt[slug] = _time(r['signed_at']);
      }
    }
    container.read(worldProvider.notifier).load(
          WorldState(
            now: now,
            policy: policy,
            bookings: [...visible, ...busy],
            maintenance: [
              for (final m in results[3] as List)
                MaintenanceBlock(
                  roomId: m['room_id'] as String,
                  start: _time(m['start_at']),
                  end: _time(m['end_at']),
                  reason: m['reason'] as String,
                ),
            ],
            signedCharterVersion: signed,
            charterSignedAt: signedAt,
          ),
        );
  }
}

DateTime _time(Object? v) => DateTime.parse(v as String).toLocal();

/// A slot someone else holds: when and where, never who or why.
Booking _privateFromRow(Map<String, dynamic> r) => Booking(
      id: r['id'] as String,
      reference: '',
      requesterId: otherPersonId,
      requesterType: RequesterType.student,
      studioId: r['studio_id'] as String,
      start: _time(r['start_at']),
      end: _time(r['end_at']),
      activity: Activity.recording,
      status: BookingStatus.values.byName(r['status'] as String),
      history: const [],
      isPrivate: true,
    );

Booking bookingFromRow(Map<String, dynamic> r) => Booking(
      id: r['id'] as String,
      reference: r['reference'] as String,
      requesterId: r['requester_slug'] as String,
      requesterType: RequesterType.values.byName(r['requester_type'] as String),
      establishmentId: r['establishment_id'] as String?,
      clubId: r['club_id'] as String?,
      projectId: r['project_id'] as String?,
      studioId: r['studio_id'] as String,
      start: _time(r['start_at']),
      end: _time(r['end_at']),
      activity: Activity.values.byName(r['activity'] as String),
      status: BookingStatus.values.byName(r['status'] as String),
      note: r['note'] as String?,
      refusalReason: r['refusal_reason'] as String?,
      technicianId: r['technician_slug'] as String?,
      equipment: [
        for (final e in (r['equipment'] as List? ?? const []))
          if (DemoWorld.equipment.any((x) => x.id == e['item_id']))
          EquipmentRequest(
            itemId: e['item_id'] as String,
            quantity: e['quantity'] as int,
            required: e['required'] as bool? ?? false,
            outcome: EquipmentOutcome.values
                .byName(e['outcome'] as String? ?? 'pending'),
            note: e['note'] as String?,
          ),
      ],
      history: [
        for (final e in (r['history'] as List? ?? const []))
          BookingEvent(
            type: BookingEventType.values.byName(e['type'] as String),
            at: _time(e['at']),
            actorId: e['actor'] as String,
            comment: e['comment'] as String?,
          ),
      ],
    );

List<Map<String, dynamic>> equipmentToJson(List<EquipmentRequest> items) => [
      for (final e in items)
        {
          'item_id': e.itemId,
          'quantity': e.quantity,
          'required': e.required,
          'outcome': e.outcome.name,
          if (e.note != null) 'note': e.note,
        },
    ];
