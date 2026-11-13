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
import '../../domain/rules/approval.dart';
import '../../domain/rules/quota.dart';

/// B1 · Home. Requesters see their next session, quota and requests.
/// The studio manager sees what is waiting for them.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(worldProvider);
    final me = ref.watch(currentPersonProvider);
    final c = context.es;
    final isRequester = me.roles.any((r) => r.isRequester);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        BrandHeader(
          title: 'Bonjour, ${me.firstName}',
          subtitle: me.title,
          bottomPadding: 72,
          trailing: IconButton(
            tooltip: 'Notifications',
            onPressed: () =>
                _soon(context, 'Les notifications arrivent à l’étape 7.'),
            icon: Icon(
              Icons.notifications_none_rounded,
              color: c.textOnBrand,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: EsSpace.s4),
            child: isRequester ? _RequesterHome(w: w) : _ManagerHome(w: w),
          ),
        ),
      ],
    );
  }
}

void _soon(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

class _RequesterHome extends ConsumerWidget {
  const _RequesterHome({required this.w});
  final WorldState w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentPersonProvider);
    final c = context.es;
    final next = nextSession(w, me.id);
    final quota = weeklyQuota(w, me);
    final pending = [
      for (final b in bookingsOf(w, me.id))
        if (b.status.isPending) b,
    ];
    final live = liveStatus(w);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next != null)
          _NextSessionCard(booking: next, now: w.now)
        else
          EsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Overline('Prochaine séance'),
                const SizedBox(height: EsSpace.s2),
                Text(
                  'Aucune séance validée pour l’instant.',
                  style: EsText.bodyM.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        const SizedBox(height: EsSpace.s3),
        if (!quota.unlimited) _QuotaCard(quota: quota),
        const SizedBox(height: EsSpace.s3),
        SectionTitle(
          'Mes demandes en cours',
          trailing: TextButton(
            onPressed: () => context.go('/bookings'),
            child: const Text('Tout voir'),
          ),
        ),
        if (pending.isEmpty)
          Text(
            'Aucune demande en attente.',
            style: EsText.bodyM.copyWith(color: c.textSecondary),
          )
        else
          EsCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < pending.length; i++) ...[
                  if (i > 0) const Divider(indent: 16, endIndent: 16),
                  _RequestRow(booking: pending[i], now: w.now),
                ],
              ],
            ),
          ),
        const SizedBox(height: EsSpace.s4),
        const SectionTitle('En ce moment au studio'),
        Wrap(
          spacing: EsSpace.s2,
          runSpacing: EsSpace.s2,
          children: [
            for (final l in live) _LiveTile(room: l),
          ],
        ),
        const SizedBox(height: EsSpace.s5),
        EsButton(
          'Nouvelle réservation',
          icon: Icons.add_rounded,
          onPressed: () => context.go('/studios'),
        ),
        const SizedBox(height: EsSpace.s6),
      ],
    );
  }
}

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({required this.booking, required this.now});
  final Booking booking;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final s = studioById(booking.studioId);
    final room = DemoWorld.rooms.firstWhere((r) => r.id == s.roomId);
    final ongoing = !booking.start.isAfter(now);
    return EsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Overline(ongoing ? 'Séance en cours' : 'Prochaine séance'),
              ),
              StatusChip(booking.status),
            ],
          ),
          const SizedBox(height: EsSpace.s2),
          Text(s.name, style: EsText.titleL.copyWith(color: c.textPrimary)),
          const SizedBox(height: EsSpace.s2),
          Wrap(
            spacing: EsSpace.s4,
            runSpacing: EsSpace.s1,
            children: [
              _Meta(
                Icons.schedule_rounded,
                '${Fmt.relativeDay(booking.start, now)} · '
                '${Fmt.range(booking.start, booking.end)}',
              ),
              _Meta(Icons.place_outlined, room.name),
            ],
          ),
          const SizedBox(height: EsSpace.s3),
          EsButton(
            'Voir mon QR code',
            icon: Icons.qr_code_2_rounded,
            style: EsButtonStyle.secondary,
            size: EsButtonSize.medium,
            onPressed: () => _soon(
              context,
              'Le QR code arrive à l’étape 2. Il ne sera actif que pendant le créneau.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c.textSecondary),
        const SizedBox(width: 6),
        Text(text, style: EsText.bodyM.copyWith(color: c.textSecondary)),
      ],
    );
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.quota});
  final QuotaStatus quota;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return EsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Votre quota cette semaine',
                  style: EsText.titleS.copyWith(color: c.textPrimary),
                ),
              ),
              Text(
                '${formatMinutes(quota.usedMinutes)} / '
                '${formatMinutes(quota.limitMinutes!)}',
                style: EsText.labelM.copyWith(color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: EsSpace.s3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: quota.ratio,
              minHeight: 8,
              backgroundColor: c.bgSubtle,
              color:
                  quota.remainingMinutes == 0 ? c.dangerText : c.actionPrimary,
            ),
          ),
          const SizedBox(height: EsSpace.s2),
          Text(
            quota.remainingMinutes == 0
                ? 'Quota atteint. Il se renouvelle lundi à 00:00.'
                : 'Il vous reste ${formatMinutes(quota.remainingMinutes)}. '
                    'Renouvelé lundi à 00:00.',
            style: EsText.bodyS.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.booking, required this.now});
  final Booking booking;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final s = studioById(booking.studioId);
    return InkWell(
      onTap: () =>
          _soon(context, 'Le détail de la demande arrive à l’étape 2.'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: EsText.titleS.copyWith(color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    '${Fmt.relativeDay(booking.start, now)} · '
                    '${Fmt.range(booking.start, booking.end)}',
                    style: EsText.bodyS.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            StatusChip(booking.status),
          ],
        ),
      ),
    );
  }
}

