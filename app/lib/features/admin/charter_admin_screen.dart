import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../data/admin_service.dart';
import '../../data/app_state.dart';
import '../../data/directory.dart';
import '../../domain/rules/settings_rules.dart';
import 'admin_page.dart';

/// I7 · Charter version. Publishing a new version asks everyone to sign
/// again before their next booking (R-13).
class CharterAdminScreen extends ConsumerStatefulWidget {
  const CharterAdminScreen({super.key});

  @override
  ConsumerState<CharterAdminScreen> createState() => _CharterAdminState();
}

class _CharterAdminState extends ConsumerState<CharterAdminScreen> {
  final version = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    version.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    version.dispose();
    super.dispose();
  }

  Future<void> _publish(String current) async {
    final v = version.text.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Publier la version $v ?'),
        content: const Text(
          'Toutes les personnes devront lire et signer la nouvelle charte '
          'avant leur prochaine réservation. Les séances déjà validées ne '
          'changent pas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publier'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminServiceProvider)
          .publishCharter(ref.read(currentPersonProvider), v);
      m.showSnackBar(SnackBar(content: Text('Charte $v publiée.')));
      version.clear();
    } on AdminProblem catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final people = [
      for (final p in ref.watch(directoryProvider))
        if (p.active && p.roles.any((r) => r.isRequester)) p,
    ];
    final current = w.policy.charterVersion;
    final signed =
        people.where((p) => w.signedCharterVersion[p.id] == current).length;
    final problem = version.text.trim().isEmpty
        ? null
        : charterVersionProblem(version.text, current);

    return AdminPage(
      title: 'Charte d’utilisation',
      subtitle: 'La charte que chaque demandeur signe avant de réserver.',
      children: [
        EsCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconTile(Icons.gavel_rounded, size: 42),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Version en vigueur : $current',
                          style: EsText.titleM.copyWith(color: c.textPrimary),
                        ),
                        Text(
                          '$signed sur ${people.length} demandeurs l’ont '
                          'signée',
                          style:
                              EsText.bodyS.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: people.isEmpty ? 0 : signed / people.length,
                  minHeight: 8,
                  backgroundColor: c.bgSubtle,
                  color: c.successText,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push('/charter'),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Voir la charte'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: EsSpace.s5),
        const Overline('Publier une nouvelle version'),
        const SizedBox(height: 8),
        const InfoBanner(
          icon: Icons.description_outlined,
          text: 'Le texte officiel de la charte est fourni par l’UEMF '
              '(question Q11). Publiez une nouvelle version quand le texte '
              'change : chacun la signera à nouveau.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: version,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Nouveau numéro de version',
            hintText: 'Ex. : 2.0',
            errorText: problem == null ? null : adminProblemText(problem),
          ),
        ),
        const SizedBox(height: 12),
        EsButton(
          'Publier la nouvelle version',
          icon: Icons.publish_rounded,
          loading: busy,
          onPressed: version.text.trim().isEmpty || problem != null || busy
              ? null
              : () => _publish(current),
        ),
      ],
    );
  }
}
