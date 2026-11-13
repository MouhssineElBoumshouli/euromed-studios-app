import 'package:euromed_studios/app/app.dart';
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

  testWidgets('the app opens on the student home with real demo data',
      (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await t.binding.setSurfaceSize(const Size(400, 1600));
    await t.pumpWidget(const ProviderScope(child: EuromedStudiosApp()));
    await t.pumpAndSettle();

    expect(find.text('Bonjour Yasmine,'), findsOneWidget);
    // Next session: Plateau TV tomorrow 14:00–15:00 (booking b1).
    expect(find.text('Plateau TV'), findsWidgets);
    expect(find.text('Demain'), findsOneWidget);
    expect(find.textContaining('14:00–15:00 · Area 2'), findsOneWidget);
    // Quota: 1 h used out of 2 h.
    expect(find.textContaining('1 h utilisées sur 2 h'), findsOneWidget);
    // Bottom tabs for a student.
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Projets'), findsNWidgets(2)); // quick action + tab
  });
}
