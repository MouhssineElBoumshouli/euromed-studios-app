import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/demo_mode.dart';
import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/app_state.dart';
import '../../data/demo_world.dart';
import '../../domain/bookings.dart';

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
    final now = simulateSessionTime
        ? b.start.add(const Duration(minutes: 18))
        : w.now;
    final win = b.status == BookingStatus.approved
        ? qrWindow(b, now, w.policy.qrGraceMinutes)
        : QrWindow.over;
    final active = win == QrWindow.active;
    final minutesLeft = b.end.difference(now).inMinutes;

    final (String label, Color bg, Color fg) = switch (win) {
      QrWindow.active => (
          'Actif · se termine dans ${minutesLeft ~/ 60 > 0 ? '${minutesLeft ~/ 60} h ' : ''}${minutesLeft % 60} min',
          c.successBg,
          c.successText,
        ),
      QrWindow.notYet => (
          'S’active ${Fmt.relativeDay(b.start, now).toLowerCase()} à ${Fmt.time(b.start)}',
          c.pendingBg,
          c.pendingText,
        ),
      QrWindow.over => ('Créneau terminé', c.neutralBg, c.neutralText),
    };

    return Scaffold(
      backgroundColor: c.bgBrand,
      body: CustomPaint(
        painter: ZelligePainter(color: c.brandAccent),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton.filled(
                  tooltip: 'Fermer',
                  style: IconButton.styleFrom(
                    backgroundColor: c.bgBrandRaised,
                    foregroundColor: c.textOnBrand,
                  ),
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Overline('Accès studio', onBrand: true)),
              const SizedBox(height: 6),
              Text(
                s.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: EsText.displayL.copyWith(color: c.textOnBrand),
              ),
              Text(
                '${Fmt.relativeDay(b.start, w.now)} · '
                '${Fmt.range(b.start, b.end)} · ${room.name}',
                textAlign: TextAlign.center,
                style: EsText.bodyM.copyWith(color: c.textOnBrandMuted),
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c.bgSurface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Semantics(
                        label: active
                            ? 'QR code d’accès actif'
                            : 'QR code d’accès, pas encore actif',
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: active ? 1 : 0.18,
                          child: QrImageView(
                            data: 'ESTUDIOS|${b.reference}|${b.id}|'
                                '${b.start.toIso8601String()}|'
                                '${b.end.toIso8601String()}',
                            size: 232,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF0A1230),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF0A1230),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${me.fullName} · ${b.reference}',
                        style: EsText.titleS.copyWith(color: c.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Tag(label: label, background: bg, foreground: fg, dot: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                active
                    ? 'Présentez ce code au régisseur à l’entrée. Il fonctionne '
                        'aussi hors connexion.'
                    : 'Le code ne fonctionne que pendant votre créneau. Il '
                        's’affichera ici automatiquement.',
                textAlign: TextAlign.center,
                style: EsText.bodyM.copyWith(color: c.textOnBrandMuted),
              ),
              if (kDemoMode && b.status == BookingStatus.approved) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: c.brandAccent),
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
      ),
    );
  }
}
