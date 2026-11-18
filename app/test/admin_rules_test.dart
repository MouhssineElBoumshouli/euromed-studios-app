import 'package:euromed_studios/data/demo_world.dart';
import 'package:euromed_studios/domain/people.dart';
import 'package:euromed_studios/domain/rules/admin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final people = {for (final p in DemoWorld.people) p.id: p};
  final admin = people['idrissi']!;
  final haddad = people['haddad']!;

  String? check(
    Person target, {
    Person? by,
    Set<Role>? roles,
    List<ApproverScope>? scopes,
    List<String>? clubs,
    bool? active,
    List<Person>? everyone,
  }) =>
      accessProblem(
        by: by ?? admin,
        target: target,
        roles: roles ?? target.roles,
        scopes: scopes ?? target.approverScopes,
        clubs: clubs ?? target.clubIds,
        active: active ?? target.active,
        everyone: everyone ?? DemoWorld.people,
      );

  test('only an admin changes access', () {
    expect(check(haddad, by: people['tazi']), 'not_allowed');
    expect(check(haddad, roles: {Role.regisseur, Role.student}), isNull);
  });

  test('at least one role', () {
    expect(check(haddad, roles: {}), 'no_role');
  });

  test('a level-1 approver needs a scope; a club rep needs a club', () {
    expect(check(haddad, roles: {Role.entityApprover}, scopes: []),
        'scope_required');
    expect(
      check(haddad,
          roles: {Role.entityApprover},
          scopes: [const ApproverScope(RequesterType.student)]),
      isNull,
    );
    expect(check(haddad, roles: {Role.clubRepresentative}, clubs: []),
        'club_required');
  });

  test('an admin cannot lock themselves out', () {
    expect(check(admin, roles: {Role.studioManager}), 'self_lockout');
    expect(check(admin, active: false), 'self_lockout');
  });

  test('the last active admin stays', () {
    final second = haddad.copyWith(roles: {Role.admin});
    final everyone = [admin, second];
    // Another admin removing the only other admin is fine while one stays.
    expect(check(second, roles: {Role.regisseur}, everyone: everyone), isNull);
    // But not when the target is the last active admin.
    final lonely = [admin, second.copyWith(active: false)];
    expect(
      check(admin,
          by: second.copyWith(roles: {Role.admin}),
          roles: {Role.regisseur},
          everyone: lonely),
      'last_admin',
    );
  });

  test('changes are described in plain words', () {
    final c = accessChanges(haddad,
        roles: {Role.regisseur, Role.student},
        scopes: const [],
        clubs: const [],
        active: false);
    expect(c, contains('+ ${Role.student.label}'));
    expect(c, contains('compte désactivé'));
    expect(
      accessChanges(haddad,
          roles: haddad.roles,
          scopes: haddad.approverScopes,
          clubs: haddad.clubIds,
          active: true),
      isEmpty,
    );
  });
}
