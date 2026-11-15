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
  });

  factory RulesDraft.of(Policy p) => RulesDraft(
        openingHour: p.openingHour,
        closingHour: p.closingHour,
        slotMinutes: p.slotMinutes,
        maxAdvanceDays: p.maxAdvanceDays,
        studentQuotaMinutes: p.quotaFor(RequesterType.student) ?? 120,
        qrGraceMinutes: p.qrGraceMinutes,
      );

  final int openingHour;
  final int closingHour;
  final int slotMinutes;
  final int maxAdvanceDays;
  final int studentQuotaMinutes;
  final int qrGraceMinutes;

  RulesDraft copyWith({
    int? openingHour,
    int? closingHour,
    int? slotMinutes,
    int? maxAdvanceDays,
    int? studentQuotaMinutes,
    int? qrGraceMinutes,
  }) =>
      RulesDraft(
        openingHour: openingHour ?? this.openingHour,
        closingHour: closingHour ?? this.closingHour,
        slotMinutes: slotMinutes ?? this.slotMinutes,
        maxAdvanceDays: maxAdvanceDays ?? this.maxAdvanceDays,
        studentQuotaMinutes: studentQuotaMinutes ?? this.studentQuotaMinutes,
        qrGraceMinutes: qrGraceMinutes ?? this.qrGraceMinutes,
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
  if (d.studentQuotaMinutes < 30 ||
      d.studentQuotaMinutes > 2400 ||
      d.studentQuotaMinutes % 30 != 0) {
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

/// What changes, in the same words as the activity log.
List<String> rulesChanges(RulesDraft a, RulesDraft b) => [
      if (a.openingHour != b.openingHour || a.closingHour != b.closingHour)
        'Horaires : ${a.openingHour}h–${a.closingHour}h → '
            '${b.openingHour}h–${b.closingHour}h',
      if (a.slotMinutes != b.slotMinutes)
        'Créneaux : ${a.slotMinutes} → ${b.slotMinutes} min',
      if (a.maxAdvanceDays != b.maxAdvanceDays)
        'Réservation jusqu’à ${a.maxAdvanceDays} → ${b.maxAdvanceDays} jours',
      if (a.studentQuotaMinutes != b.studentQuotaMinutes)
        'Quota étudiant : ${_h(a.studentQuotaMinutes)} → '
            '${_h(b.studentQuotaMinutes)} h/semaine',
      if (a.qrGraceMinutes != b.qrGraceMinutes)
        'Accès avant la séance : ${a.qrGraceMinutes} → '
            '${b.qrGraceMinutes} min',
    ];

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

String? charterVersionProblem(String version, String current) {
  final v = version.trim();
  if (!RegExp(r'^[0-9]+(\.[0-9]+){0,2}$').hasMatch(v)) return 'bad_version';
  if (v == current) return 'same_version';
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
      _ => 'Le changement n’a pas pu être enregistré. Réessayez.',
    };
