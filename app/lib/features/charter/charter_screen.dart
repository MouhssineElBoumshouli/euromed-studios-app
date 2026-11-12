import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../data/app_state.dart';
import '../../data/booking_service.dart';

/// A6 · House rules, signed before any request (R-13).
/// Returns `true` to the caller once signed.
class CharterScreen extends ConsumerStatefulWidget {
  const CharterScreen({super.key});

  @override
  ConsumerState<CharterScreen> createState() => _CharterState();
}

class _CharterState extends ConsumerState<CharterScreen> {
  bool accepted = false;
  bool saving = false;

  static const _rules = [
    (
      'Ponctualité',
      'Libérez le studio à l’heure exacte de fin du créneau, rangé et '
          'éteint.',
    ),
    (
      'Matériel',
      'Vous êtes responsable du matériel emprunté jusqu’à son retour au '
          'régisseur.',
    ),
    (
      'Signalement',
      'Signalez tout équipement ou meuble défectueux dans le formulaire '
          'de fin de séance.',
    ),
    (
      'Accès',
      'Votre QR code est personnel. Il n’est valable que pendant votre '
          'créneau.',
    ),
    (
      'Annulation',
      'Annulez dès que possible si vous ne venez pas, pour libérer le '
          'créneau.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final me = ref.watch(currentPersonProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Règlement intérieur')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Avant votre première demande, lisez et signez le règlement des '
            'studios. Vous le signerez à nouveau s’il change.',
            style: EsText.bodyM.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: EsSpace.s4),
          EsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (t, d) in _rules) ...[
                  Text(t, style: EsText.titleS.copyWith(color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Text(d, style: EsText.bodyM.copyWith(color: c.textSecondary)),
                  const SizedBox(height: EsSpace.s3),
                ],
                Text(
                  'Version ${w.policy.charterVersion} · texte officiel à '
                  'fournir par l’UEMF',
                  style: EsText.bodyS.copyWith(color: c.textGold),
                ),
              ],
            ),
          ),
          const SizedBox(height: EsSpace.s3),
          CheckboxListTile(
            value: accepted,
            onChanged: (v) => setState(() => accepted = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'J’ai lu et j’accepte le règlement intérieur',
              style: EsText.labelM.copyWith(color: c.textPrimary),
            ),
            subtitle: Text(
              'Signé au nom de ${me.fullName}, avec la date et l’heure.',
              style: EsText.bodyS.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: EsButton(
            'Signer et continuer',
            loading: saving,
            onPressed: accepted
                ? () async {
                    setState(() => saving = true);
                    await ref.read(bookingServiceProvider).signCharter(me.id);
                    if (context.mounted) context.pop(true);
                  }
                : null,
          ),
        ),
      ),
    );
  }
}
