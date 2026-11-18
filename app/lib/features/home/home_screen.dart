import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell.dart';
import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/logo.dart';
import '../../data/app_state.dart';
import '../../data/demo_world.dart';
import '../../data/selectors.dart';
import '../../domain/bookings.dart';
import '../../domain/rules/approval.dart';
import '../../domain/rules/quota.dart';
import '../notifications/notifications_screen.dart';
import '../../data/directory.dart';
import '../../core/l10n/text.dart';

/// B1 · Home. Requesters see their next session, quota and requests.
/// The studio manager sees what is waiting for them.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(worldProvider);
    final me = ref.watch(currentPersonProvider);
    final isRequester = me.roles.any((r) => r.isRequester);
    final top = MediaQuery.paddingOf(context).top;

    return BlobBackground(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          EsSpace.page,
          top + EsSpace.s4,
          EsSpace.page,
          tabBarSpace(context),
        ),
        children: [
          // On computers and tablets the side menu already has the logo,
          // the bell and the profile.
          if (!isWide(context)) ...[
            const _TopRow(),
            const SizedBox(height: EsSpace.s5),
          ],
          if (isRequester) _RequesterHome(w: w) else _ManagerHome(w: w),
        ],
      ),
    );
  }
}

/// Phones: one column. Wide screens: the main column on the left and the
/// lists on the right, so the page uses the room instead of a thin strip.
class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.main, required this.side});
  final List<Widget> main;
  final List<Widget> side;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 960) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [...main, const SizedBox(height: EsSpace.s4), ...side],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 11,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: main,
              ),
            ),
            const SizedBox(width: EsSpace.s6),
            Expanded(
              flex: 9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: side,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Euromed Studios logo on the left, notifications and profile on the right.
class _TopRow extends ConsumerWidget {
  const _TopRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentPersonProvider);
    return Row(
      children: [
        const EuromedStudiosLogo(height: 40, onDark: false),
        const Spacer(),
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: esShadow(context.es),
          ),
          child: const NoticeBell(),
        ),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: tr('Mon profil'),
          excludeSemantics: true,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go('/profile'),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: context.es.bgSurface,
                shape: BoxShape.circle,
                boxShadow: esShadow(context.es),
              ),
              child: Avatar(me.initials, size: 40),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Vos idées prennent vie en studio." with the last words in blue.
