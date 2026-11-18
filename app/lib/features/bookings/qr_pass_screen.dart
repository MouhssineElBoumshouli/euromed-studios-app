import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/demo_mode.dart';
import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/logo.dart';
import '../../data/app_state.dart';
import '../../data/demo_world.dart';
import '../../domain/bookings.dart';
import '../../core/l10n/text.dart';

enum QrWindow { notYet, active, over }

/// When the QR works: from the slot start to its end, plus the grace
/// period set by the admin (P-10, Q10).
QrWindow qrWindow(Booking b, DateTime now, int graceMinutes) {
  final from = b.start.subtract(Duration(minutes: graceMinutes));
  final to = b.end.add(Duration(minutes: graceMinutes));
  if (now.isBefore(from)) return QrWindow.notYet;
  if (!now.isBefore(to)) return QrWindow.over;
  return QrWindow.active;
}

/// E3 · Access QR code (R-28). Shown full screen on navy.
///
/// The code holds a reference and a validity window; the régisseur's
/// scanner checks it against the server (and works offline from the
/// day's list, Q10).
class QrPassScreen extends ConsumerStatefulWidget {
  const QrPassScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<QrPassScreen> createState() => _QrPassState();
}

class _QrPassState extends ConsumerState<QrPassScreen> {
  /// Demo only: pretend we're at the session time to see the active code.
  bool simulateSessionTime = false;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final b = w.bookings.firstWhere((x) => x.id == widget.bookingId);
    final s = studioById(b.studioId);
    final me = personById(b.requesterId);
    final room = DemoWorld.rooms.firstWhere((r) => r.id == s.roomId);
    final now =
        simulateSessionTime ? b.start.add(const Duration(minutes: 18)) : w.now;
    final win = b.status == BookingStatus.approved
        ? qrWindow(b, now, w.policy.qrGraceMinutes)
        : QrWindow.over;
    final active = win == QrWindow.active;
    final minutesLeft = b.end.difference(now).inMinutes;

    final (String label, Color bg, Color fg) = switch (win) {
      QrWindow.active => (
          'Actif · se termine dans ${minutesLeft ~/ 60 > 0 ? '${minutesLeft ~/ 60} h ' : ''}${minutesLeft % 60} min',
          EsColors.light.successBg,
          EsColors.light.successText,
        ),
      QrWindow.notYet => (
          'S’active ${tr(Fmt.relativeDay(b.start, now)).toLowerCase()} à ${Fmt.time(b.start)}',
          EsColors.light.pendingBg,
          EsColors.light.pendingText,
        ),
      QrWindow.over => (
          'Créneau terminé',
          EsColors.light.neutralBg,
          EsColors.light.neutralText,
        ),
    };

    final ticket = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EsRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 110,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(s.photo, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF0E1433).withValues(alpha: 0.88),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PASS STUDIO',
                              style: EsText.overline
                                  .copyWith(color: c.brandAccent),
                            ),
                            Text(
                              s.name,
                              style:
                                  EsText.titleL.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const EuromedStudiosLogo(height: 40, wordmark: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Row(
              children: [
                _TicketFact('Date', Fmt.shortDay(b.start)),
                _TicketFact('Horaire', Fmt.range(b.start, b.end)),
                _TicketFact('Salle', room.name),
              ],
            ),
          ),
          const _Perforation(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Column(
              children: [
                Semantics(
                  label: tr(active
                      ? 'QR code d’accès actif'
                      : 'QR code d’accès, pas encore actif'),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedOpacity(
                        duration: EsMotion.medium,
                        opacity: active ? 1 : 0.12,
                        child: QrImageView(
                          data: 'ESTUDIOS|${b.reference}|${b.id}|'
                              '${b.start.toIso8601String()}|'
                              '${b.end.toIso8601String()}',
                          size: 210,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF0E1433),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0E1433),
                          ),
                        ),
                      ),
                      if (!active)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEFF1F8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_clock_outlined,
                            size: 30,
                            color: Color(0xFF1C2B6B),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Tag(label: label, background: bg, foreground: fg, dot: true),
                const SizedBox(height: 12),
                Text(
                  me.fullName,
                  style: EsText.titleS.copyWith(color: const Color(0xFF0E1433)),
                ),
                Text(
                  'Réf. ${b.reference} · personnel, non partageable',
                  style: EsText.bodyS.copyWith(color: const Color(0xFF5B6180)),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: c.bgBrand,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.bgBrandRaised.withValues(alpha: 0.7),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -120,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.bgBrandRaised.withValues(alpha: 0.5),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                EsSpace.page,
                8,
                EsSpace.page,
                EsSpace.s6,
              ),
              children: [
                Row(
                  children: [
                    EsBackButton(
                      close: true,
                      label: null,
                      onDark: true,
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    Text(
                      'Mon accès',
                      style: EsText.titleM.copyWith(color: c.textOnBrand),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: EsSpace.s5),
                FadeInUp(child: ticket),
                const SizedBox(height: EsSpace.s5),
                Text(
                  active
                      ? 'Présentez ce code au régisseur à l’entrée. Il '
                          'fonctionne aussi hors connexion.'
                      : 'Le code ne fonctionne que pendant votre créneau. '
                          'Il s’activera ici automatiquement.',
                  textAlign: TextAlign.center,
                  style: EsText.bodyM.copyWith(color: c.textOnBrandMuted),
                ),
                if (kDemoMode && b.status == BookingStatus.approved) ...[
                  const SizedBox(height: EsSpace.s3),
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: c.brandAccent,
                      ),
                      onPressed: () => setState(
                        () => simulateSessionTime = !simulateSessionTime,
                      ),
                      icon: const Icon(Icons.fast_forward_rounded),
                      label: Text(
                        simulateSessionTime
                            ? 'Démo : revenir à maintenant'
                            : 'Démo : avancer à l’heure de la séance',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketFact extends StatelessWidget {
  const _TicketFact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: EsText.bodyS.copyWith(color: const Color(0xFF5B6180)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            style: EsText.titleS.copyWith(
              color: const Color(0xFF0E1433),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// The torn-ticket line between details and the code.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    final bg = context.es.bgBrand;
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Transform.translate(
            offset: const Offset(-12, 0),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < (box.maxWidth / 12).floor(); i++)
                    Container(
                      width: 6,
                      height: 2,
                      color: const Color(0xFFD5D9E8),
                    ),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(12, 0),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}
