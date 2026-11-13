import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell.dart';
import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/app_state.dart';
import '../../data/demo_world.dart';
import '../../domain/bookings.dart';
import '../../domain/people.dart';
import '../../domain/rules/approval.dart';
import '../notifications/notifications_screen.dart';
import 'decision_screen.dart';

/// G1 · Validation inbox for Level 1 approvers, the Studio Manager and the
/// Administrator. Oldest request first, so nobody waits too long.
class ValidationsScreen extends ConsumerStatefulWidget {
  const ValidationsScreen({super.key});

  @override
  ConsumerState<ValidationsScreen> createState() => _ValidationsState();
}

class _ValidationsState extends ConsumerState<ValidationsScreen> {
  bool showDone = false;

  /// Computer layout: the request shown in the right pane.
  String? selectedId;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final me = ref.watch(currentPersonProvider);
    final notifier = ref.read(worldProvider.notifier);
    final inbox = inboxFor(me, w.bookings, people: DemoWorld.people);
    final done = [
      for (final b in w.bookings)
        if (b.history.any(
          (e) =>
              e.actorId == me.id &&
              (e.type == BookingEventType.entityApproved ||
                  e.type == BookingEventType.studioApproved ||
                  e.type == BookingEventType.refused),
        ))
          b,
    ]..sort((a, b) => _lastAt(b).compareTo(_lastAt(a)));
    final items = showDone ? done : inbox;
    // The studio team also sees what is on its way: requests still waiting
    // for their level 1 approver (read-only here), so nothing surprises them.
    final upcoming = !showDone &&
            (me.has(Role.studioManager) || me.has(Role.admin))
        ? ([
            for (final b in w.bookings)
              if (!b.isPrivate &&
                  b.status == BookingStatus.pendingEntity &&
                  !inbox.contains(b))
                b,
          ]..sort((a, b) => a.start.compareTo(b.start)))
        : const <Booking>[];
    final wide = isWide(context);
    final current = wide
        ? (items.any((b) => b.id == selectedId)
            ? selectedId
            : (selectedId != null && w.bookings.any((b) => b.id == selectedId)
                ? selectedId
                : items.firstOrNull?.id))
        : null;

    final list = ListView(
        padding: EdgeInsets.only(bottom: tabBarSpace(context)),
        children: [
          BrandHeader(
            title: 'Validations',
            subtitle: inbox.isEmpty
                ? 'Tout est traité. Beau travail.'
                : '${inbox.length} demande${inbox.length > 1 ? 's' : ''} '
                    'à traiter',
            bottomPadding: EsSpace.s4,
            trailing: wide ? null : const NoticeBell(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: EsSpace.page),
            child: _Segmented(
              left: 'À traiter',
              leftCount: inbox.length,
              right: 'Déjà traitées',
              rightCount: done.length,
              rightSelected: showDone,
              onChanged: (v) => setState(() => showDone = v),
            ),
          ),
          const SizedBox(height: EsSpace.s4),
          if (items.isEmpty)
            EmptyState(
              icon: showDone ? Icons.history_rounded : Icons.task_alt_rounded,
              title: showDone ? 'Aucune décision encore' : 'Rien à valider',
              message: showDone
                  ? 'Vos validations et refus apparaîtront ici.'
                  : 'Les nouvelles demandes arrivent ici dès leur envoi.',
            ),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                EsSpace.page,
                0,
                EsSpace.page,
                EsSpace.s3,
              ),
              child: FadeInUp(
                index: i,
                child: RequestReviewCard(
                  booking: items[i],
                  now: w.now,
                  conflict: items[i].status == BookingStatus.pendingStudio
                      ? notifier.level2Conflict(items[i])
                      : null,
                  selected: items[i].id == current,
                  onTap: wide
                      ? () => setState(() => selectedId = items[i].id)
                      : () => context.push('/validations/${items[i].id}'),
                ),
              ),
            ),
          if (upcoming.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                EsSpace.page,
                EsSpace.s4,
                EsSpace.page,
                EsSpace.s1,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Overline(
                      'Bientôt chez vous · ${upcoming.length} en attente du '
                      'niveau 1',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                EsSpace.page,
                0,
                EsSpace.page,
                EsSpace.s3,
              ),
              child: Text(
                'Vous les validerez après l’accord du responsable de '
                'l’entité.',
                style: EsText.bodyS.copyWith(color: c.textSecondary),
              ),
            ),
            for (final b in upcoming)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  EsSpace.page,
                  0,
                  EsSpace.page,
                  EsSpace.s3,
                ),
                child: Opacity(
                  opacity: 0.85,
                  child: RequestReviewCard(
                    booking: b,
                    now: w.now,
                    waitingFor: needsLevel1Fallback(b, DemoWorld.people)
                        ? 'Administration (repli)'
                        : level1Label(b.requesterType),
                    selected: b.id == current,
                    onTap: wide
                        ? () => setState(() => selectedId = b.id)
                        : () => context.push('/validations/${b.id}'),
                  ),
                ),
              ),
          ],
        ],
    );

    if (!wide) return BlobBackground(variant: 1, child: list);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 460, child: list),
        VerticalDivider(width: 1, color: c.border),
        Expanded(
          child: current == null
              ? const EmptyState(
                  icon: Icons.touch_app_outlined,
                  title: 'Choisissez une demande',
                  message: 'Ses détails et les actions apparaîtront ici.',
                )
              : DecisionScreen(
                  key: ValueKey(current),
                  bookingId: current,
                  embedded: true,
                ),
        ),
      ],
    );
  }

  DateTime _lastAt(Booking b) => b.history.last.at;
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.left,
    required this.leftCount,
    required this.right,
    required this.rightCount,
    required this.rightSelected,
    required this.onChanged,
  });
  final String left;
  final int leftCount;
  final String right;
  final int rightCount;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    Widget seg(String label, int n, bool selected, bool value) => Expanded(
          child: Semantics(
            selected: selected,
            button: true,
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: EsMotion.fast,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? c.bgSurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(EsRadius.pill),
                  boxShadow: selected ? esShadow(c) : null,
                ),
                child: Text(
                  '$label · $n',
                  style: EsText.labelM.copyWith(
                    fontSize: 13.5,
                    color: selected ? c.textPrimary : c.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.bgSubtle,
        borderRadius: BorderRadius.circular(EsRadius.pill),
      ),
      child: Row(
        children: [
          seg(left, leftCount, !rightSelected, false),
          seg(right, rightCount, rightSelected, true),
        ],
      ),
    );
  }
}

