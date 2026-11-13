import 'package:euromed_studios/data/app_state.dart';
import 'package:euromed_studios/data/demo_world.dart';
import 'package:euromed_studios/data/selectors.dart';
import 'package:euromed_studios/domain/bookings.dart';
import 'package:euromed_studios/domain/people.dart';
import 'package:euromed_studios/domain/rules/notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer asPerson(String id) => ProviderContainer(
      overrides: [currentPersonIdProvider.overrideWith((ref) => id)],
    );

void main() {
  test('approvers see what waits for them, as actionable notices', () {
    final c = asPerson('tazi');
    addTearDown(c.dispose);
    final feed = c.read(noticesProvider);
    final pendingStudio = c
        .read(worldProvider)
        .bookings
        .where((b) => b.status == BookingStatus.pendingStudio)
        .length;
    expect(feed.where((n) => n.actionable).length, pendingStudio);
    expect(c.read(unreadNoticesProvider), greaterThanOrEqualTo(pendingStudio));
  });

  test('a student is told when their request moves, never about others', () {
    final c = asPerson('yasmine');
    addTearDown(c.dispose);
    final feed = c.read(noticesProvider);
    expect(feed.where((n) => n.actionable), isEmpty);
    final mine = {
      for (final b in c.read(worldProvider).bookings)
        if (b.requesterId == 'yasmine') b.id,
    };
    for (final n in feed) {
      expect(mine.any((id) => n.route.contains(id)), isTrue, reason: n.title);
    }
  });

  test('a decision creates a notice for the requester; opening clears unread',
      () {
    final c = asPerson('yasmine');
    addTearDown(c.dispose);
    final w = c.read(worldProvider.notifier);
    final b = c
        .read(worldProvider)
        .bookings
        .firstWhere((x) => x.status == BookingStatus.pendingEntity && x.requesterId == 'yasmine');
    final amrani = DemoWorld.people.firstWhere((p) => p.id == 'amrani');
    w.approve(b.id, by: amrani);
    final feed = c.read(noticesProvider);
    expect(feed.first.kind, NoticeKind.progress);
    expect(c.read(unreadNoticesProvider), greaterThan(0));
    w.markNoticesSeen('yasmine');
    expect(c.read(unreadNoticesProvider), 0);
  });

  test('own actions never notify yourself', () {
    final c = asPerson('amrani');
    addTearDown(c.dispose);
    final b = c
        .read(worldProvider)
        .bookings
        .firstWhere((x) => x.status == BookingStatus.pendingEntity && x.requesterType == RequesterType.student);
    final before = c.read(noticesProvider).length;
    c.read(worldProvider.notifier).approve(
          b.id,
          by: DemoWorld.people.firstWhere((p) => p.id == 'amrani'),
        );
    // The "to decide" notice disappears and nothing new appears for amrani.
    expect(c.read(noticesProvider).length, before - 1);
  });
}
