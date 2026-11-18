import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../settings/app_prefs.dart';
import '../theme/es_colors.dart';
import '../theme/es_text.dart';
import 'layout.dart';

/// Look (system, light, dark) and language, saved on this device.
class PreferencesCard extends StatelessWidget {
  const PreferencesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return ListenableBuilder(
      listenable: Listenable.merge([AppPrefs.theme, AppPrefs.language]),
      builder: (context, _) => EsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Apparence',
                style: EsText.titleS.copyWith(color: c.textPrimary)),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('Système'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Clair'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Sombre'),
                ),
              ],
              selected: {AppPrefs.theme.value},
              onSelectionChanged: (s) => AppPrefs.setTheme(s.first),
            ),
            const SizedBox(height: EsSpace.s4),
            Text('Langue', style: EsText.titleS.copyWith(color: c.textPrimary)),
            const SizedBox(height: 8),
            const LanguageSwitch(),
            const SizedBox(height: 6),
            Text(
              'Enregistré sur cet appareil.',
              style: EsText.bodyS.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Français / English. Language names are never translated.
class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppPrefs.language,
      builder: (context, code, _) => SegmentedButton<String>(
        showSelectedIcon: !compact,
        style: compact
            ? const ButtonStyle(visualDensity: VisualDensity.compact)
            : null,
        segments: const [
          ButtonSegment(value: 'fr', label: Text('Français')),
          ButtonSegment(value: 'en', label: Text('English')),
        ],
        selected: {code},
        onSelectionChanged: (s) => AppPrefs.setLanguage(s.first),
      ),
    );
  }
}
