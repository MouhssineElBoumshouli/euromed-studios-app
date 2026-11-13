import 'package:flutter/material.dart';

import '../core/theme/es_colors.dart';
import '../core/theme/es_text.dart';
import '../core/widgets/layout.dart';
import '../data/backend.dart';
import '../data/demo_world.dart';
import '../data/live_sync.dart';
import '../domain/people.dart';

/// A1 · Sign-in for the live demo.
///
/// Each fictional account is one tap. In the official version this screen
/// becomes "Se connecter avec mon compte UEMF".
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? signingIn;
  String? error;

  Future<void> _pick(String slug) async {
    setState(() {
      signingIn = slug;
      error = null;
    });
    try {
      await liveSync!.signIn(slug);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        signingIn = null;
        error = 'Connexion impossible. Vérifiez votre connexion internet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final loading = liveStatus.value == LiveStatus.loading;
    return Scaffold(
      body: BlobBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  EsSpace.page,
                  EsSpace.s8,
                  EsSpace.page,
                  EsSpace.s8,
                ),
                children: [
                  Text(
                    'UEMF',
                    style: EsText.displayM.copyWith(
                      color: c.actionPrimary,
                      fontSize: 28,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'EUROMED STUDIOS',
                    style: EsText.overline.copyWith(
                      color: c.textSecondary,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: EsSpace.s8),
                  Text.rich(
                    TextSpan(
                      text: 'Bienvenue ',
                      children: [
                        TextSpan(
                          text: 'en studio.',
                          style: TextStyle(color: c.accent),
                        ),
                      ],
                    ),
                    style: EsText.hero.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: EsSpace.s2),
                  Text(
                    'Démo en direct : choisissez un compte. Ce que vous faites '
                    'ici apparaît aussitôt sur les autres téléphones et '
                    'ordinateurs.',
                    style: EsText.bodyL.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: EsSpace.s5),
                  if (error != null) ...[
                    InfoBanner(tone: BannerTone.danger, text: error!),
                    const SizedBox(height: EsSpace.s3),
                  ],
                  DemoAccountList(
                    busySlug: signingIn ?? (loading ? '' : null),
                    onPick: _pick,
                  ),
                  const SizedBox(height: EsSpace.s4),
                  Text(
                    'Toutes les personnes sont fictives. Dans la version '
                    'officielle, chacun se connecte avec son compte UEMF.',
                    textAlign: TextAlign.center,
                    style: EsText.bodyS.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The fictional demo accounts, grouped by what they do.
class DemoAccountList extends StatelessWidget {
  const DemoAccountList({
    super.key,
    required this.onPick,
    this.busySlug,
    this.currentSlug,
  });
  final ValueChanged<String> onPick;

  /// The account being opened ('' while restoring a session).
  final String? busySlug;
  final String? currentSlug;

  static const groups = [
    ('Demandeurs', ['yasmine', 'adam', 'rami', 'nadia', 'omar']),
    ('Validateurs niveau 1', ['amrani', 'benjelloun', 'lahlou', 'fassi']),
    ('Équipe des studios', ['tazi', 'haddad', 'idrissi']),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, slugs) in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Overline(title),
          ),
          for (final slug in slugs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AccountTile(
                person: DemoWorld.people.firstWhere((p) => p.id == slug),
                busy: busySlug == slug,
                current: currentSlug == slug,
                enabled: busySlug == null,
                onTap: () => onPick(slug),
              ),
            ),
        ],
        if (busySlug == '')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: CircularProgressIndicator(color: c.actionPrimary),
            ),
          ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.person,
    required this.busy,
    required this.current,
    required this.enabled,
    required this.onTap,
  });
  final Person person;
  final bool busy;
  final bool current;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return EsCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: enabled ? onTap : null,
      semanticLabel: 'Se connecter en tant que ${person.fullName}',
      child: Row(
        children: [
          Avatar(person.initials, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.fullName,
                  style: EsText.titleS.copyWith(color: c.textPrimary),
                ),
                Text(
                  person.title ?? person.roles.first.label,
                  style: EsText.bodyS.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          if (busy)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.actionPrimary,
              ),
            )
          else if (current)
            Icon(Icons.check_circle_rounded, color: c.successFill)
          else
            Icon(Icons.arrow_forward_rounded, color: c.textDisabled),
        ],
      ),
    );
  }
}
