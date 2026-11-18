import 'package:flutter/material.dart' hide Text;

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../data/app_state.dart';
import '../../domain/bookings.dart';
import '../../domain/rules/approval.dart';
import '../../core/l10n/text.dart';

enum _StepState { done, now, next, failed }

/// The request's journey: sent → Level 1 → Level 2 → validated (R-20),
/// with who decided, when, and any comment or refusal reason.
class BookingTimeline extends StatelessWidget {
  const BookingTimeline({super.key, required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    BookingEvent? ev(BookingEventType t) {
      for (final e in b.history) {
        if (e.type == t) return e;
      }
      return null;
    }

    final sent = ev(BookingEventType.submitted);
    final l1 = ev(BookingEventType.entityApproved);
    final l2 = ev(BookingEventType.studioApproved);
    final refused = ev(BookingEventType.refused);
    final cancelled = ev(BookingEventType.cancelled);
    final checkIn = ev(BookingEventType.checkedIn);

    String who(BookingEvent e) {
      final p = personById(e.actorId);
      return '${p.displayName} · ${p.title ?? ''}';
    }

    final steps = <(String, String?, String?, _StepState)>[
      ('Demande envoyée', sent == null ? null : Fmt.dateTime(sent.at), null, _StepState.done),
      if (l1 != null)
        ('Validée par l’entité', '${who(l1)}\n${Fmt.dateTime(l1.at)}', l1.comment, _StepState.done)
      else if (refused != null && b.history.indexOf(refused) == 1)
        ('Refusée par l’entité', '${who(refused)}\n${Fmt.dateTime(refused.at)}', refused.comment, _StepState.failed)
      else if (cancelled != null)
        ('Annulée', Fmt.dateTime(cancelled.at), cancelled.comment, _StepState.failed)
      else
        ('En attente entité', level1Label(b.requesterType), null, _StepState.now),
      if (l1 != null)
        if (l2 != null)
          ('Validée par les Studios', '${who(l2)}\n${Fmt.dateTime(l2.at)}', l2.comment, _StepState.done)
        else if (refused != null)
          ('Refusée par les Studios', '${who(refused)}\n${Fmt.dateTime(refused.at)}', refused.comment, _StepState.failed)
        else if (cancelled != null)
          ('Annulée', Fmt.dateTime(cancelled.at), cancelled.comment, _StepState.failed)
        else
          ('En attente studio', level2Label, null, _StepState.now),
      if (l2 != null) ...[
        if (cancelled != null)
          ('Annulée', Fmt.dateTime(cancelled.at), cancelled.comment, _StepState.failed)
        else
          ('QR code disponible', 'Actif uniquement pendant le créneau', null, _StepState.done),
        if (checkIn != null)
          ('Entrée au studio', Fmt.dateTime(checkIn.at), null, _StepState.done),
      ] else if (refused == null && cancelled == null) ...[
        if (l1 == null) ('En attente studio', level2Label, null, _StepState.next),
        ('Validée · QR code', null, null, _StepState.next),
      ],
    ];

    final c = context.es;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      _Dot(state: steps[i].$4),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: steps[i].$4 == _StepState.done
                                ? c.successFill.withValues(alpha: 0.4)
                                : c.border,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$1,
                          style: EsText.titleS.copyWith(
                            color: switch (steps[i].$4) {
                              _StepState.next => c.textSecondary,
                              _StepState.failed => c.dangerText,
                              _ => c.textPrimary,
                            },
                          ),
                        ),
                        if (steps[i].$2 != null)
                          Text(
                            steps[i].$2!,
                            style: EsText.bodyS.copyWith(color: c.textSecondary),
                          ),
                        if (steps[i].$3 != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '« ${steps[i].$3!} »',
                              style: EsText.bodyS.copyWith(
                                color: steps[i].$4 == _StepState.failed
                                    ? c.dangerText
                                    : c.textGold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.state});
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (Color bg, Color fg, IconData? icon) = switch (state) {
      _StepState.done => (c.successBg, c.successText, Icons.check_rounded),
      _StepState.now => (c.pendingBg, c.pendingText, Icons.more_horiz_rounded),
      _StepState.failed => (c.dangerBg, c.dangerText, Icons.close_rounded),
      _StepState.next => (c.bgSubtle, c.textDisabled, null),
    };
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: state == _StepState.next
            ? Border.all(color: c.borderStrong, width: 1.5)
            : null,
      ),
      child: icon == null ? null : Icon(icon, size: 15, color: fg),
    );
  }
}
