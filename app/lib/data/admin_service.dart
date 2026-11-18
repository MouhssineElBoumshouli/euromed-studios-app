/// I4–I7 · Admin changes to rules, studios, maintenance, equipment and the
/// charter. Live: server functions that check and log every change.
/// Offline: the same checks on the in-memory demo.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity.dart';
import '../domain/bookings.dart';
import '../domain/people.dart';
import '../domain/policy.dart';
import '../domain/rules/settings_rules.dart';
import 'admin_state.dart';
import 'app_state.dart';
import 'backend.dart';
import 'catalog.dart';
import 'live_sync.dart';

class AdminProblem implements Exception {
  const AdminProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

class AdminService {
  AdminService(this._ref);
  final Ref _ref;

  SupabaseClient get _db => Supabase.instance.client;
  WorldState get _world => _ref.read(worldProvider);

  Future<T> _live<T>(Future<T> Function() run) async {
    try {
      final r = await run();
      try {
        await liveSync?.refresh();
      } catch (_) {}
      return r;
    } on PostgrestException catch (e) {
      final code = RegExp('[a-z_]+').stringMatch(e.message) ?? '';
      throw AdminProblem(adminProblemText(code));
    } on AdminProblem {
      rethrow;
    } catch (_) {
      // No network, a timeout, an expired session…
      throw AdminProblem(adminProblemText('network'));
    }
  }

  void _log(Person by, String action, String summary, {String? target}) {
    final admin = _ref.read(adminProvider.notifier);
    admin.load(
      AdminState(
        audit: [
          AuditEntry(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            at: _world.now,
            actorId: by.id,
            action: action,
            targetId: target,
            summary: summary,
          ),
          ..._ref.read(adminProvider).audit,
        ],
      ),
    );
  }

  Future<void> _wait() =>
      Future<void>.delayed(const Duration(milliseconds: 350));

  /// I6 · Opening hours, slot length, booking window, quota, entry window.
  Future<void> updateRules(Person by, RulesDraft d) async {
    final problem = rulesProblem(d);
    if (problem != null) throw AdminProblem(adminProblemText(problem));
    if (!by.has(Role.admin)) {
      throw AdminProblem(adminProblemText('not_allowed'));
    }
    if (isLive) {
      await _live(
        () => _db.rpc(
          'update_settings',
          params: {
            'p_opening': d.openingHour,
            'p_closing': d.closingHour,
            'p_slot': d.slotMinutes,
            'p_advance': d.maxAdvanceDays,
            'p_quota': d.studentQuota,
            'p_grace': d.qrGraceMinutes,
          },
        ),
      );
      return;
    }
    await _wait();
    final p = _world.policy;
    final changes = rulesChanges(RulesDraft.of(p), d);
    if (changes.isEmpty) return;
    _ref.read(worldProvider.notifier).setPolicy(
          Policy(
            openingHour: d.openingHour,
            closingHour: d.closingHour,
            slotMinutes: d.slotMinutes,
            openWeekdays: p.openWeekdays,
            maxAdvanceDays: d.maxAdvanceDays,
            weeklyQuotaMinutes: {
              for (final e in p.weeklyQuotaMinutes.entries)
                if (e.key != RequesterType.student) e.key: e.value,
              if (d.studentQuota != null)
                RequesterType.student: d.studentQuota!,
            },
            qrGraceMinutes: d.qrGraceMinutes,
            charterVersion: p.charterVersion,
          ),
        );
    _log(by, 'settingsChanged', changes.join(' · '));
  }

  /// I4 · Open or close a studio to booking.
  Future<void> setStudioBookable(Person by, String studioId, bool value) async {
    if (!by.has(Role.admin)) {
      throw AdminProblem(adminProblemText('not_allowed'));
    }
    if (isLive) {
      await _live(
        () => _db.rpc(
          'set_studio_bookable',
          params: {'p_id': studioId, 'p_bookable': value},
        ),
      );
      return;
    }
    await _wait();
    final s = Catalog.studios.firstWhere((x) => x.id == studioId);
    if (s.bookable == value) return;
    Catalog.setBookable(studioId, value);
    _ref.read(worldProvider.notifier).touch();
    _log(
      by,
      'studioChanged',
      '${s.name} : ${value ? 'ouvert' : 'fermé'} à la réservation',
      target: studioId,
    );
  }

