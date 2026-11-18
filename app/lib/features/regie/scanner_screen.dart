import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../data/app_state.dart';
import '../../data/booking_service.dart';
import '../../domain/bookings.dart';
import '../../domain/rules/sessions.dart';
import 'regie_screen.dart';
import '../../core/l10n/text.dart';

/// H2 · Door check: scan the person's QR pass (or type its reference),
/// see at once if they may come in, and let them in.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerState();
}

class _ScannerState extends ConsumerState<ScannerScreen> {
  final controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final reference = TextEditingController();
  String? scanned;
  bool busy = false;

  @override
  void dispose() {
    controller.dispose();
    reference.dispose();
    super.dispose();
  }

  /// Finds the booking a QR or a typed reference points to.
  Booking? _lookup(String raw, List<Booking> all) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    final parts = v.split('|');
    if (parts.length >= 3 && parts.first == 'ESTUDIOS') {
      return all.where((b) => b.id == parts[2]).firstOrNull;
    }
    return all
        .where((b) => b.reference.toUpperCase() == v.toUpperCase())
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    if (!canOperate(ref.watch(currentPersonProvider))) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Réservé à la régie',
          message: 'Seule l’équipe des studios peut contrôler les accès.',
        ),
      );
    }
    final found = scanned == null ? null : _lookup(scanned!, w.bookings);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Navy screen: light status and navigation icons.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: c.bgBrand,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    EsBackButton(
                      close: true,
                      label: null,
                      onDark: true,
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/regie'),
                    ),
                    const Spacer(),
                    Text(
                      'Contrôle d’accès',
                      style: EsText.titleM.copyWith(color: c.textOnBrand),
                    ),
                    const Spacer(),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(EsRadius.xl),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: controller,
                          onDetect: (capture) {
                            final v = capture.barcodes.firstOrNull?.rawValue;
                            if (v != null && v != scanned) {
                              setState(() => scanned = v);
                            }
                          },
                          errorBuilder: (context, error) => ColoredBox(
                            color: c.bgBrandRaised,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Caméra indisponible. Autorisez la caméra, '
                                  'ou saisissez la référence ci-dessous.',
                                  textAlign: TextAlign.center,
                                  style: EsText.bodyM
                                      .copyWith(color: c.textOnBrandMuted),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Center(
                            child: Container(
                              width: 230,
                              height: 230,
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.bgSurface,
                  borderRadius: BorderRadius.circular(EsRadius.xl),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedSize(
                      duration: EsMotion.medium,
                      child: scanned == null
                          ? Text(
                              'Placez le QR code du demandeur dans le cadre.',
                              style:
                                  EsText.bodyM.copyWith(color: c.textSecondary),
                            )
                          : _Result(
                              booking: found,
                              now: w.now,
                              busy: busy,
                              early: w.policy.qrGraceMinutes,
                              onCheckIn:
                                  found == null ? null : () => _checkIn(found),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: reference,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: tr('Ou référence : ES-2026-0147'),
                              isDense: true,
                            ),
                            onSubmitted: (v) => setState(() => scanned = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: tr('Vérifier'),
                          style: IconButton.styleFrom(
                            backgroundColor: c.actionPrimary,
                            foregroundColor: c.onActionPrimary,
                            fixedSize: const Size(48, 48),
                          ),
                          onPressed: () =>
                              setState(() => scanned = reference.text),
                          icon: const Icon(Icons.search_rounded),
                        ),
                      ],
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

  Future<void> _checkIn(Booking b) async {
    setState(() => busy = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(bookingServiceProvider)
          .checkIn(b.id, by: ref.read(currentPersonProvider));
      m.showSnackBar(
        SnackBar(
            content:
                Text('${personById(b.requesterId).fullName} est entré·e.')),
      );
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(sessionError(e))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.booking,
    required this.now,
    required this.busy,
    required this.onCheckIn,
    required this.early,
  });
  final int early;
  final Booking? booking;
  final DateTime now;
  final bool busy;
  final VoidCallback? onCheckIn;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final b = booking;
    if (b == null) {
      return const InfoBanner(
        tone: BannerTone.danger,
        title: 'Code inconnu',
        text: 'Aucune réservation ne correspond. Vérifiez la référence.',
      );
    }
    final problem = checkInProblem(b, now, earlyMinutes: early);
    final inside = isCheckedIn(b);
    final ok = problem == null;
    final s = studioById(b.studioId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: ok || inside ? c.successBg : c.dangerBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                ok || inside ? Icons.check_rounded : Icons.close_rounded,
                color: ok || inside ? c.successText : c.dangerText,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    personById(b.requesterId).fullName,
                    style: EsText.titleM.copyWith(color: c.textPrimary),
                  ),
                  Text(
                    '${s.name} · ${Fmt.range(b.start, b.end)} · ${b.reference}',
                    style: EsText.bodyS.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (ok)
          EsButton(
            'Enregistrer l’arrivée',
            icon: Icons.login_rounded,
            loading: busy,
            onPressed: onCheckIn,
          )
        else
          InfoBanner(
            tone: inside ? BannerTone.success : BannerTone.danger,
            text: inside ? 'Déjà entré·e. Bonne séance !' : problem,
          ),
      ],
    );
  }
}