class _LiveTile extends StatelessWidget {
  const _LiveTile({required this.room});
  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (String label, Color color) = switch (room.state) {
      LiveState.free => ('Libre', c.successText),
      LiveState.occupied => (
          'Occupé jusqu’à ${Fmt.time(room.until!)}',
          c.textLink,
        ),
      LiveState.maintenance => (
          'Maintenance jusqu’à ${Fmt.time(room.until!)}',
          c.pendingText,
        ),
    };
    final width = (MediaQuery.sizeOf(context).width - 32 - 8) / 2;
    return SizedBox(
      width: width,
      child: EsCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room.studio.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EsText.labelM.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(label, style: EsText.bodyS.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

/// What the studio manager sees first.
class _ManagerHome extends ConsumerWidget {
  const _ManagerHome({required this.w});
  final WorldState w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentPersonProvider);
    final c = context.es;
    final inbox = inboxFor(me, w.bookings, people: DemoWorld.people);
    final today = [
      for (final b in w.bookings)
        if (b.status == BookingStatus.approved &&
            b.start.year == w.now.year &&
            b.start.month == w.now.month &&
            b.start.day == w.now.day)
          b,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EsCard(
          onTap: () => context.go('/validations'),
          child: Row(
            children: [
              Text(
                '${inbox.length}',
                style: EsText.displayXL.copyWith(color: c.textPrimary),
              ),
              const SizedBox(width: EsSpace.s3),
              Expanded(
                child: Text(
                  inbox.length == 1
                      ? 'demande attend votre validation'
                      : 'demandes attendent votre validation',
                  style: EsText.titleS.copyWith(color: c.textPrimary),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: EsSpace.s4),
        const SectionTitle('Séances d’aujourd’hui'),
        for (final b in today)
          Padding(
            padding: const EdgeInsets.only(bottom: EsSpace.s2),
            child: EsCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studioById(b.studioId).name,
                          style: EsText.titleS.copyWith(color: c.textPrimary),
                        ),
                        Text(
                          '${Fmt.range(b.start, b.end)} · '
                          '${personById(b.requesterId).displayName}',
                          style: EsText.bodyS.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(b.status),
                ],
              ),
            ),
          ),
        const SizedBox(height: EsSpace.s6),
      ],
    );
  }
}
