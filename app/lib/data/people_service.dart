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
          },
        );
        await liveSync?.refresh();
      } on PostgrestException catch (e) {
        final code = RegExp('[a-z_]+').stringMatch(e.message) ?? '';
        throw AccessProblem(accessProblemText(code));
      }
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 400));
    final changes = accessChanges(
      target,
      roles: roles,
      scopes: keepScopes,
      clubs: keepClubs,
      active: active,
    );
    if (changes.isEmpty) return;
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