  /// I4 · Plan a closure. Returns how many sessions fall in that window.
  Future<int> addMaintenance(
    Person by, {
    required String roomId,
    required DateTime start,
    required DateTime end,
    required String reason,
  }) async {
    final problem = maintenanceProblem(
      by: by,
      start: start,
      end: end,
      reason: reason,
      now: _world.now,
      existing: [
        for (final m in _world.maintenance)
          if (m.roomId == roomId) m,
      ],
    );
    if (problem != null) throw AdminProblem(adminProblemText(problem));
    if (isLive) {
      final n = await _live(
        () => _db.rpc(
          'add_maintenance',
          params: {
            'p_room': roomId,
            'p_start': start.toUtc().toIso8601String(),
            'p_end': end.toUtc().toIso8601String(),
            'p_reason': reason.trim(),
          },
        ),
      );
      return (n as num?)?.toInt() ?? 0;
    }
    await _wait();
    final rooms = {for (final s in Catalog.studios) s.id: s.roomId};
    final clashes = _world.bookings
        .where(
          (b) =>
              rooms[b.studioId] == roomId &&
              (b.status == BookingStatus.approved || b.status.isPending) &&
              b.start.isBefore(end) &&
              start.isBefore(b.end),
        )
        .length;
    _ref.read(worldProvider.notifier).setMaintenance([
      ..._world.maintenance,
      MaintenanceBlock(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        roomId: roomId,
        start: start,
        end: end,
        reason: reason.trim(),
      ),
    ]);
    _log(
        by,
        'maintenancePlanned',
        '${roomName(roomId)} : ${reason.trim()}'
            '${clashes > 0 ? ' · $clashes séance(s) concernée(s)' : ''}');
    return clashes;
  }

  Future<void> removeMaintenance(Person by, MaintenanceBlock m) async {
    if (!(by.has(Role.admin) || by.has(Role.studioManager))) {
      throw AdminProblem(adminProblemText('not_allowed'));
    }
    if (isLive) {
      await _live(
        () => _db.rpc('remove_maintenance', params: {'p_id': m.id}),
      );
      return;
    }
    await _wait();
    _ref.read(worldProvider.notifier).setMaintenance([
      for (final x in _world.maintenance)
        if (!identical(x, m) && (x.id.isEmpty || x.id != m.id)) x,
    ]);
    _log(by, 'maintenanceRemoved', '${roomName(m.roomId)} : ${m.reason}');
  }

  /// I5 · Stock of an equipment item.
  Future<void> setStock(Person by, String itemId, int stock) async {
    if (!by.has(Role.admin)) {
      throw AdminProblem(adminProblemText('not_allowed'));
    }
    if (stock < 0 || stock > 999) {
      throw AdminProblem(adminProblemText('bad_stock'));
    }
    if (isLive) {
      await _live(
        () => _db.rpc(
          'set_equipment_stock',
          params: {'p_id': itemId, 'p_stock': stock},
        ),
      );
      return;
    }
    await _wait();
    final e = Catalog.equipment.firstWhere((x) => x.id == itemId);
    if (e.stock == stock) return;
    Catalog.setStock(itemId, stock);
    _ref.read(worldProvider.notifier).touch();
    _log(by, 'equipmentChanged', '${e.name} : stock ${e.stock} → $stock',
        target: itemId);
  }

  /// I7 · Publish a new charter version: everyone signs again.
  Future<void> publishCharter(Person by, String version) async {
    final problem =
        charterVersionProblem(version, _world.policy.charterVersion);
    if (problem != null) throw AdminProblem(adminProblemText(problem));
    if (!by.has(Role.admin)) {
      throw AdminProblem(adminProblemText('not_allowed'));
    }
    if (isLive) {
      await _live(
        () => _db.rpc('publish_charter', params: {'p_version': version.trim()}),
      );
      return;
    }
    await _wait();
    final p = _world.policy;
    _ref.read(worldProvider.notifier).setPolicy(
          Policy(
            openingHour: p.openingHour,
            closingHour: p.closingHour,
            slotMinutes: p.slotMinutes,
            openWeekdays: p.openWeekdays,
            maxAdvanceDays: p.maxAdvanceDays,
            weeklyQuotaMinutes: p.weeklyQuotaMinutes,
            qrGraceMinutes: p.qrGraceMinutes,
            charterVersion: version.trim(),
          ),
        );
    _log(by, 'charterPublished',
        'Charte : version ${p.charterVersion} → ${version.trim()}');
  }
}

/// "Plateau TV / Euromed Radio" for a room shared by two studios.
String roomName(String roomId) {
  final names = [
    for (final s in Catalog.studios)
      if (s.roomId == roomId) s.name,
  ];
  return names.isEmpty ? roomId : names.join(' / ');
}

final adminServiceProvider = Provider<AdminService>(AdminService.new);
