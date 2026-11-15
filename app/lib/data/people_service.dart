/// I3 · Saves an admin's change to someone's access (live: the
/// set_person_access server function; offline: the demo directory).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity.dart';
import '../domain/people.dart';
import '../domain/rules/admin.dart';
import 'admin_state.dart';
import 'app_state.dart';
import 'backend.dart';
import 'directory.dart';
import 'live_sync.dart';

class AccessProblem implements Exception {
  const AccessProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

class PeopleService {
  PeopleService(this._ref);
  final Ref _ref;

  Future<void> setAccess({
    required Person by,
    required Person target,
    required Set<Role> roles,
    required List<ApproverScope> scopes,
    required List<String> clubs,
    required bool active,
    bool cancelPending = false,
  }) async {
    final keepScopes =
        roles.contains(Role.entityApprover) ? scopes : const <ApproverScope>[];
    final keepClubs =
        roles.contains(Role.clubRepresentative) ? clubs : const <String>[];
    final problem = accessProblem(
      by: by,
      target: target,
      roles: roles,
      scopes: keepScopes,
      clubs: keepClubs,
      active: active,
      everyone: Directory.people,
    );
    if (problem != null) throw AccessProblem(accessProblemText(problem));

    if (isLive) {
      try {
        await Supabase.instance.client.rpc(
          'set_person_access',
          params: {
            'p_slug': target.id,
            'p_roles': [for (final r in roles) r.name],
            'p_scopes': [
              for (final s in keepScopes)
                {
                  'type': s.requesterType.name,
                  if (s.establishmentId != null)
                    'establishment_id': s.establishmentId,
                },
            ],
            'p_clubs': keepClubs,
            'p_active': active,
            // What the admin saw: the server refuses if it changed since.
            'p_expected': {
              'roles': [for (final r in target.roles) r.name],
              'scopes': [
                for (final s in target.approverScopes)
                  {
                    'type': s.requesterType.name,
                    if (s.establishmentId != null)
                      'establishment_id': s.establishmentId,
                  },
              ],
              'clubs': target.clubIds,
              'active': target.active,
            },
            'p_cancel_pending': cancelPending,
          },
        );
      } on PostgrestException catch (e) {
        final code = RegExp('[a-z_]+').stringMatch(e.message) ?? '';
        throw AccessProblem(accessProblemText(code));
      }
      // Saved. A failed reload must not look like a failed save.
      try {
        await liveSync?.refresh();
      } catch (_) {}
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 400));
    final current =
        Directory.people.where((p) => p.id == target.id).firstOrNull;
    if (current == null || !current.sameAs(target)) {
      throw AccessProblem(accessProblemText('stale'));
    }
    final changes = accessChanges(
      target,
      roles: roles,
      scopes: keepScopes,
      clubs: keepClubs,
      active: active,
    );
    if (changes.isEmpty) return;
    if (!active && cancelPending) {
      final world = _ref.read(worldProvider.notifier);
      for (final b in _ref.read(worldProvider).bookings) {
        if (b.requesterId == target.id && b.status.isPending) {
          world.cancel(b.id, by: by, reason: 'Compte désactivé par '
              'l’administration');
        }
      }
    }
    _ref.read(directoryProvider.notifier).update(
          target.copyWith(
            roles: roles,
            approverScopes: keepScopes,
            clubIds: keepClubs,
            active: active,
          ),
        );
    final admin = _ref.read(adminProvider.notifier);
    admin.load(
      AdminState(
        audit: [
          AuditEntry(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            at: _ref.read(worldProvider).now,
            actorId: by.id,
            action: active != target.active
                ? (active ? 'accountEnabled' : 'accountDisabled')
                : 'rolesChanged',
            targetType: 'person',
            targetId: target.id,
            summary: '${target.fullName} : ${changes.join(' · ')}',
          ),
          ..._ref.read(adminProvider).audit,
        ],
      ),
    );
  }
}

final peopleServiceProvider = Provider<PeopleService>(PeopleService.new);
