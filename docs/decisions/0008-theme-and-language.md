# 0008 · Dark theme and English language

Status: requested by Mouhssine (2026-11-18), built in #19.

## Decision
- **Appearance:** Système (follows the device), Clair or Sombre, chosen in
  Profil → Préférences. Saved on the device with `shared_preferences`.
  That package was already used inside `supabase_flutter`; it is now listed
  directly in `pubspec.yaml`.
- **Language:** Français (default) or English, chosen in Profil and on
  the sign-in screen. Saved on the device.
- **How English works:**
  - French stays written directly in the code.
  - The app's own `Text` widget (`lib/core/l10n/text.dart`) shows each text
    in the chosen language when it is drawn on screen.
  - Translations live in `tools/l10n/en.json`, which generates
    `lib/core/l10n/en_catalog.dart`.
  - Texts with values in them use `{0}`, `{1}` (e.g. "Bonjour {0}," →
    "Hello {0},").
  - Strings that Material draws itself (field labels, tooltips, screen
    reader labels) go through `tr()`.
- **Guard:** CI fails when a French text has no English line. Run
  `python3 tools/l10n/build_catalog.py` to see what is missing.

## Why this approach
The usual Flutter approach (ARB files plus generated getters) would mean
rewriting all ~1,100 texts across 60 files into keys. That is a large and
risky change before the presentation. The approach chosen here keeps every
screen's code the same, and the check makes sure no text is forgotten.

## Limits
- Texts written by the server, such as the activity log summaries, are
  partly translated: only known pieces are.
- What people type (project titles, messages) is never translated.
- Anything sent to UEMF stays in French.
- If the app later needs more languages (for example Arabic, which reads
  right to left), moving to ARB files is the natural next step. The
  catalogue can be converted automatically.
