/// I4–I7 · Checks for the rules an admin can change. The server functions
/// (update_settings, add_maintenance, publish_charter) apply the same ones.
library;

import '../bookings.dart';
import '../people.dart';
import '../policy.dart';

/// The editable part of the rules.
class RulesDraft {
  const RulesDraft({
    required this.openingHour,
    required this.closingHour,
    required this.slotMinutes,
    required this.maxAdvanceDays,
    required this.studentQuotaMinutes,
    required this.qrGraceMinutes,
    this.limitQuota = true,
  });

  factory RulesDraft.of(Policy p) => RulesDraft(
        openingHour: p.openingHour,
        closingHour: p.closingHour,
        slotMinutes: p.slotMinutes,
        maxAdvanceDays: p.maxAdvanceDays,
        // With no limit, the stepper starts from 2 h if it is turned on.
        studentQuotaMinutes: p.quotaFor(RequesterType.student) ?? 120,
        limitQuota: p.quotaFor(RequesterType.student) != null,
        qrGraceMinutes: p.qrGraceMinutes,
      );

  final int openingHour;
  final int closingHour;
  final int slotMinutes;
  final int maxAdvanceDays;
  final int studentQuotaMinutes;
  final int qrGraceMinutes;

  /// False = students have no weekly limit.
  final bool limitQuota;

  /// The weekly student limit to save, or null for no limit.
  int? get studentQuota => limitQuota ? studentQuotaMinutes : null;

  RulesDraft copyWith({
    int? openingHour,
    int? closingHour,
    int? slotMinutes,
    int? maxAdvanceDays,
    int? studentQuotaMinutes,
    int? qrGraceMinutes,
    bool? limitQuota,
  }) =>
      RulesDraft(
        openingHour: openingHour ?? this.openingHour,
        closingHour: closingHour ?? this.closingHour,
        slotMinutes: slotMinutes ?? this.slotMinutes,
        maxAdvanceDays: maxAdvanceDays ?? this.maxAdvanceDays,
        studentQuotaMinutes: studentQuotaMinutes ?? this.studentQuotaMinutes,
        qrGraceMinutes: qrGraceMinutes ?? this.qrGraceMinutes,
        limitQuota: limitQuota ?? this.limitQuota,
      );
}

const allowedSlotMinutes = [30, 60, 120];

String? rulesProblem(RulesDraft d) {
  if (d.openingHour < 6 || d.closingHour > 23 || d.openingHour >= d.closingHour) {
    return 'bad_hours';
  }
  if (!allowedSlotMinutes.contains(d.slotMinutes)) return 'bad_slot';
  if (((d.closingHour - d.openingHour) * 60) % d.slotMinutes != 0) {
    return 'slot_misfit';
  }
  if (d.maxAdvanceDays < 1 || d.maxAdvanceDays > 180) return 'bad_advance';
  if (d.limitQuota &&
      (d.studentQuotaMinutes < 30 ||
          d.studentQuotaMinutes > 2400 ||
          d.studentQuotaMinutes % 30 != 0)) {
    return 'bad_quota';
  }
  if (d.qrGraceMinutes < 0 || d.qrGraceMinutes > 60) return 'bad_grace';
  return null;
}

String _h(int minutes) {
  final h = minutes / 60;
  return h == h.roundToDouble()
      ? '${h.round()}'
      : h.toStringAsFixed(1).replaceAll('.', ',');
}

String _quota(int? minutes) =>
    minutes == null ? 'sans limite' : '${_h(minutes)} h/semaine';

/// What changes, in the same words as the activity log.
List<String> rulesChanges(RulesDraft a, RulesDraft b) => [
      if (a.openingHour != b.openingHour || a.closingHour != b.closingHour)
        'Horaires : ${a.openingHour}h–${a.closingHour}h → '
            '${b.openingHour}h–${b.closingHour}h',
      if (a.slotMinutes != b.slotMinutes)
        'Créneaux : ${a.slotMinutes} → ${b.slotMinutes} min',
      if (a.maxAdvanceDays != b.maxAdvanceDays)
        'Réservation jusqu’à ${a.maxAdvanceDays} → ${b.maxAdvanceDays} jours',
      if (a.studentQuota != b.studentQuota)
        'Quota étudiant : ${_quota(a.studentQuota)} → '
            '${_quota(b.studentQuota)}',
      if (a.qrGraceMinutes != b.qrGraceMinutes)
        'Accès avant la séance : ${a.qrGraceMinutes} → '
            '${b.qrGraceMinutes} min',
    ];

