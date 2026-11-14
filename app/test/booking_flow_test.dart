import 'package:euromed_studios/app/app.dart';
import 'package:euromed_studios/app/router.dart';
import 'package:euromed_studios/data/app_state.dart';
import 'package:euromed_studios/data/demo_world.dart';
import 'package:euromed_studios/domain/bookings.dart';
import 'package:euromed_studios/domain/people.dart';
import 'package:euromed_studios/features/bookings/qr_pass_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'fr_FR';
    await initializeDateFormatting('fr_FR');
  });

  group('QR window (R-28, P-10)', () {
    final b1 = DemoWorld.bookings.firstWhere((b) => b.id == 'b1');

    test('not active before, active during, over after', () {
      expect(qrWindow(b1, b1.start.subtract(const Duration(minutes: 1)), 0),
          QrWindow.notYet);
      expect(qrWindow(b1, b1.start, 0), QrWindow.active);
      expect(qrWindow(b1, b1.end.subtract(const Duration(minutes: 1)), 0),
          QrWindow.active);
      expect(qrWindow(b1, b1.end, 0), QrWindow.over);
    });

    test('the grace period set by the admin widens the window', () {
      expect(qrWindow(b1, b1.start.subtract(const Duration(minutes: 5)), 10),
          QrWindow.active);
    });
  });

  group('Charter (R-13)', () {
    test('the external client must sign before sending', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(worldProvider.notifier);
      SubmitProblem? check() => n.check(
            requesterId: 'omar',
            requesterType: RequesterType.external,
            studioId: 'podcast',
            start: DateTime(2026, 11, 12, 15),
            end: DateTime(2026, 11, 12, 17),
          );
      expect(check(), SubmitProblem.charterMissing);
      n.signCharter('omar');
      expect(check(), isNull);
      expect(c.read(worldProvider).charterSignedAt['omar'], DemoWorld.now);
      final b = n.submit(
        requesterId: 'omar',
        requesterType: RequesterType.external,
        studioId: 'podcast',
        start: DateTime(2026, 11, 12, 15),
        end: DateTime(2026, 11, 12, 17),
        activity: Activity.recording,
      );
      expect(b.reference, 'ES-2026-0147');
      expect(b.status, BookingStatus.pendingEntity);
    });
  });

  testWidgets('Studios tab lists studios by zone', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await t.binding.setSurfaceSize(const Size(400, 2400));
    await t.pumpWidget(const ProviderScope(child: EuromedStudiosApp()));
    await t.pumpAndSettle();
    await t.tap(find.text('Studios').last);
    await t.pumpAndSettle();
    expect(find.text('Studios'), findsNWidgets(2)); // title + tab
    expect(find.text('PRODUCTION'), findsOneWidget);
    expect(find.text('Studio Podcast'), findsOneWidget);
  });

  testWidgets('Booking starts on a month calendar, then shows the slots',
      (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await t.binding.setSurfaceSize(const Size(400, 1400));
    await t.pumpWidget(const ProviderScope(child: EuromedStudiosApp()));
    await t.pumpAndSettle();
    appRouter.push('/book/podcast');
    await t.pumpAndSettle();

    expect(find.text('Choisissez une date'), findsOneWidget);
    expect(find.text('ÉTAPE 1/4'), findsOneWidget);
    expect(find.textContaining('Date choisie : '), findsOneWidget);
    final go = find.textContaining('Voir les créneaux du ');
    expect(go, findsOneWidget);

    await t.tap(go);
    await t.pumpAndSettle();
    expect(find.text('Choisissez un créneau'), findsOneWidget);
    expect(find.text('ÉTAPE 2/4'), findsOneWidget);
    expect(find.text('Changer'), findsOneWidget);

    await t.tap(find.text('Changer'));
    await t.pumpAndSettle();
    expect(find.text('Choisissez une date'), findsOneWidget);
    appRouter.go('/home');
    await t.pumpAndSettle();
  });
}
