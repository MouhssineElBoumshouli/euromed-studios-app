import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/demo_mode.dart';
import 'core/settings/app_prefs.dart';
import 'data/app_state.dart';
import 'data/backend.dart';
import 'data/demo_world.dart';
import 'data/live_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status and navigation bars on every Android version;
  // screens leave room for them.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR');
  await initializeDateFormatting('en_GB');
  // Light/dark look and language chosen on this device.
  await AppPrefs.load();

  // Demo only: "?as=tazi" opens the app as that fictional person, so a
  // laptop can start as the studio manager and a phone as a student.
  final as = kDemoMode ? Uri.base.queryParameters['as'] : null;
  final known = as != null && DemoWorld.people.any((p) => p.id == as);

  final container = ProviderContainer(
    overrides: [
      if (known && !kLiveBuild)
        currentPersonIdProvider.overrideWith((ref) => as),
    ],
  );

  if (kLiveBuild) {
    await Supabase.initialize(
      url: kSupabaseUrl,
      publishableKey: kSupabasePublishableKey,
    );
    liveSync = LiveSync(container);
    await liveSync!.start();
    final current = Supabase.instance.client.auth.currentUser?.email;
    if (known && current != demoEmail(as)) {
      if (current != null) await liveSync!.signOut();
      // Fire and forget: the sign-in screen shows progress meanwhile.
      liveSync!.signIn(as).ignore();
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const EuromedStudiosApp(),
    ),
  );
}