/// A request as an approver sees it: who, where, when, how long it has
/// waited, and whether anything blocks it.
class RequestReviewCard extends StatelessWidget {
  const RequestReviewCard({
    super.key,
    required this.booking,
    required this.now,
    required this.onTap,
    this.conflict,
    this.selected = false,
    this.waitingFor,
  });

  /// Shown when the request waits for someone else (read-only).
  final String? waitingFor;
  final Booking booking;
  final DateTime now;
  final VoidCallback onTap;
  final String? conflict;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final b = booking;
    final s = studioById(b.studioId);
    final who = personById(b.requesterId);
    final level1 = b.status == BookingStatus.pendingEntity;
    final sent = b.history.last.at;
    final waitedLong = now.difference(sent).inHours >= 24 && b.status.isPending;
    return EsCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      color: selected ? c.lilac : null,
      semanticLabel: 'Demande de ${who.fullName}, ${s.name}, '
          '${Fmt.relativeDay(b.start, now)} ${Fmt.range(b.start, b.end)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(who.initials, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      who.fullName,
                      style: EsText.titleS.copyWith(color: c.textPrimary),
                    ),
                    Text(
                      [
                        b.requesterType.label,
                        if (establishmentById(b.establishmentId) != null)
                          establishmentById(b.establishmentId)!.short,
                      ].join(' · '),
                      style: EsText.bodyS.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              if (b.status.isPending)
                Tag(
                  label: level1 ? 'Niveau 1' : 'Niveau 2',
                  background: level1 ? c.pendingBg : c.reviewBg,
                  foreground: level1 ? c.pendingText : c.reviewText,
                )
              else
                StatusChip(b.status),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? c.bgSurface : c.bgSubtle,
              borderRadius: BorderRadius.circular(EsRadius.md),
            ),
            child: Row(
              children: [
                PhotoThumb(s.photo, size: 46, radius: 12),
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
                        '${Fmt.relativeDay(b.start, now)} · '
                        '${Fmt.range(b.start, b.end)} · ${b.activity.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EsText.bodyS.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 15,
                color: waitedLong ? c.pendingText : c.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Reçue ${Fmt.ago(sent, now)}',
                style: EsText.labelS.copyWith(
                  color: waitedLong ? c.pendingText : c.textSecondary,
                ),
              ),
              if (b.equipment.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.inventory_2_outlined,
                  size: 15,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${b.equipment.length} matériel',
                  style: EsText.labelS.copyWith(color: c.textSecondary),
                ),
              ],
              const Spacer(),
              Text(
                b.reference,
                style: EsText.bodyS.copyWith(color: c.textDisabled),
              ),
            ],
          ),
          if (conflict != null) ...[
            const SizedBox(height: 10),
            InfoBanner(tone: BannerTone.danger, text: conflict!),
          ],
          if (waitingFor != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.hourglass_top_rounded, size: 15, color: c.pendingText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Attend : $waitingFor',
                    style: EsText.labelS.copyWith(color: c.pendingText),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
