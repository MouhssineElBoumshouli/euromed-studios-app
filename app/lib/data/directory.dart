/// Everyone the app knows (names, roles, scopes).
///
/// Offline it holds the fictional demo people. Live, [LiveSync] replaces
/// it with the profiles from the server on every refresh, so a role an
/// admin changes reaches everyone's app within seconds.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/people.dart';
import 'backend.dart';
import 'demo_world.dart';

/// A plain mirror of the directory, for code that has no `ref`
/// (e.g. [personById]). Always equal to [directoryProvider]'s state.
abstract final class Directory {
  static List<Person> _people = DemoWorld.people;
  static List<Person> get people => _people;
}

class DirectoryNotifier extends Notifier<List<Person>> {
  @override
  List<Person> build() {
    // Live, nobody is known until the first load (no fictional names).
    if (isLive) Directory._people = const [];
    return Directory._people;
  }

  void replace(List<Person> people) {
    // Skip identical reloads, so the 30 s refresh doesn't rebuild screens.
    if (people.length == state.length &&
        [for (var i = 0; i < people.length; i++) people[i].sameAs(state[i])]
            .every((x) => x)) {
      return;
    }
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
