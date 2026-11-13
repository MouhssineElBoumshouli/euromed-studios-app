/// Where the app's shared data lives (decision 0004: Supabase).
///
/// The URL and publishable key are public by design: they only let the app
/// talk to the server. What each person may see or change is decided on the
/// server, by row-level security and the booking functions
/// (supabase/migrations).
library;

import 'package:flutter/foundation.dart';

const kSupabaseUrl = 'https://otywhgcmayylalzldjvw.supabase.co';
const kSupabasePublishableKey =
    'sb_publishable_pkYJ6uY-C_KaT_0u5eZRIA_giFhtl2_';

/// Build flag: `--dart-define=LIVE=false` runs fully offline on the
/// in-memory demo world (used by tests and as a safety net).
const kLiveBuild = bool.fromEnvironment('LIVE', defaultValue: true);

/// Demo accounts share one password so the sign-in screen can offer
/// one-tap accounts. These are fictional people with fictional data; real
/// UEMF accounts will sign in through the university instead.
const kDemoPassword = 'Studio-Demo-2026!';

String demoEmail(String slug) => '$slug@demo.euromed-studios.test';

enum LiveStatus { off, signedOut, loading, ready }

/// Where the live connection stands. The router listens to it.
final liveStatus = ValueNotifier<LiveStatus>(LiveStatus.off);

/// True once main() has connected to the server.
bool get isLive => liveStatus.value != LiveStatus.off;
