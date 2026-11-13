import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'app/demo_mode.dart';
import 'data/app_state.dart';
import 'data/demo_world.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR');
  // Demo only: "?as=tazi" opens the app as that fictional person, so a
  // laptop can start as the studio manager and a phone as a student.
  final as = kDemoMode ? Uri.base.queryParameters['as'] : null;
  final known = as != null && DemoWorld.people.any((p) => p.id == as);
  runApp(
    ProviderScope(
      overrides: [
        if (known) currentPersonIdProvider.overrideWith((ref) => as),
      ],
      child: const EuromedStudiosApp(),
    ),
  );
}
