/// Demo mode shows the persona switcher and fictional data.
///
/// On by default while there is no real server. A real build turns it off:
/// `flutter build --dart-define=DEMO=false`. Then the switcher disappears
/// and roles come only from the UEMF account.
const bool kDemoMode = bool.fromEnvironment('DEMO', defaultValue: true);
