import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/settings/app_prefs.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class EuromedStudiosApp extends StatelessWidget {
  const EuromedStudiosApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds the whole app when the look or the language changes.
    return ListenableBuilder(
      listenable: Listenable.merge([AppPrefs.theme, AppPrefs.language]),
      builder: (context, _) {
        final en = AppPrefs.language.value == 'en';
        return MaterialApp.router(
          title: 'Euromed Studios',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: AppPrefs.theme.value,
          locale: en ? const Locale('en', 'GB') : const Locale('fr', 'FR'),
          supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'GB')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: appRouter,
          builder: (context, child) {
            // Edge to edge: the app draws behind the status and navigation
            // bars (screens leave room for them), with icons that stay
            // readable in light and dark.
            final dark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: (dark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark)
                  .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}
