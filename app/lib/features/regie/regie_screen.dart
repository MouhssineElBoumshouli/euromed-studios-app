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
import '../../data/booking_service.dart';
import '../../domain/bookings.dart';
import '../../domain/rules/sessions.dart';
import '../notifications/notifications_screen.dart';
import '../../core/l10n/text.dart';

/// H1 · Régie: today's validated sessions, in order, with what to do next
/// for each (let in, close with a report).
class RegieScreen extends ConsumerWidget {
  const RegieScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    List<Booking> sessionsOn(DateTime d) => [
          for (final b in w.bookings)
            if (!b.isPrivate &&
                (b.status == BookingStatus.approved ||
                    b.status == BookingStatus.completed ||
                    b.status == BookingStatus.noShow) &&
                b.start.year == d.year &&
                b.start.month == d.month &&
                b.start.day == d.day)
              b,
        ]..sort((a, b) => a.start.compareTo(b.start));
    final today = sessionsOn(w.now);
    // Closed today (weekend): show the next open day instead of nothing.
    final closed = !w.policy.openWeekdays.contains(w.now.weekday);
    var next = DateTime(w.now.year, w.now.month, w.now.day + 1);
    for (var i = 0;
        i < 7 && !w.policy.openWeekdays.contains(next.weekday);
        i++) {
      next = DateTime(next.year, next.month, next.day + 1);
    }
    final upcoming = closed ? sessionsOn(next) : const <Booking>[];
    int count(Set<SessionPhase> p) => today
        .where(
          (b) => p.contains(
            phaseOf(b, w.now, earlyMinutes: w.policy.qrGraceMinutes),
          ),
        )
        .length;