/// Upcoming sessions (approved or waiting) that would no longer fit the
/// new opening hours or slot grid. They are kept, but staff should know.
List<Booking> sessionsOutside(
  List<Booking> bookings,
  DateTime now,
  RulesDraft d,
) =>
    [
      for (final b in bookings)
        if (b.end.isAfter(now) &&
            (b.status == BookingStatus.approved || b.status.isPending) &&
            !_fits(b, d))
          b,
    ];

bool _fits(Booking b, RulesDraft d) {
  final from = b.start.hour * 60 + b.start.minute;
  final to = b.end.hour * 60 + b.end.minute;
  return dateOnlyEq(b.start, b.end) &&
      from >= d.openingHour * 60 &&
      to <= d.closingHour * 60 &&
      (from - d.openingHour * 60) % d.slotMinutes == 0;
}

bool dateOnlyEq(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String? maintenanceProblem({
  required Person by,
  required DateTime start,
  required DateTime end,
  required String reason,
  required DateTime now,
  required List<MaintenanceBlock> existing,
}) {
  if (!(by.has(Role.admin) || by.has(Role.studioManager))) {
    return 'not_allowed';
  }
  if (!end.isAfter(start)) return 'bad_period';
  if (end.isBefore(now)) return 'in_the_past';
  if (end.difference(start) > const Duration(days: 60)) return 'too_long';
  final r = reason.trim();
  if (r.length < 3 || r.length > 200) return 'reason_required';
  if (existing.any((m) => m.start.isBefore(end) && start.isBefore(m.end))) {
    return 'overlap';
  }
  return null;
}

/// The largest quantity of [itemId] promised at the same moment by
/// upcoming sessions (approved or waiting), across every room.
int equipmentPeak(List<Booking> bookings, String itemId, DateTime now) {
  final events = <(DateTime, int)>[];
  for (final b in bookings) {
    if (!b.end.isAfter(now) ||
        !(b.status == BookingStatus.approved || b.status.isPending)) {
      continue;
    }
    var q = 0;
    for (final e in b.equipment) {
      if (e.itemId == itemId) q += e.quantity;
    }
    if (q == 0) continue;
    events
      ..add((b.start, q))
      ..add((b.end, -q));
  }
  // At the same instant, an end comes before a start.
  events.sort((a, b) {
    final t = a.$1.compareTo(b.$1);
    return t != 0 ? t : a.$2.compareTo(b.$2);
  });
  var running = 0, top = 0;
  for (final (_, d) in events) {
    running += d;
    if (running > top) top = running;
  }
  return top;
}

/// "2.1" → [2, 1, 0], so versions compare as numbers (2.10 > 2.9).
List<int> versionKey(String v) {
  final parts = [for (final p in v.trim().split('.')) int.tryParse(p) ?? 0];
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts.take(3).toList();
}

int compareVersions(String a, String b) {
  final x = versionKey(a), y = versionKey(b);
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return 0;
}

String? charterVersionProblem(String version, String current) {
  final v = version.trim();
  if (!RegExp(r'^[0-9]{1,4}(\.[0-9]{1,4}){0,2}$').hasMatch(v)) {
    return 'bad_version';
  }
  final c = compareVersions(v, current);
  if (c == 0) return 'same_version';
  if (c < 0) return 'older_version';
  return null;
}

String adminProblemText(String code) => switch (code) {
      'not_allowed' => 'Seule l’administration peut faire ce changement.',
      'bad_hours' => 'L’ouverture doit précéder la fermeture (entre 6 h et '
          '23 h).',
      'bad_slot' => 'Durée de créneau : 30 min, 1 h ou 2 h.',
      'slot_misfit' => 'La journée doit contenir un nombre entier de '
          'créneaux.',
      'bad_advance' => 'Fenêtre de réservation : entre 1 et 180 jours.',
      'bad_quota' => 'Quota : entre 30 min et 40 h, par pas de 30 min.',
      'bad_grace' => 'Accès anticipé : entre 0 et 60 minutes.',
      'bad_period' => 'La fin doit être après le début.',
      'in_the_past' => 'Cette période est déjà passée.',
      'too_long' => 'Une fermeture dure au plus 60 jours.',
      'reason_required' => 'Indiquez la raison de la fermeture.',
      'overlap' => 'Une fermeture est déjà prévue sur ce créneau.',
      'bad_stock' => 'Le stock doit être entre 0 et 999.',
      'bad_version' => 'Numéro de version : par exemple 2.0 ou 2.1.',
      'same_version' => 'C’est déjà la version en vigueur.',
      'older_version' => 'La nouvelle version doit être plus récente que '
          'celle en vigueur.',
      'network' => 'Pas de connexion. Vérifiez le réseau et réessayez.',
      _ => 'Le changement n’a pas pu être enregistré. Réessayez.',
    };
