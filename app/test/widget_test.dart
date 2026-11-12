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
    await t.binding.setSurfaceSize(const Size(400, 1600));
    await t.pumpWidget(const ProviderScope(child: EuromedStudiosApp()));
    await t.pumpAndSettle();

    expect(find.text('BONJOUR, YASMINE'), findsOneWidget);
    // Next session: Plateau TV tomorrow 14:00–15:00 (booking b1).
    expect(find.text('Plateau TV'), findsWidgets);
    expect(find.textContaining('Demain · 14:00–15:00'), findsOneWidget);
    // Quota: 1 h used out of 2 h.
    expect(find.text('1 h / 2 h'), findsOneWidget);
    // Bottom tabs for a student.
    expect(find.text('Réservations'), findsOneWidget);
    expect(find.text('Projets'), findsOneWidget);
  });
}
