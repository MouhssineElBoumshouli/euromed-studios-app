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
import '../../data/demo_world.dart';
import '../../data/selectors.dart';
import '../../domain/bookings.dart';

/// E1 · My bookings, in four tabs.
class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final me = ref.watch(currentPersonProvider);
    final all = bookingsOf(w, me.id);
    final upcoming = [
      for (final b in all)
        if (b.status == BookingStatus.approved && b.end.isAfter(w.now)) b,
    ];
    final pending = [
      for (final b in all)
        if (b.status.isPending) b,
    ];
    final past = [
      for (final b in all.reversed)
        if (b.status == BookingStatus.completed ||
            (b.status == BookingStatus.approved && !b.end.isAfter(w.now)))
          b,
    ];
    final closed = [
      for (final b in all.reversed)
        if (b.status == BookingStatus.refused ||
            b.status == BookingStatus.cancelled)
          b,
    ];

    Widget list(List<Booking> items, String emptyTitle, String emptyText) {
      if (items.isEmpty) {
        return ListView(
          children: [
            EmptyState(
              icon: Icons.event_available_outlined,
              title: emptyTitle,
              message: emptyText,
              action: EsButton(
                'Réserver un studio',
                expand: false,
                onPressed: () => context.go('/studios'),
              ),
            ),
          ],
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: EsSpace.s3),
        itemBuilder: (_, i) => BookingCard(booking: items[i], now: w.now),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'RÉSERVATIONS',
              style: EsText.displayL.copyWith(color: c.textPrimary),
            ),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: EsText.labelM,
            unselectedLabelStyle: EsText.labelM,
            labelColor: c.actionPrimary,
            unselectedLabelColor: c.textSecondary,
            indicatorColor: c.actionPrimary,
            tabs: [
              Tab(text: 'À venir (${upcoming.length})'),
              Tab(text: 'En attente (${pending.length})'),
              Tab(text: 'Passées (${past.length})'),
              Tab(text: 'Refusées / annulées (${closed.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                list(
                  upcoming,
                  'Aucune séance validée à venir',
                  'Vos séances validées apparaîtront ici, avec leur QR code.',
                ),
                list(
                  pending,
                  'Aucune demande en attente',
                  'Les demandes envoyées attendent ici leur validation.',
                ),
                list(
                  past,
                  'Pas encore de séance passée',
                  'L’historique de vos séances apparaîtra ici.',
                ),
                list(
                  closed,
                  'Rien à signaler',
                  'Les demandes refusées ou annulées apparaîtront ici, avec '
                      'leur motif.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, required this.now});
  final Booking booking;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final s = studioById(booking.studioId);
    final room = DemoWorld.rooms.firstWhere((r) => r.id == s.roomId);
    final canShowQr =
        booking.status == BookingStatus.approved && booking.end.isAfter(now);
    return EsCard(
      onTap: () => context.push('/bookings/${booking.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  s.name,
                  style: EsText.titleM.copyWith(color: c.textPrimary),
                ),
              ),
              StatusChip(booking.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${Fmt.relativeDay(booking.start, now)} · '
            '${Fmt.range(booking.start, booking.end)}',
            style: EsText.bodyM.copyWith(color: c.textPrimary),
          ),
          Text(
            '${room.name} · ${booking.activity.label} · ${booking.reference}',
            style: EsText.bodyS.copyWith(color: c.textSecondary),
          ),
          if (booking.status == BookingStatus.refused &&
              booking.refusalReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Motif : ${booking.refusalReason}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: EsText.bodyS.copyWith(color: c.dangerText),
            ),
          ],
          if (canShowQr) ...[
            const SizedBox(height: 12),
            EsButton(
              'Afficher le QR code',
              icon: Icons.qr_code_2_rounded,
              style: EsButtonStyle.secondary,
              size: EsButtonSize.medium,
              onPressed: () => context.push('/qr/${booking.id}'),
            ),
          ],
        ],
      ),
    );
  }
}
