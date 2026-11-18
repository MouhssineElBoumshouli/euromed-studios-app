import 'package:flutter/material.dart' hide Text;
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
import '../../core/l10n/text.dart';

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
      body: PhotoPage(
        photo: s.photo,
        onBack: () => context.pop(),
        sheet: Container(
          padding: const EdgeInsets.fromLTRB(
            EsSpace.page,
            EsSpace.s5,
            EsSpace.page,
            EsSpace.s8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StatusChip(b.status),
                  const Spacer(),
                  Text(
                    b.reference,
                    style: EsText.labelS.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: EsSpace.s3),
              Text(
                s.name,
                style: EsText.displayXL.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  room.name,
                  b.activity.label,
                  if (club != null) 'Au nom de ${club.name}',
                ].join(' · '),
                style: EsText.bodyM.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: EsSpace.s4),
              EsCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _Fact('Date', Fmt.shortDay(b.start)),
                    _Divider(),
                    _Fact('Horaire', Fmt.range(b.start, b.end)),
                    _Divider(),
                    _Fact('Durée', formatMinutes(b.duration.inMinutes)),
                  ],
                ),
              ),
              if (b.status == BookingStatus.refused &&
                  b.refusalReason != null) ...[
                const SizedBox(height: EsSpace.s3),
                InfoBanner(
                  tone: BannerTone.danger,
                  title: 'Motif du refus',
                  text: b.refusalReason!,
                ),
              ],
              if (showQr) ...[
                const SizedBox(height: EsSpace.s4),
                EsButton(
                  'Afficher mon QR code',
                  icon: Icons.qr_code_2_rounded,
                  onPressed: () => context.push('/qr/${b.id}'),
                ),
              ],
              const SizedBox(height: EsSpace.s4),
              const SectionTitle('Suivi de la demande'),
              const SizedBox(height: EsSpace.s2),
              EsCard(child: BookingTimeline(booking: b)),
              if (b.equipment.isNotEmpty) ...[
                const SizedBox(height: EsSpace.s4),
                const SectionTitle('Matériel demandé'),
                const SizedBox(height: EsSpace.s2),
                EsCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < b.equipment.length; i++) ...[
                        if (i > 0) Divider(height: 20, color: c.border),
                        Row(
                          children: [
                            const IconTile(
                              Icons.inventory_2_outlined,
                              size: 38,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${equipmentById(b.equipment[i].itemId).name}'
                                    ' × ${b.equipment[i].quantity}',
                                    style: EsText.titleS
                                        .copyWith(color: c.textPrimary),
                                  ),
                                  Text(
                                    b.equipment[i].required
                                        ? 'Indispensable'
                                        : 'Souhaité',
                                    style: EsText.bodyS.copyWith(
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _Outcome(b.equipment[i].outcome),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (b.note != null) ...[
                const SizedBox(height: EsSpace.s4),
                const SectionTitle('Votre note'),
                const SizedBox(height: EsSpace.s2),
                EsCard(
                  child: Text(
                    b.note!,
                    style: EsText.bodyM.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
              if (b.technicianId != null) ...[
                const SizedBox(height: EsSpace.s4),
                InfoBanner(
                  icon: Icons.engineering_outlined,
                  title: 'Technicien affecté',
                  text: personById(b.technicianId!).fullName,
                ),
              ],
              const SizedBox(height: EsSpace.s6),
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
        ),
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
            8,
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
                decoration: InputDecoration(
                  hintText: tr('Motif (facultatif)'),
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
        const SnackBar(
            content: Text('Demande annulée. Le créneau est libéré.')),
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
      EquipmentOutcome.unavailable => (
          'Indisponible',
          c.dangerBg,
          c.dangerText
        ),
    };
    return Tag(label: t, background: bg, foreground: fg);
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Expanded(
      child: Column(
        children: [
          Text(label, style: EsText.bodyS.copyWith(color: c.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: EsText.titleS.copyWith(color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: context.es.border);
}
