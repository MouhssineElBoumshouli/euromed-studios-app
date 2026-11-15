/// Everyone the app knows (names, roles, scopes).
///
/// Offline it holds the fictional demo people. Live, [LiveSync] replaces
/// it with the profiles from the server on every refresh, so a role an
/// admin changes reaches everyone's app within seconds.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/people.dart';
import 'demo_world.dart';

/// A plain mirror of the directory, for code that has no `ref`
/// (e.g. [personById]). Always equal to [directoryProvider]'s state.
abstract final class Directory {
  static List<Person> _people = DemoWorld.people;
  static List<Person> get people => _people;
}

class DirectoryNotifier extends Notifier<List<Person>> {
  @override
  List<Person> build() => Directory._people;

  void replace(List<Person> people) {
    Directory._people = people;
    state = people;
  }

  /// Offline: apply an admin's change to one person.
  void update(Person p) => replace([
        for (final x in state) x.id == p.id ? p : x,
      ]);
}

final directoryProvider =
    NotifierProvider<DirectoryNotifier, List<Person>>(DirectoryNotifier.new);
