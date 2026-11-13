/// In-app notifications, derived from the bookings' history.
///
/// Design (decision 0005): no separate notification table. Every booking
/// already keeps an append-only history (who did what, when). A person's
/// feed is computed from the bookings they may see, so the feed can never
/// disagree with the bookings, works the same offline and live, and needs
/// no extra writes. Only "read up to" is stored, per person.
library;

import '../bookings.dart';
import '../people.dart';
import 'approval.dart';
import 'sessions.dart';

enum NoticeKind { toDecide, approved, progress, refused, cancelled, reminder, assigned, closed }

class Notice {
  const Notice({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    required this.route,
    this.actionable = false,
  });

  /// Stable id: the same event always gives the same notice.
  final String id;
  final NoticeKind kind;
  final DateTime at;
  final String title;
  final String body;

  /// Where tapping the notice goes.
  final String route;

  /// Waits for this person to act (stays until handled).
  final bool actionable;
}

/// How long before a session the reminder appears.
const reminderLead = Duration(hours: 1);

/// Builds [person]'s feed, newest first.
///
/// [describe] turns a booking into "Studio Podcast · jeu. 16 nov. 10:00",
/// [nameOf] a person id into a display name (kept outside so this stays
/// pure and easy to test).
List<Notice> noticesFor(
  Person person,
  List<Booking> bookings,
  DateTime now, {
  required List<Person> people,
  required String Function(Booking) describe,
  required String Function(String personId) nameOf,
}) {
  final out = <Notice>[];
  final staff = person.has(Role.studioManager) ||
      person.has(Role.admin) ||
      person.has(Role.regisseur);

  for (final b in bookings) {
    if (b.isPrivate) continue;
    final what = describe(b);
    final mine = b.requesterId == person.id;

    // Requests waiting for this person's decision.
    if (b.status.isPending && canDecide(person, b, people: people)) {
      out.add(
        Notice(
          id: 'decide-${b.id}-${b.status.name}',
          kind: NoticeKind.toDecide,
          at: b.history.last.at,
          title: b.status == BookingStatus.pendingEntity
              ? 'Nouvelle demande à valider'
              : 'Demande à valider (niveau 2)',
          body: '${nameOf(b.requesterId)} · $what',
          route: '/validations/${b.id}',
          actionable: true,
        ),
      );
    }

    for (final e in b.history) {
      if (e.actorId == person.id) continue;
      final id = '${b.id}-${e.type.name}-${e.at.millisecondsSinceEpoch}';
      if (mine) {
        final n = switch (e.type) {
          BookingEventType.entityApproved => (
              NoticeKind.progress,
              'Étape 1 validée',
              'Votre demande passe à la Direction des Studios. $what',
            ),
          BookingEventType.studioApproved => (
              NoticeKind.approved,
              'Séance validée',
              'Votre QR code d’accès est prêt. $what',
            ),
          BookingEventType.refused => (
              NoticeKind.refused,
              'Demande refusée',
              'Motif : ${e.comment ?? b.refusalReason ?? '—'}',
            ),
          BookingEventType.cancelled => (
              NoticeKind.cancelled,
              'Séance annulée par l’administration',
              e.comment ?? what,
            ),
          BookingEventType.completed => (
              NoticeKind.closed,
              'Séance terminée',
              'Merci ! $what',
            ),
          BookingEventType.noShow => (
              NoticeKind.cancelled,
              'Absence notée',
              'Vous ne vous êtes pas présenté·e. $what',
            ),
          _ => null,
        };
        if (n != null) {
          out.add(
            Notice(
              id: id,
              kind: n.$1,
              at: e.at,
              title: n.$2,
              body: n.$3,
              route: '/bookings/${b.id}',
            ),
          );
        }
      } else if (e.type == BookingEventType.studioApproved &&
          b.technicianId == person.id) {
        out.add(
          Notice(
            id: id,
            kind: NoticeKind.assigned,
            at: e.at,
            title: 'Vous êtes affecté·e à une séance',
            body: '${nameOf(b.requesterId)} · $what',
            route: '/bookings/${b.id}',
          ),
        );
      } else if (staff &&
          e.type == BookingEventType.cancelled &&
          b.history.any((x) => x.type == BookingEventType.studioApproved)) {
        out.add(
          Notice(
            id: id,
            kind: NoticeKind.cancelled,
            at: e.at,
            title: 'Séance validée annulée',
            body: '${nameOf(b.requesterId)} · $what · le créneau est libre',
            route: '/bookings/${b.id}',
          ),
        );
      }
    }

    // Reminder one hour before a validated session.
    final soon = b.start.subtract(reminderLead);
    if (b.status == BookingStatus.approved &&
        !now.isBefore(soon) &&
        now.isBefore(b.start) &&
        (mine || (b.technicianId == person.id)) &&
        !isCheckedIn(b)) {
      out.add(
        Notice(
          id: 'remind-${b.id}',
          kind: NoticeKind.reminder,
          at: soon,
          title: mine ? 'Votre séance commence bientôt' : 'Séance à préparer',
          body: mine
              ? '$what · pensez à votre QR code.'
              : '${nameOf(b.requesterId)} · $what',
          route: mine ? '/qr/${b.id}' : '/bookings/${b.id}',
        ),
      );
    }
  }

  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
}

/// Unread = newer than the last time this person opened the feed (or, if
/// they never did, from the last 24 hours). Requests waiting for a decision
/// count until they are handled.
bool isUnread(Notice n, DateTime? seenAt, DateTime now) =>
    n.actionable ||
    n.at.isAfter(seenAt ?? now.subtract(const Duration(hours: 24)));

int unreadCount(List<Notice> feed, DateTime? seenAt, DateTime now) =>
    feed.where((n) => isUnread(n, seenAt, now)).length;
