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
import '../domain/activity.dart';
import '../domain/people.dart';
import '../domain/policy.dart';
import '../domain/projects.dart';
import 'app_state.dart';
import 'backend.dart';
import 'admin_state.dart';
import 'demo_world.dart';
import 'directory.dart';
import 'projects_state.dart';

/// Set by main() when the app runs against the server.
LiveSync? liveSync;

class LiveSync {
  LiveSync(this.container);
  final ProviderContainer container;

  SupabaseClient get db => Supabase.instance.client;
  RealtimeChannel? _channel;
  Timer? _clock;
  Timer? _debounce;

  Future<void> start() async {
    liveStatus.value = db.auth.currentSession == null
        ? LiveStatus.signedOut
        : LiveStatus.loading;
    db.auth.onAuthStateChange.listen((e) {
      final session = e.session;
      if (session == null) {
        _generation++;
        _readyUid = null;
        _stop();
        _clearWorld();
        liveStatus.value = LiveStatus.signedOut;
      } else if (e.event == AuthChangeEvent.signedIn ||
          e.event == AuthChangeEvent.initialSession) {
        // Supabase may repeat "signed in" for the same person (e.g. when
        // the tab regains focus): keep the current screen in that case.
        if (_readyUid == session.user.id &&
            liveStatus.value == LiveStatus.ready) {
          return;
        }
        _enter(++_generation, session.user.id);
      }
    });
  }

  Future<void> signIn(String slug) {
    loginNotice.value = null;
    return _signIn(slug);
  }

  Future<void> _signIn(String slug) => db.auth.signInWithPassword(
        email: demoEmail(slug),
        password: kDemoPassword,
      );

  Future<void> signOut() => db.auth.signOut();

  /// Each sign-in or sign-out starts a new "generation". A slower load
  /// from a previous account is dropped instead of overwriting the new
  /// one (e.g. switching from Mehdi to Karim quickly).
  int _generation = 0;
  String? _readyUid;

  /// Empties the world so nothing of the previous account stays on screen.
  void _clearWorld() {
    final w = container.read(worldProvider);
    container.read(worldProvider.notifier).load(
          WorldState(
            now: DateTime.now(),
            policy: w.policy,
            bookings: const [],
            maintenance: const [],
            signedCharterVersion: const {},
          ),
        );
    container
        .read(projectsProvider.notifier)
        .load(const ProjectsState(loaded: false));
    // An admin's log must not stay visible to the next person.
    container.read(adminProvider.notifier).load(const AdminState());
  }

  Future<void> _enter(int gen, String uid) async {
    _stop();
    _clearWorld();
    liveStatus.value = LiveStatus.loading;
    try {
      final me = await db
          .from('profiles')
          .select('slug, active')
          .eq('id', uid)
          .single();
      if (gen != _generation) return;
      if (me['active'] == false) {
        loginNotice.value = 'Ce compte a été désactivé par '
            'l’administration. Contactez la Direction des Studios.';
        await db.auth.signOut();
        return;
      }
      container.read(currentPersonIdProvider.notifier).state =
          me['slug'] as String;
      await refresh(gen);
      if (gen != _generation) return;
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
      _clock = Timer.periodic(
        const Duration(seconds: 30),
        (_) => refresh(gen),
      );
      _readyUid = uid;
      liveStatus.value = LiveStatus.ready;
    } catch (_) {
      if (gen == _generation) await db.auth.signOut();
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
    final gen = _generation;
    _debounce = Timer(const Duration(milliseconds: 250), () => refresh(gen));
  }

  Map<String, String> _slugById = {};

  /// Reloads everything this person may see. A load started for another
  /// account ([gen] out of date) is thrown away instead of shown.
  Future<void> refresh([int? gen]) async {
    gen ??= _generation;
    final now = DateTime.now();
    // The directory: everyone's name, roles and scopes (small table).
    final people = await db.from('profiles').select();
    if (gen != _generation) return;
    _slugById = {
      for (final p in people) p['id'] as String: p['slug'] as String,
    };
    final directory = [for (final p in people) personFromRow(p)];
    final mine = directory
        .where((p) => p.id == container.read(currentPersonIdProvider))
        .firstOrNull;
    if (mine != null && !mine.active) {
      // An admin turned this account off: sign out with an explanation.
      loginNotice.value = 'Ce compte a été désactivé par l’administration. '
          'Contactez la Direction des Studios.';
      await db.auth.signOut();
      return;
    }
    container.read(directoryProvider.notifier).replace(directory);
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
      // Private "read up to" time; a missing table must not block sign-in.
      Future<dynamic>.value(
        db
            .from('notification_reads')
            .select('seen_at')
            .maybeSingle()
            .catchError((_) => null),
      ),
      // Projects arrived later; a missing table must not block sign-in.
      Future<dynamic>.value(
        db
            .from('projects')
            .select()
            .then<dynamic>((v) => v)
            .catchError((_) => <dynamic>[]),
      ),
      Future<dynamic>.value(
        db
            .from('project_files')
            .select()
            .then<dynamic>((v) => v)
            .catchError((_) => <dynamic>[]),
      ),
      Future<dynamic>.value(
        db
            .from('project_messages')
            .select()
            .then<dynamic>((v) => v)
            .catchError((_) => <dynamic>[]),
      ),
      Future<dynamic>.value(
        db
            .from('project_invites')
            .select()
            .then<dynamic>((v) => v)
            .catchError((_) => <dynamic>[]),
      ),
      // Admins only (the server returns nothing to others).
      Future<dynamic>.value(
        db
            .from('audit_log')
            .select()
            .order('at', ascending: false)
            .limit(500)
            .then<dynamic>((v) => v)
            .catchError((_) => <dynamic>[]),
      ),
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
    if (gen != _generation) return;
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
            noticesSeenAt: {
              if (results[5] != null)
                container.read(currentPersonIdProvider):
                    _time(results[5]['seen_at']),
            },
          ),
        );
    container.read(adminProvider.notifier).load(
          AdminState(
            audit: [
              for (final r in results[10] as List)
                AuditEntry(
                  id: '${r['id']}',
                  at: _time(r['at']),
                  actorId: r['actor_slug'] as String?,
                  action: r['action'] as String,
                  targetType: r['target_type'] as String?,
                  targetId: r['target_id'] as String?,
                  summary: r['summary'] as String,
                ),
            ],
          ),
        );
    container.read(projectsProvider.notifier).load(
          ProjectsState(
            projects: [
              for (final r in results[6] as List)
                if (projectFromRow(r as Map<String, dynamic>) case final p?) p,
            ],
            files: [
              for (final r in results[7] as List)
                if (fileFromRow(r as Map<String, dynamic>) case final f?) f,
            ],
            messages: [
              for (final r in results[8] as List)
                if (messageFromRow(r as Map<String, dynamic>) case final m?) m,
            ],
            invites: [
              for (final r in results[9] as List)
                if (inviteFromRow(r as Map<String, dynamic>) case final i?) i,
            ],
          ),
        );
  }
}

