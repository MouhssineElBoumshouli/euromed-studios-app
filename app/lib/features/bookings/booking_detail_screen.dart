import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/app_state.dart';
import '../../data/booking_service.dart';
import '../../data/demo_world.dart';
import '../../domain/bookings.dart';
import '../../domain/rules/approval.dart';
import '../../domain/rules/quota.dart';
import 'booking_widgets.dart';

/// E2 · One booking: status journey, equipment, actions.
class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final me = ref.watch(currentPersonProvider);
    final b = w.bookings.where((x) => x.id == bookingId).firstOrNull;
    if (b == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Demande introuvable',
          message: 'Elle a peut-être été supprimée.',
        ),
      );
    }
    final s = studioById(b.studioId);
    final room = DemoWorld.rooms.firstWhere((r) => r.id == s.roomId);
    final club = b.clubId == null
        ? null
        : DemoWorld.clubs.firstWhere((x) => x.id == b.clubId);
    final showQr = b.status == BookingStatus.approved && b.end.isAfter(w.now);
    final cancellable = canCancel(me, b, w.now);

    return Scaffold(
      appBar: AppBar(title: Text('Demande ${b.reference}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          EsCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 6,
                  child: Image.asset(s.photo, fit: BoxFit.cover),
                ),
                Padding(
                  padding: const EdgeInsets.all(EsSpace.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.name,
                              style: EsText.titleL.copyWith(color: c.textPrimary),
                            ),
                          ),
                          StatusChip(b.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${Fmt.longDay(b.start)} · ${Fmt.range(b.start, b.end)} '
                        '(${formatMinutes(b.duration.inMinutes)})',
                        style: EsText.bodyM.copyWith(color: c.textPrimary),
                      ),
                      Text(
                        [
                          room.name,
                          b.activity.label,
                          if (club != null) 'Au nom de ${club.name}',
                        ].join(' · '),
                        style: EsText.bodyS.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (b.status == BookingStatus.refused && b.refusalReason != null) ...[
            const SizedBox(height: EsSpace.s3),
            InfoBanner(
              tone: BannerTone.danger,
              text: 'Motif du refus : ${b.refusalReason}',
            ),
          ],
          if (showQr) ...[
            const SizedBox(height: EsSpace.s3),
            EsButton(
              'Afficher mon QR code',
              icon: Icons.qr_code_2_rounded,
              onPressed: () => context.push('/qr/${b.id}'),
            ),
          ],
          const SizedBox(height: EsSpace.s4),
          const SectionTitle('Suivi'),
          EsCard(child: BookingTimeline(booking: b)),
          if (b.equipment.isNotEmpty) ...[
            const SizedBox(height: EsSpace.s4),
            const SectionTitle('Matériel demandé'),
            EsCard(
              child: Column(
                children: [
                  for (final e in b.equipment)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${equipmentById(e.itemId).name} × ${e.quantity}',
                                  style: EsText.titleS.copyWith(color: c.textPrimary),
                                ),
                                Text(
                                  e.required ? 'Indispensable' : 'Souhaité',
                                  style: EsText.bodyS.copyWith(
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _Outcome(e.outcome),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (b.note != null) ...[
            const SizedBox(height: EsSpace.s4),
            const SectionTitle('Votre note'),
            Text(b.note!, style: EsText.bodyM.copyWith(color: c.textSecondary)),
          ],
          if (b.technicianId != null) ...[
            const SizedBox(height: EsSpace.s4),
            InfoBanner(
              icon: Icons.engineering_outlined,
              text: 'Technicien affecté : ${personById(b.technicianId!).fullName}',
            ),
          ],
          const SizedBox(height: EsSpace.s5),
          if (cancellable)
            EsButton(
              b.status == BookingStatus.approved
                  ? 'Annuler la séance'
                  : 'Annuler la demande',
              style: EsButtonStyle.destructive,
              onPressed: () => _confirmCancel(context, ref, b.id),
            ),
          if (b.status == BookingStatus.refused ||
              b.status == BookingStatus.cancelled)
            EsButton(
              'Faire une nouvelle demande',
              style: EsButtonStyle.secondary,
              onPressed: () => context.push('/book/${s.id}'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final reason = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final c = ctx.es;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Annuler cette demande ?',
                style: EsText.titleL.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Le créneau sera libéré pour les autres. Cette action ne peut '
                'pas être annulée.',
                style: EsText.bodyM.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reason,
                decoration: const InputDecoration(
                  hintText: 'Motif (facultatif)',
                ),
              ),
              const SizedBox(height: 16),
              EsButton(
                'Oui, annuler',
                style: EsButtonStyle.destructive,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 8),
              EsButton(
                'Garder ma demande',
                style: EsButtonStyle.ghost,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true) return;
    await ref.read(bookingServiceProvider).cancel(
          id,
          by: ref.read(currentPersonProvider),
          reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande annulée. Le créneau est libéré.')),
      );
    }
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome(this.o);
  final EquipmentOutcome o;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (String t, Color bg, Color fg) = switch (o) {
      EquipmentOutcome.pending => ('À confirmer', c.pendingBg, c.pendingText),
      EquipmentOutcome.confirmed => ('Confirmé', c.successBg, c.successText),
      EquipmentOutcome.substituted => ('Remplacé', c.reviewBg, c.reviewText),
      EquipmentOutcome.unavailable => ('Indisponible', c.dangerBg, c.dangerText),
    };
    return Tag(label: t, background: bg, foreground: fg);
  }
}
