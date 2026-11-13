import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../data/app_state.dart';
import '../bookings/booking_widgets.dart';

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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: c.successBg,
                child: Icon(Icons.check_rounded, size: 48, color: c.successText),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'DEMANDE ENVOYÉE',
              textAlign: TextAlign.center,
              style: EsText.displayL.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              '${s.name} · ${Fmt.longDay(b.start)} · ${Fmt.range(b.start, b.end)}\n'
              'Référence ${b.reference}',
              textAlign: TextAlign.center,
              style: EsText.bodyM.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Le créneau est bloqué « En attente ». Vous recevrez une '
              'notification à chaque étape.',
              textAlign: TextAlign.center,
              style: EsText.bodyM.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 24),
            EsCard(child: BookingTimeline(booking: b)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EsButton(
                'Voir ma demande',
                onPressed: () {
                  context.go('/bookings');
                  context.push('/bookings/${b.id}');
                },
              ),
              const SizedBox(height: 8),
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