    return ListView(
      padding: EdgeInsets.only(bottom: tabBarSpace(context)),
      children: [
        BrandHeader(
          title: 'Régie',
          subtitle: 'Aujourd’hui · ${Fmt.longDay(w.now)}',
          bottomPadding: EsSpace.s4,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isWide(context)) ...[
                const NoticeBell(),
                const SizedBox(width: 8),
              ],
              EsButton(
                'Scanner',
                icon: Icons.qr_code_scanner_rounded,
                expand: false,
                size: EsButtonSize.medium,
                onPressed: () => context.push('/scanner'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EsSpace.page),
          child: Row(
            children: [
              _Count(
                'À venir',
                count({SessionPhase.upcoming, SessionPhase.ready}),
                c.reviewText,
              ),
              const SizedBox(width: 10),
              _Count(
                  'En cours', count({SessionPhase.inProgress}), c.successText),
              const SizedBox(width: 10),
              _Count('En retard', count({SessionPhase.late}), c.pendingText),
              const SizedBox(width: 10),
              _Count('Terminées', count({SessionPhase.done}), c.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: EsSpace.s4),
        if (closed) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: EsSpace.page),
            child: InfoBanner(
              icon: Icons.door_front_door_outlined,
              title: 'Studios fermés aujourd’hui',
              text: 'Voici les séances validées de la prochaine journée.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              EsSpace.page,
              EsSpace.s4,
              EsSpace.page,
              EsSpace.s2,
            ),
            child: SectionTitle(Fmt.longDay(next)),
          ),
          if (upcoming.isEmpty)
            const EmptyState(
              icon: Icons.weekend_outlined,
              title: 'Aucune séance validée',
              message: 'Les séances validées apparaîtront ici.',
            ),
          for (var i = 0; i < upcoming.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                EsSpace.page,
                0,
                EsSpace.page,
                EsSpace.s3,
              ),
              child: FadeInUp(
                index: i,
                child: SessionCard(booking: upcoming[i], now: w.now),
              ),
            ),
        ] else if (today.isEmpty)
          const EmptyState(
            icon: Icons.weekend_outlined,
            title: 'Aucune séance aujourd’hui',
            message: 'Les séances validées du jour apparaîtront ici.',
          ),
        for (var i = 0; i < today.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              EsSpace.page,
              0,
              EsSpace.page,
              EsSpace.s3,
            ),
            child: FadeInUp(
              index: i,
              child: SessionCard(booking: today[i], now: w.now),
            ),
          ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Expanded(
      child: EsCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: EsText.displayM.copyWith(color: color, fontSize: 24),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: EsText.bodyS.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

(String, Color, Color) phaseLabel(EsColors c, SessionPhase p) => switch (p) {
      SessionPhase.upcoming => ('À venir', c.neutralBg, c.neutralText),
      SessionPhase.ready => ('Accès ouvert', c.reviewBg, c.reviewText),
      SessionPhase.inProgress => ('En cours', c.successBg, c.successText),
      SessionPhase.late => ('En retard', c.pendingBg, c.pendingText),
      SessionPhase.done => ('Terminée', c.neutralBg, c.neutralText),
      SessionPhase.missed => ('Personne n’est venu', c.dangerBg, c.dangerText),
    };

/// One session of the day with its next action.
class SessionCard extends ConsumerStatefulWidget {
  const SessionCard({super.key, required this.booking, required this.now});
  final Booking booking;
  final DateTime now;

  @override
  ConsumerState<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<SessionCard> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final b = widget.booking;
    final s = studioById(b.studioId);
    final who = personById(b.requesterId);
    final early = ref.watch(worldProvider).policy.qrGraceMinutes;
    final phase = phaseOf(b, widget.now, earlyMinutes: early);
    final (label, bg, fg) = phaseLabel(c, phase);
    final canIn = checkInProblem(b, widget.now, earlyMinutes: early) == null;
    final canClose = canComplete(b, widget.now);
    final canAbsent = canMarkNoShow(b, widget.now);
    return EsCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/bookings/${b.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  '${Fmt.time(b.start)}\n${Fmt.time(b.end)}',
                  style: EsText.numeric.copyWith(color: c.textPrimary),
                ),
              ),
              PhotoThumb(s.photo, size: 48, radius: 12),
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
                      '${who.fullName} · ${b.activity.label}',
                      style: EsText.bodyS.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Tag(label: label, background: bg, foreground: fg, dot: true),
            ],
          ),
          if (b.equipment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in b.equipment)
                  Tag(
                    label: '${equipmentById(e.itemId).name} × ${e.quantity}',
                    icon: Icons.inventory_2_outlined,
                    background: c.bgSubtle,
                    foreground: c.textSecondary,
                  ),
              ],
            ),
          ],
          if (canIn || canClose || canAbsent) ...[
            const SizedBox(height: 12),
            if (canAbsent && canIn) ...[
              Text(
                'Pas encore arrivé·e. Vous pouvez encore l’accueillir, ou '
                'noter l’absence.',
                style: EsText.bodyS.copyWith(color: c.pendingText),
              ),
              const SizedBox(height: 8),
            ],
            if (canIn)
              EsButton(
                'Enregistrer l’arrivée',
                icon: Icons.login_rounded,
                size: EsButtonSize.medium,
                loading: busy,
                onPressed: () => _run(
                  () => ref
                      .read(bookingServiceProvider)
                      .checkIn(b.id, by: ref.read(currentPersonProvider)),
                  'Arrivée enregistrée. Bonne séance !',
                ),
              )
            else if (canClose)
              EsButton(
                'Clôturer la séance',
                icon: Icons.task_alt_rounded,
                style: EsButtonStyle.secondary,
                size: EsButtonSize.medium,
                loading: busy,
                onPressed: () async {
                  final report = await showModalBottomSheet<String?>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => const _ReportSheet(),
                  );
                  if (report == null) return;
                  await _run(
                    () => ref.read(bookingServiceProvider).complete(
                          b.id,
                          by: ref.read(currentPersonProvider),
                          report: report.isEmpty ? null : report,
                        ),
                    'Séance clôturée.',
                  );
                },
              ),
            if (canAbsent) ...[
              const SizedBox(height: 8),
              EsButton(
                'Noter l’absence',
                icon: Icons.person_off_outlined,
                style: EsButtonStyle.ghost,
                size: EsButtonSize.medium,
                onPressed: busy
                    ? null
                    : () => _run(
                          () => ref.read(bookingServiceProvider).markNoShow(
                                b.id,
                                by: ref.read(currentPersonProvider),
                              ),
                          'Absence notée.',
                        ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, String ok) async {
    setState(() => busy = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await action();
      m.showSnackBar(SnackBar(content: Text(ok)));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(sessionError(e))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

/// Turns a refusal from the server into a sentence.
String sessionError(Object e) {
  final m = e.toString();
  if (m.contains('too_early')) {
    return 'Trop tôt : l’accès ouvre 15 minutes avant le début.';
  }
  if (m.contains('session_over')) return 'Le créneau est terminé.';
  if (m.contains('already_checked_in')) return 'Arrivée déjà enregistrée.';
  if (m.contains('not_validated')) return 'Cette séance n’est pas validée.';
  return 'L’action n’a pas pu être enregistrée. Réessayez.';
}

const _reportChips = [
  'RAS, studio rendu propre',
  'Matériel rendu complet',
  'Retard du demandeur',
  'Problème technique signalé',
];

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final text = TextEditingController();

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        EsSpace.page,
        0,
        EsSpace.page,
        EsSpace.s5 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Fin de séance',
            style: EsText.displayM.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Un mot pour l’historique (facultatif).',
            style: EsText.bodyM.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: EsSpace.s3),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _reportChips)
                ActionChip(
                  label: Text(r),
                  onPressed: () =>
                      text.text = text.text.isEmpty ? r : '${text.text} · $r',
                ),
            ],
          ),
          const SizedBox(height: EsSpace.s3),
          TextField(
            controller: text,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: tr('Ex. : câble XLR abîmé, à remplacer'),
            ),
          ),
          const SizedBox(height: EsSpace.s2),
          EsButton(
            'Clôturer la séance',
            icon: Icons.task_alt_rounded,
            onPressed: () => Navigator.pop(context, text.text.trim()),
          ),
        ],
      ),
    );
  }
}
