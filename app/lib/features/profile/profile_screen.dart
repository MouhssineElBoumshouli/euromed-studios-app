import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/demo_switcher.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/app_state.dart';
import '../../data/selectors.dart';
import '../../domain/rules/quota.dart';

/// J1 · Profile.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final me = ref.watch(currentPersonProvider);
    final w = ref.watch(worldProvider);
    final est = establishmentById(me.establishmentId);
    final signed = w.signedCharterVersion[me.id];
    final isRequester = me.roles.any((r) => r.isRequester);
    final quota = isRequester ? weeklyQuota(w, me) : null;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        BrandHeader(
          title: me.fullName,
          overline: 'Mon profil',
          subtitle: me.title,
          trailing: Avatar(me.initials, size: 56, onBrand: true),
        ),
        Padding(
          padding: const EdgeInsets.all(EsSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('Mes rôles'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in me.roles)
                    Tag(
                      label: r.label,
                      background: c.reviewBg,
                      foreground: c.reviewText,
                    ),
                ],
              ),
              const SizedBox(height: EsSpace.s4),
              EsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Line('Établissement', est?.name ?? '—'),
                    if (quota != null && !quota.unlimited)
                      _Line(
                        'Quota hebdomadaire',
                        '${formatMinutes(quota.limitMinutes!)} · '
                            '${formatMinutes(quota.usedMinutes)} déjà réservé cette semaine',
                      ),
                    if (quota != null && quota.unlimited)
                      const _Line('Quota hebdomadaire', 'Sans limite'),
                    _Line(
                      'Règlement intérieur',
                      signed == null
                          ? 'Pas encore signé'
                          : 'Signé · version $signed',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: EsSpace.s5),
              EsButton(
                'Voir l’application avec un autre rôle',
                icon: Icons.swap_horiz_rounded,
                style: EsButtonStyle.secondary,
                onPressed: () => showDemoSwitcher(context, ref),
              ),
              const SizedBox(height: EsSpace.s3),
              Text(
                'Mode démo. Dans la version finale, vos rôles viennent de '
                'votre compte UEMF et ne se changent pas ici.',
                textAlign: TextAlign.center,
                style: EsText.bodyS.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: EsText.labelS.copyWith(color: c.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: EsText.bodyM.copyWith(color: c.textPrimary)),
        ],
      ),
    );
  }
}
