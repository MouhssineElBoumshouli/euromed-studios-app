import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell.dart';
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
import '../../core/l10n/text.dart';

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
          padding: EdgeInsets.only(bottom: tabBarSpace(context)),
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
        padding: EdgeInsets.fromLTRB(
          EsSpace.page,
          EsSpace.s4,
          EsSpace.page,
          tabBarSpace(context),
        ),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: EsSpace.s3),
        itemBuilder: (_, i) => FadeInUp(
          index: i,
          child: BookingCard(booking: items[i], now: w.now),
        ),
      );
    }

    Tab tab(String label, int n) => Tab(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (n > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: c.lilac,
                    borderRadius: BorderRadius.circular(EsRadius.pill),
                  ),
                  child: Text(
                    '$n',
                    style: EsText.labelS.copyWith(
                      color: c.onLilac,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );

    return DefaultTabController(
      length: 4,
      initialIndex: upcoming.isEmpty && pending.isNotEmpty ? 1 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BrandHeader(
            title: 'Mes sessions',
            subtitle: '${all.length} demande${all.length > 1 ? 's' : ''} '
                'au total',
            bottomPadding: EsSpace.s4,
            trailing: Semantics(
              button: true,
              label: tr('Nouvelle réservation'),
              excludeSemantics: true,
              child: Material(
                color: c.actionPrimary,
                shape: const CircleBorder(),
                elevation: 6,
                shadowColor: c.shadow.withValues(alpha: 0.4),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.go('/studios'),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(Icons.add_rounded, color: c.onActionPrimary),
                  ),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: EsSpace.page),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: c.bgSubtle,
              borderRadius: BorderRadius.circular(EsRadius.pill),
            ),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerHeight: 0,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              labelStyle: EsText.labelM.copyWith(fontSize: 13.5),
              unselectedLabelStyle: EsText.labelM.copyWith(fontSize: 13.5),
              labelColor: c.textPrimary,
              unselectedLabelColor: c.textSecondary,
              indicatorSize: TabBarIndicatorSize.tab,
              splashBorderRadius: BorderRadius.circular(EsRadius.pill),
              indicator: BoxDecoration(
                color: c.bgSurface,
                borderRadius: BorderRadius.circular(EsRadius.pill),
                boxShadow: esShadow(c),
              ),
              tabs: [
                tab('À venir', upcoming.length),
                tab('En attente', pending.length),
                tab('Passées', past.length),
                tab('Refusées', closed.length),
              ],
            ),
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

/// A booking with a calendar-style date block on the left.
class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, required this.now});
  final Booking booking;
  final DateTime now;

  static const _mo = [
    'JANV', 'FÉVR', 'MARS', 'AVR', 'MAI', 'JUIN',
    'JUIL', 'AOÛT', 'SEPT', 'OCT', 'NOV', 'DÉC',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final s = studioById(booking.studioId);
    final room = DemoWorld.rooms.firstWhere((r) => r.id == s.roomId);
    final canShowQr =
        booking.status == BookingStatus.approved && booking.end.isAfter(now);
    final muted = booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.refused ||
        !booking.end.isAfter(now);
    return EsCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/bookings/${booking.id}'),
      semanticLabel: '${s.name}, ${Fmt.relativeDay(booking.start, now)} '
          '${Fmt.range(booking.start, booking.end)}, ${booking.status.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: muted ? c.bgSubtle : c.lilac,
                  borderRadius: BorderRadius.circular(EsRadius.md),
                ),
                child: Column(
                  children: [
                    Text(
                      _mo[booking.start.month - 1],
                      style: EsText.overline.copyWith(
                        color: muted ? c.textSecondary : c.onLilac,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '${booking.start.day}',
                      style: EsText.displayM.copyWith(
                        color: muted ? c.textSecondary : c.onLilac,
                        fontSize: 22,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: EsText.titleM.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Fmt.relativeDay(booking.start, now)} · '
                      '${Fmt.range(booking.start, booking.end)}',
                      style: EsText.bodyS.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    StatusChip(booking.status),
                  ],
                ),
              ),
              if (canShowQr)
                IconButton.filled(
                  tooltip: tr('Afficher le QR code'),
                  style: IconButton.styleFrom(
                    backgroundColor: c.actionPrimary,
                    foregroundColor: c.onActionPrimary,
                    fixedSize: const Size(48, 48),
                  ),
                  onPressed: () => context.push('/qr/${booking.id}'),
                  icon: const Icon(Icons.qr_code_2_rounded),
                )
              else
                Icon(Icons.chevron_right_rounded, color: c.textDisabled),
            ],
          ),
          if (booking.status == BookingStatus.refused &&
              booking.refusalReason != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.dangerBg,
                borderRadius: BorderRadius.circular(EsRadius.sm),
              ),
              child: Text(
                'Motif : ${booking.refusalReason}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: EsText.bodyS.copyWith(color: c.dangerText),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Divider(height: 1, color: c.border),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 14, color: c.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${room.name} · ${booking.activity.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EsText.bodyS.copyWith(color: c.textSecondary),
                ),
              ),
              Text(
                booking.reference,
                style: EsText.bodyS.copyWith(
                  color: c.textDisabled,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
