/// In-app notifications, derived from the bookings' history.
///
/// Design (decision 0005): no separate notification table. Every booking
/// already keeps an append-only history (who did what, when). A person's
/// feed is computed from the bookings they may see, so the feed can never
/// disagree with the bookings, works the same offline and live, and needs
/// no extra writes. Only "read up to" is stored, per person.
library;

import '../../core/l10n/tr.dart';
import '../bookings.dart';
import '../people.dart';
import '../projects.dart';
import 'approval.dart';
import 'projects.dart';
import 'sessions.dart';

enum NoticeKind {
  toDecide,
  approved,
  progress,
  refused,
  cancelled,
  reminder,
  assigned,
  closed,
  invite,
  project,
}

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
    late final what = describe(b);
    // Old history isn't news: keep 30 days (waiting decisions always stay).
    final since = now.subtract(const Duration(days: 30));
    final mine = b.requesterId == person.id;

    // Requests waiting for this person's decision.
    if (b.status.isPending &&
        b.history.last.actorId != person.id &&
        canDecide(person, b, people: people)) {
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

    final wasValidated =
        b.history.any((x) => x.type == BookingEventType.studioApproved);
    for (final e in b.history) {
      if (e.actorId == person.id || e.at.isBefore(since)) continue;
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
          wasValidated) {
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

/// Project news for [person], newest first (R-24, R-25, R-27).
///
/// Built from the projects' history and the invitations, like the
/// bookings feed: nothing extra to store.
List<Notice> projectNoticesFor(
  Person person,
  List<Project> projects,
  List<ProjectInvite> invites,
  DateTime now, {
  List<ProjectMessage> messages = const [],
  required String Function(String personId) nameOf,
}) {
  final out = <Notice>[];
  final since = now.subtract(const Duration(days: 30));

  for (final i in invites) {
    if (i.inviteeId == person.id && i.status == InviteStatus.pending) {
      out.add(
        Notice(
          id: 'invite-${i.id}',
          kind: NoticeKind.invite,
          at: i.at,
          title: 'Invitation à un projet',
          body: '${nameOf(i.invitedBy)} vous invite sur « ${i.projectTitle} ».',
          route: '/projects',
          actionable: true,
        ),
      );
    }
  }

  for (final p in projects) {
    final mine = p.involves(person.id);
    final follows = followsEdit(person, p, messages);
    if (!mine && !follows) continue;

    // Waiting for the quality check: the editors, or the studio manager.
    if (follows && canQualityCheck(person, p)) {
      final ready = p.history.lastWhere(
        (e) => e.type == ProjectEventType.postStatus,
        orElse: () => ProjectEvent(
          type: ProjectEventType.postStatus,
          at: p.createdAt,
          actorId: '',
        ),
      );
      out.add(
        Notice(
          id: 'qc-${p.id}-${ready.at.millisecondsSinceEpoch}',
          kind: NoticeKind.toDecide,
          at: ready.at,
          title: 'Contrôle qualité à faire',
          body: '« ${p.title} » est prêt à être vérifié.',
          route: '/projects/${p.id}',
          actionable: true,
        ),
      );
    }

    for (final e in p.history) {
      if (e.actorId == person.id || e.at.isBefore(since)) continue;
      final id = '${p.id}-${e.type.name}-${e.at.millisecondsSinceEpoch}';
      final n = switch (e.type) {
        ProjectEventType.postStatus when mine => (
            NoticeKind.progress,
            e.detail == PostStatus.readyForCheck.name
                ? 'Montage terminé'
                : 'Montage en cours',
            e.detail == PostStatus.readyForCheck.name
                ? '« ${p.title} » passe au contrôle qualité.'
                : 'L’équipe technique travaille sur « ${p.title} ».',
          ),
        ProjectEventType.qcPassed when mine => (
            NoticeKind.approved,
            'Projet validé et livré',
            'Le fichier final de « ${p.title} » est disponible.',
          ),
        ProjectEventType.qcFailed when mine => (
            NoticeKind.refused,
            'Contrôle qualité : à reprendre',
            '« ${p.title} » : ${e.detail ?? ''}',
          ),
        ProjectEventType.memberJoined when p.ownerId == person.id => (
            NoticeKind.project,
            'Nouveau collaborateur',
            '${nameOf(e.actorId)} a rejoint « ${p.title} ».',
          ),
        ProjectEventType.stageChanged when mine && p.ownerId != person.id => (
            NoticeKind.progress,
            'Le projet avance',
            '« ${p.title} » passe en ${(tr(ProjectStage.values.where((s) => s.name == e.detail).firstOrNull?.label) ?? e.detail ?? '').toLowerCase()}.',
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
            route: '/projects/${p.id}',
          ),
        );
      }
    }
  }
  // The project thread: messages and correction requests from others.
  final byId = {for (final p in projects) p.id: p};
  for (final m in messages) {
    final p = byId[m.projectId];
    if (p == null || m.authorId == person.id || m.at.isBefore(since)) continue;
    if (m.kind != MessageKind.message && m.kind != MessageKind.correction) {
      continue; // status changes and verdicts come from the history
    }
    final mine = p.involves(person.id);
    if (!mine && !followsEdit(person, p, messages)) continue;
    final text = m.body.length > 90 ? '${m.body.substring(0, 90)}…' : m.body;
    out.add(
      Notice(
        id: 'msg-${m.id}',
        kind: NoticeKind.project,
        at: m.at,
        title: m.kind == MessageKind.correction
            ? 'Correction demandée'
            : 'Nouveau message',
        body: '${nameOf(m.authorId)} · « ${p.title} » : $text',
        route: '/projects/${p.id}',
      ),
    );
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
