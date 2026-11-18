import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../data/app_state.dart';
import '../bookings/booking_widgets.dart';
import '../../core/l10n/text.dart';

/// D4 · Request sent.
class SentScreen extends ConsumerWidget {
  const SentScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final b = w.bookings.firstWhere((x) => x.id == bookingId);
    final s = studioById(b.studioId);
    return Scaffold(
      body: BlobBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              EsSpace.page,
              EsSpace.s10,
              EsSpace.page,
              EsSpace.s6,
            ),
            children: [
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.elasticOut,
                  builder: (context, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: c.successBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.bgSurface, width: 6),
                      boxShadow: esShadow(c, strength: 2),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 52,
                      color: c.successText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: EsSpace.s5),
              Text(
                'Demande envoyée !',
                textAlign: TextAlign.center,
                style: EsText.displayXL.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: EsSpace.s2),
              Text(
                'Le créneau est bloqué « En attente ». Vous serez prévenu·e '
                'à chaque étape.',
                textAlign: TextAlign.center,
                style: EsText.bodyL.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: EsSpace.s6),
              EsCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    PhotoThumb(s.photo, size: 60),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: EsText.titleM.copyWith(color: c.textPrimary),
                          ),
                          Text(
                            '${Fmt.shortDay(b.start)} · '
                            '${Fmt.range(b.start, b.end)}',
                            style:
                                EsText.bodyS.copyWith(color: c.textSecondary),
                          ),
                          Text(
                            'Réf. ${b.reference}',
                            style: EsText.bodyS.copyWith(color: c.textDisabled),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: EsSpace.s3),
              EsCard(child: BookingTimeline(booking: b)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            EsSpace.page,
            8,
            EsSpace.page,
            12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EsButton(
                'Voir ma demande',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () {
                  context.go('/bookings');
                  context.push('/bookings/${b.id}');
                },
              ),
              const SizedBox(height: 4),
              EsButton(
                'Retour à l’accueil',
                style: EsButtonStyle.ghost,
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
