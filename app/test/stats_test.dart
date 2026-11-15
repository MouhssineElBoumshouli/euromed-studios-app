import 'package:euromed_studios/data/demo_world.dart';
import 'package:euromed_studios/domain/activity.dart';
import 'package:euromed_studios/domain/bookings.dart';
import 'package:euromed_studios/domain/policy.dart';
import 'package:euromed_studios/domain/rules/stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = Policy();
  final now = DemoWorld.now;

  test('week starts on Monday', () {
    final s = weekStart(DateTime(2026, 11, 12, 15)); // Thursday
    expect(s, DateTime(2026, 11, 9));
  });

  test('open minutes count only open weekdays', () {
    final from = DateTime(2026, 11, 9);
    final to = DateTime(2026, 11, 16);
    // 5 days × 9 h
    expect(openMinutes(policy, from, to), 5 * 9 * 60);
  });

  test('occupancy counts only held slots, clipped to the period', () {
    final from = weekStart(now);
    final to = DateTime(from.year, from.month, from.day + 7);
    final loads =
        occupancy(DemoWorld.studios, DemoWorld.bookings, policy, from, to);
    for (final l in loads) {
      expect(l.rate, inInclusiveRange(0, 1));
      expect(l.studio.bookable, isTrue);
    }
    final held = DemoWorld.bookings.where(
      (b) => holdsStudio(b) && !b.start.isBefore(from) && b.end.isBefore(to),
    );
    final minutes = held.fold(0, (s, b) => s + b.end.difference(b.start).inMinutes);
    expect(loads.fold(0, (s, l) => s + l.bookedMinutes), minutes);
  });

  test('pending summary splits the two levels and finds the oldest', () {
    final p = pendingSummary(DemoWorld.bookings);
    final l1 = DemoWorld.bookings
        .where((b) => b.status == BookingStatus.pendingEntity)
        .length;
    expect(p.atEntity, l1);
    if (p.oldest != null) {
      for (final b in DemoWorld.bookings.where((b) => b.status.isPending)) {
        expect(
          b.history.last.at.isBefore(p.oldest!.history.last.at),
          isFalse,
        );
      }
    }
  });

  test('median approval time of an odd and an even list', () {
    Booking with2(Duration wait, String id) {
      final base = DemoWorld.bookings.first;
      final sent = now.subtract(const Duration(days: 2));
      return base.copyWith(
        history: [
          BookingEvent(
            type: BookingEventType.submitted,
            at: sent,
            actorId: 'x',
          ),
          BookingEvent(
            type: BookingEventType.studioApproved,
            at: sent.add(wait),
            actorId: 'y',
          ),
        ],
      );
    }

    final t = approvalTimes([
      with2(const Duration(hours: 2), 'a'),
      with2(const Duration(hours: 4), 'b'),
      with2(const Duration(hours: 9), 'c'),
    ], now)!;
    expect(t.median, const Duration(hours: 4));
    expect(t.average, const Duration(hours: 5));
  });

  test('activity feed is newest first and covers admin actions', () {
    final feed = activityFeed(
      bookings: DemoWorld.bookings,
      projects: const [],
      audit: [
        AuditEntry(
          id: '1',
          at: now,
          action: 'settingsChanged',
          summary: 'Fenêtre : 21 → 30 jours',
          actorId: 'idrissi',
        ),
      ],
      describe: (b) => b.reference,
      nameOf: (id) => id,
    );
    for (var i = 1; i < feed.length; i++) {
      expect(feed[i].at.isAfter(feed[i - 1].at), isFalse);
    }
    expect(feed.any((i) => i.category == ActivityCategory.admin), isTrue);
  });
}