class _Headline extends StatelessWidget {
  const _Headline({required this.greeting, required this.lead, this.accent});
  final String greeting;
  final String lead;
  final String? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: EsText.bodyL.copyWith(color: c.textSecondary)),
        const SizedBox(height: 6),
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(
              text: lead,
              children: [
                if (accent != null)
                  TextSpan(text: accent, style: TextStyle(color: c.accent)),
              ],
            ),
            style: EsText.hero.copyWith(color: c.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _RequesterHome extends ConsumerWidget {
  const _RequesterHome({required this.w});
  final WorldState w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentPersonProvider);
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
        _Headline(
          greeting: 'Bonjour ${me.firstName},',
          lead: 'Vos idées prennent vie ',
          accent: 'en studio.',
        ),
        const SizedBox(height: EsSpace.s5),
        _TwoColumns(
          main: [
            FadeInUp(
              child: next != null
                  ? _NextSessionHero(booking: next, now: w.now)
                  : const _EmptyHero(),
            ),
            const SizedBox(height: EsSpace.s5),
            FadeInUp(
              index: 1,
              child: _QuickActions(nextQrId: next?.id),
            ),
            if (!quota.unlimited) ...[
              const SizedBox(height: EsSpace.s5),
              FadeInUp(index: 2, child: _QuotaCard(quota: quota)),
            ],
          ],
          side: [
            SectionTitle(
              'Demandes en cours',
              actionLabel: 'Voir tout',
              onAction: () => context.go('/bookings'),
            ),
            const SizedBox(height: EsSpace.s2),
            if (pending.isEmpty)
              EsCard(
                child: Row(
                  children: [
                    const IconTile(Icons.inbox_outlined, size: 40),
                    const SizedBox(width: EsSpace.s3),
                    Expanded(
                      child: Text(
                        'Aucune demande en attente. Tout est à jour.',
                        style: EsText.bodyM
                            .copyWith(color: context.es.textSecondary),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (var i = 0; i < pending.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: EsSpace.s3),
                  child: FadeInUp(
                    index: 3 + i,
                    child: RequestCard(booking: pending[i], now: w.now),
                  ),
                ),
            const SizedBox(height: EsSpace.s2),
            SectionTitle(
              'En ce moment',
              trailing: _LiveLegend(count: live.length),
            ),
            const SizedBox(height: EsSpace.s2),
            _LiveStrip(rooms: live),
          ],
        ),
      ],
    );
  }
}

/// The next approved session as a big photo card with the QR shortcut.
class _NextSessionHero extends StatelessWidget {
  const _NextSessionHero({required this.booking, required this.now});
  final Booking booking;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final s = studioById(booking.studioId);
    final room = DemoWorld.rooms.firstWhere((r) => r.id == s.roomId);
    final ongoing = !booking.start.isAfter(now);
    final until = booking.start.difference(now);
    final countdown = ongoing
        ? 'En cours · jusqu’à ${Fmt.time(booking.end)}'
        : until.inHours < 24
            ? '${Fmt.relativeDay(booking.start, now)} · dans '
                '${until.inHours > 0 ? '${until.inHours} h ' : ''}'
                '${until.inMinutes % 60} min'
            : Fmt.relativeDay(booking.start, now);

    return Semantics(
      button: true,
      label: tr('${ongoing ? 'Séance en cours' : 'Prochaine séance'} : '
          '${s.name}, ${Fmt.relativeDay(booking.start, now)}, '
          '${Fmt.range(booking.start, booking.end)}. Ouvrir le QR code.'),
      excludeSemantics: true,
      child: EsCard(
        padding: EdgeInsets.zero,
        radius: EsRadius.xl,
        onTap: () => context.push('/qr/${booking.id}'),
        child: SizedBox(
          height: 228,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(s.photo, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.25, 1],
                    colors: [
                      Colors.transparent,
                      c.bgBrand.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: _GlassPill(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LiveDot(
                        color: ongoing ? c.successFill : c.brandAccent,
                        size: 7,
                      ),
                      Text(
                        ongoing ? 'Séance en cours' : 'Prochaine séance',
                        style: EsText.labelS.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            countdown,
                            style: EsText.labelS
                                .copyWith(color: c.brandAccent, fontSize: 12.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.name,
                            style:
                                EsText.displayM.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${Fmt.range(booking.start, booking.end)} · '
                            '${room.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EsText.bodyS.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        color: c.bgBrand,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(EsRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: child,
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return EsCard(
      padding: EdgeInsets.zero,
      radius: EsRadius.xl,
      onTap: () => context.go('/studios'),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/photos/cover.jpg', fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    c.bgBrand.withValues(alpha: 0.9)
                  ],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aucune séance prévue',
                    style: EsText.displayM.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choisissez un studio et réservez votre premier créneau.',
                    style: EsText.bodyS.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({this.nextQrId});
  final String? nextQrId;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.add_rounded, 'Réserver', () => context.go('/studios')),
      (
        Icons.calendar_today_rounded,
        'Mes sessions',
        () => context.go('/bookings')
      ),
      (Icons.layers_rounded, 'Projets', () => context.go('/projects')),
      (
        Icons.qr_code_2_rounded,
        'Mon QR',
        nextQrId == null
            ? () => context.go('/bookings')
            : () => context.push('/qr/$nextQrId'),
      ),
    ];
    return Row(
      children: [
        for (final (icon, label, onTap) in items)
          Expanded(
            child: Semantics(
              button: true,
              label: tr(label),
              excludeSemantics: true,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(EsRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      IconTile(icon, size: 54),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: EsText.labelS
                            .copyWith(color: context.es.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Weekly quota as a ring, so "how much is left" reads at a glance.
class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.quota});
  final QuotaStatus quota;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final full = quota.remainingMinutes == 0;
    return EsCard(
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: quota.ratio),
              duration: EsMotion.slow * 2,
              curve: EsMotion.curve,
              builder: (context, v, _) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: c.lilac,
                      color: full ? c.dangerText : c.actionPrimary,
                    ),
                  ),
                  Text(
                    formatMinutes(quota.remainingMinutes),
                    style: EsText.titleS.copyWith(color: c.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: EsSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  full ? 'Quota atteint' : 'Temps disponible cette semaine',
                  style: EsText.titleM.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatMinutes(quota.usedMinutes)} utilisées sur '
                  '${formatMinutes(quota.limitMinutes!)}. '
                  'Renouvelé lundi à 00:00.',
                  style: EsText.bodyS.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A request with its photo, slot, status and approval progress.
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.booking, required this.now});
  final Booking booking;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final s = studioById(booking.studioId);
    return EsCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/bookings/${booking.id}'),
      semanticLabel: '${s.name}, ${Fmt.relativeDay(booking.start, now)} '
          '${Fmt.range(booking.start, booking.end)}, ${booking.status.label}',
      child: Row(
        children: [
          PhotoThumb(s.photo, size: 64),
          const SizedBox(width: EsSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: EsText.titleM.copyWith(color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${Fmt.relativeDay(booking.start, now)} · '
                  '${Fmt.range(booking.start, booking.end)}',
                  style: EsText.bodyS.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(child: StatusChip(booking.status)),
                    const SizedBox(width: 8),
                    ApprovalDots(status: booking.status),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textDisabled),
        ],
      ),
    );
  }
}

/// Two small bars showing how far the request is in the two-step approval.
class ApprovalDots extends StatelessWidget {
  const ApprovalDots({super.key, required this.status});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final done = switch (status) {
      BookingStatus.pendingEntity => 0,
      BookingStatus.pendingStudio => 1,
      BookingStatus.approved || BookingStatus.completed => 2,
      _ => -1,
    };
    if (done < 0) return const SizedBox.shrink();
    return Semantics(
      label: tr('Étape $done sur 2 validée'),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 2; i++)
            Container(
              width: 16,
              height: 5,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: i < done ? c.successFill : c.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveLegend extends StatelessWidget {
  const _LiveLegend({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LiveDot(color: c.successFill, size: 7),
        Text(
          'En direct',
          style: EsText.labelS.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

/// Live status of every studio, as a sideways-scrolling strip.
class _LiveStrip extends StatelessWidget {
  const _LiveStrip({required this.rooms});
  final List<LiveRoom> rooms;

  @override
  Widget build(BuildContext context) {
    // Computers and tablets: every studio at once, as a grid.
    if (isWide(context)) {
      return LayoutBuilder(
        builder: (context, box) {
          const gap = EsSpace.s3;
          final cols = (box.maxWidth / 170).floor().clamp(2, 6);
          final w = (box.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final r in rooms) LiveCard(room: r, width: w),
            ],
          );
        },
      );
    }
    return SizedBox(
      height: 178,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: rooms.length,
        separatorBuilder: (_, __) => const SizedBox(width: EsSpace.s3),
        itemBuilder: (context, i) => LiveCard(room: rooms[i]),
      ),
    );
  }
}

/// One studio's state right now: free, in use, or in maintenance.
class LiveCard extends StatelessWidget {
  const LiveCard({super.key, required this.room, this.width = 148});
  final LiveRoom room;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (String label, Color fg, Color bg) = switch (room.state) {
      LiveState.free => ('Libre', c.successText, c.successBg),
      LiveState.occupied => (
          'Occupé · ${Fmt.time(room.until!)}',
          c.reviewText,
          c.reviewBg,
        ),
      LiveState.maintenance => (
          'Maintenance',
          c.pendingText,
          c.pendingBg,
        ),
    };
    return SizedBox(
      width: width,
      child: EsCard(
        padding: EdgeInsets.zero,
        onTap: () => context.push('/studios/${room.studio.id}'),
        semanticLabel: '${room.studio.name} : $label',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.asset(
                  room.studio.photo,
                  height: 96,
                  width: width,
                  fit: BoxFit.cover,
                ),
                if (room.state != LiveState.free)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.18),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.studio.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EsText.titleS.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Tag(label: label, background: bg, foreground: fg, dot: true),
                ],
              ),
            ),
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
    final inbox = inboxFor(me, w.bookings, people: Directory.people);
    final today = [
      for (final b in w.bookings)
        if (b.status == BookingStatus.approved &&
            b.start.year == w.now.year &&
            b.start.month == w.now.month &&
            b.start.day == w.now.day)
          b,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final live = liveStatus(w);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Headline(
          greeting: 'Bonjour ${me.firstName}',
          lead: 'Les studios, ',
          accent: 'aujourd’hui.',
        ),
        const SizedBox(height: EsSpace.s5),
        _TwoColumns(
          main: [
            FadeInUp(
              child: EsCard(
                color: c.bgBrand,
                radius: EsRadius.xl,
                padding: const EdgeInsets.all(EsSpace.s5),
                onTap: () => context.go('/validations'),
                semanticLabel: '${inbox.length} demandes attendent votre '
                    'validation. Ouvrir.',
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${inbox.length}',
                          style: EsText.hero.copyWith(
                            color: Colors.white,
                            fontSize: 52,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: EsSpace.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inbox.length == 1
                                ? 'demande attend votre validation'
                                : 'demandes attendent votre validation',
                            style: EsText.titleM.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Les plus anciennes en premier.',
                            style: EsText.bodyS
                                .copyWith(color: c.textOnBrandMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: EsSpace.s4),
            SectionTitle(
              'Séances d’aujourd’hui',
              trailing: Text(
                '${today.length}',
                style: EsText.titleM.copyWith(color: c.textSecondary),
              ),
            ),
            const SizedBox(height: EsSpace.s2),
            if (today.isEmpty)
              Text(
                'Aucune séance validée aujourd’hui.',
                style: EsText.bodyM.copyWith(color: c.textSecondary),
              ),
            for (var i = 0; i < today.length; i++)
              FadeInUp(
                index: i + 1,
                child: _TimelineRow(
                  booking: today[i],
                  now: w.now,
                  last: i == today.length - 1,
                ),
              ),
          ],
          side: [
            SectionTitle(
              'En ce moment',
              trailing: _LiveLegend(count: live.length),
            ),
            const SizedBox(height: EsSpace.s2),
            _LiveStrip(rooms: live),
          ],
        ),
      ],
    );
  }
}

/// A session on a vertical timeline: time on the left, card on the right.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.booking,
    required this.now,
    required this.last,
  });
  final Booking booking;
  final DateTime now;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final s = studioById(booking.studioId);
    final ongoing = !booking.start.isAfter(now) && booking.end.isAfter(now);
    final past = !booking.end.isAfter(now);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 50,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                Fmt.time(booking.start),
                style: EsText.numeric.copyWith(
                  color: past ? c.textDisabled : c.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 18),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ongoing ? c.successFill : c.bgSurface,
                  border: Border.all(
                    color: ongoing ? c.successFill : c.borderStrong,
                    width: 2,
                  ),
                ),
              ),
              if (!last) Expanded(child: Container(width: 2, color: c.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: EsSpace.s3),
              child: EsCard(
                padding: const EdgeInsets.all(10),
                onTap: () => context.push('/bookings/${booking.id}'),
                child: Row(
                  children: [
                    PhotoThumb(s.photo, size: 44, radius: 12),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: EsText.titleS.copyWith(color: c.textPrimary),
                          ),
                          Text(
                            '${Fmt.range(booking.start, booking.end)} · '
                            '${personById(booking.requesterId).displayName}',
                            style:
                                EsText.bodyS.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (ongoing)
                      Tag(
                        label: 'En cours',
                        background: c.successBg,
                        foreground: c.successText,
                        dot: true,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
