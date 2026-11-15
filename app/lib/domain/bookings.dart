/// Bookings, their statuses and history (R-10 to R-20, P-04, P-05, P-11).
library;

import 'people.dart';

/// The activity the requester must choose (R-11).
enum Activity {
  recording('Enregistrement'),
  filming('Captation d’image'),
  editing('Montage'),
  mixing('Mixage audio');

  const Activity(this.label);
  final String label;
}

/// Request status. The first three are the CdC's statuses (R-20).
enum BookingStatus {
  pendingEntity('En attente entité'),
  pendingStudio('En attente studio'),
  approved('Validée'),
  refused('Refusée'),
  cancelled('Annulée'),
  completed('Terminée'),
  noShow('Absence');

  const BookingStatus(this.label);
  final String label;

  /// Statuses that keep the slot locked for everyone (R-15).
  bool get holdsSlot =>
      this == pendingEntity || this == pendingStudio || this == approved;

  bool get isPending => this == pendingEntity || this == pendingStudio;
}

enum BookingEventType {
  submitted('Demande envoyée'),
  entityApproved('Validée par l’entité'),
  studioApproved('Validée par les Studios'),
  refused('Refusée'),
  cancelled('Annulée'),
  checkedIn('Entrée au studio'),
  completed('Séance terminée'),
  noShow('Absence constatée');

  const BookingEventType(this.label);
  final String label;
}

/// One line of a booking's history. Also serves as the audit trail (P-11).
class BookingEvent {
  const BookingEvent({
    required this.type,
    required this.at,
    required this.actorId,
    this.comment,
  });
  final BookingEventType type;
  final DateTime at;
  final String actorId;
  final String? comment;
}

class EquipmentItem {
  const EquipmentItem({
    required this.id,
    required this.name,
    required this.detail,
    required this.icon,
    required this.stock,
  });
  final String id;
  final String name;
  final String detail;

  /// Name of an icon in our icon set (see core/widgets/es_icons.dart).
  final String icon;
  final int stock;

  EquipmentItem withStock(int value) => EquipmentItem(
        id: id,
        name: name,
        detail: detail,
        icon: icon,
        stock: value,
      );
}

/// What the technical validator decided for an item (P-04, P-05).
enum EquipmentOutcome { pending, confirmed, substituted, unavailable }

class EquipmentRequest {
  const EquipmentRequest({
    required this.itemId,
    required this.quantity,
    required this.required,
    this.outcome = EquipmentOutcome.pending,
    this.note,
  });
  final String itemId;
  final int quantity;

  /// Must-have ("Indispensable") or nice-to-have ("Souhaité").
  final bool required;
  final EquipmentOutcome outcome;
  final String? note;

  EquipmentRequest copyWith({EquipmentOutcome? outcome, String? note}) =>
      EquipmentRequest(
        itemId: itemId,
        quantity: quantity,
        required: required,
        outcome: outcome ?? this.outcome,
        note: note ?? this.note,
      );
}

class Booking {
  const Booking({
    required this.id,
    required this.reference,
    required this.requesterId,
    required this.requesterType,
    required this.studioId,
    required this.start,
    required this.end,
    required this.activity,
    required this.status,
    required this.history,
    this.establishmentId,
    this.clubId,
    this.projectId,
    this.note,
    this.equipment = const [],
    this.technicianId,
    this.refusalReason,
    this.isPrivate = false,
  });

  final String id;

  /// Human reference shown to users, e.g. ES-2026-0142.
  final String reference;
  final String requesterId;
  final RequesterType requesterType;
  final String? establishmentId;
  final String? clubId;
  final String studioId;
  final DateTime start;
  final DateTime end;
  final Activity activity;
  final BookingStatus status;
  final List<BookingEvent> history;
  final String? projectId;
  final String? note;
  final List<EquipmentRequest> equipment;
  final String? technicianId;
  final String? refusalReason;

  /// Someone else's booking that this person may not see in detail: only
  /// its time and room are known (they still block the slot).
  final bool isPrivate;

  Duration get duration => end.difference(start);

  bool overlaps(DateTime s, DateTime e) => start.isBefore(e) && s.isBefore(end);

  Booking copyWith({
    BookingStatus? status,
    List<BookingEvent>? history,
    List<EquipmentRequest>? equipment,
    String? technicianId,
    String? refusalReason,
  }) =>
      Booking(
        id: id,
        reference: reference,
        requesterId: requesterId,
        requesterType: requesterType,
        establishmentId: establishmentId,
        clubId: clubId,
        studioId: studioId,
        start: start,
        end: end,
        activity: activity,
        status: status ?? this.status,
        history: history ?? this.history,
        projectId: projectId,
        note: note,
        equipment: equipment ?? this.equipment,
        technicianId: technicianId ?? this.technicianId,
        refusalReason: refusalReason ?? this.refusalReason,
        isPrivate: isPrivate,
      );
}

/// A period when a room is closed for maintenance.
class MaintenanceBlock {
  const MaintenanceBlock({
    required this.roomId,
    required this.start,
    required this.end,
    required this.reason,
    this.id = '',
  });

  /// Server id (empty for the built-in demo closure).
  final String id;
  final String roomId;
  final DateTime start;
  final DateTime end;
  final String reason;
}