T? _enum<T extends Enum>(List<T> values, Object? name) =>
    values.where((v) => v.name == name).firstOrNull;

/// A project row, or null if it holds a value this app doesn't know
/// (one odd row must not break the whole load).
Project? projectFromRow(Map<String, dynamic> r) {
  final type = _enum(ProjectType.values, r['type']);
  final stage = _enum(ProjectStage.values, r['stage']);
  if (type == null || stage == null) return null;
  return Project(
    id: r['id'] as String,
    title: r['title'] as String,
    description: r['description'] as String?,
    type: type,
    stage: stage,
    ownerId: r['owner_slug'] as String,
    memberIds: [
      for (final m in (r['member_slugs'] as List? ?? const [])) m as String,
    ],
    createdAt: _time(r['created_at']),
    postStatus:
        _enum(PostStatus.values, r['post_status']) ?? PostStatus.notStarted,
    deliveryUrl: r['delivery_url'] as String?,
    deliveredAt:
        r['delivered_at'] == null ? null : _time(r['delivered_at']),
    qcNote: r['qc_note'] as String?,
    history: [
      for (final e in (r['history'] as List? ?? const []))
        if (_enum(ProjectEventType.values, e['type']) case final t?)
          ProjectEvent(
            type: t,
            at: _time(e['at']),
            actorId: e['actor'] as String? ?? '',
            detail: e['detail'] as String?,
          ),
    ],
  );
}

ProjectFile? fileFromRow(Map<String, dynamic> r) {
  final kind = _enum(FileKind.values, r['kind']);
  if (kind == null) return null;
  return ProjectFile(
    id: r['id'] as String,
    projectId: r['project_id'] as String,
    kind: kind,
    name: r['name'] as String,
    path: r['path'] as String,
    sizeBytes: r['size_bytes'] as int,
    uploadedBy: r['uploaded_by'] as String,
    uploadedAt: _time(r['uploaded_at']),
  );
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

ProjectMessage? messageFromRow(Map<String, dynamic> r) {
  final kind = _enum(MessageKind.values, r['kind']);
  if (kind == null) return null;
  return ProjectMessage(
    id: r['id'] as String,
    projectId: r['project_id'] as String,
    authorId: r['author_slug'] as String,
    kind: kind,
    body: r['body'] as String,
    at: _time(r['created_at']),
  );
}

ProjectInvite? inviteFromRow(Map<String, dynamic> r) {
  final status = _enum(InviteStatus.values, r['status']);
  if (status == null) return null;
  return ProjectInvite(
    id: r['id'] as String,
    projectId: r['project_id'] as String,
    projectTitle: r['project_title'] as String,
    inviteeId: r['invitee_slug'] as String,
    invitedBy: r['invited_by'] as String,
    status: status,
    at: _time(r['created_at']),
  );
}

T? _byName<T extends Enum>(List<T> values, Object? name) =>
    values.where((v) => v.name == name).firstOrNull;

/// A profile row as a [Person]. Unknown roles or scope types are skipped.
Person personFromRow(Map<String, dynamic> r) => Person(
      id: r['slug'] as String,
      firstName: r['first_name'] as String? ?? '',
      lastName: r['last_name'] as String? ?? '',
      title: r['title'] as String?,
      establishmentId: r['establishment_id'] as String?,
      roles: {
        for (final x in (r['roles'] as List? ?? const []))
          if (_byName(Role.values, x) case final role?) role,
      },
      approverScopes: [
        for (final s in (r['approver_scopes'] as List? ?? const []))
          if (_byName(RequesterType.values, (s as Map)['type']) case final t?)
            ApproverScope(t, establishmentId: s['establishment_id'] as String?),
      ],
      clubIds: [
        for (final c in (r['club_ids'] as List? ?? const [])) c as String,
      ],
      active: r['active'] as bool? ?? true,
    );
