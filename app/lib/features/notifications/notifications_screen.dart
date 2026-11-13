import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../data/app_state.dart';
import '../../data/booking_service.dart';
import '../../data/selectors.dart';
import '../../domain/rules/notifications.dart';

/// I1 · Notifications: what changed for me, and what waits for me.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsState();
}

class _NotificationsState extends ConsumerState<NotificationsScreen> {
  /// What counted as read when the screen opened, so new items keep
  /// their dot during this visit even though we mark them read at once.
  DateTime? seenBefore;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    final me = ref.read(currentPersonProvider);
    seenBefore = ref.read(worldProvider).noticesSeenAt[me.id];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingServiceProvider).markNoticesSeen(me.id).ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    final feed = ref.watch(noticesProvider);
    final todo = feed.where((n) => n.actionable).toList();
    final rest = feed.where((n) => !n.actionable).toList();
    bool unread(Notice n) =>
        n.actionable || seenBefore == null || n.at.isAfter(seenBefore!);
    final unreadCount = feed.where(unread).length;

    final today = <Notice>[], week = <Notice>[], older = <Notice>[];
    for (final n in rest) {
      final days = DateTime(w.now.year, w.now.month, w.now.day)
          .difference(DateTime(n.at.year, n.at.month, n.at.day))
          .inDays;
      (days <= 0 ? today : days < 7 ? week : older).add(n);
    }

    Widget section(String title, List<Notice> items) => items.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Overline(title),
              ),
              EsCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, indent: 68, color: c.border),
                      _NoticeTile(
                        notice: items[i],
                        now: w.now,
                        unread: unread(items[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          EsSpace.page,
          MediaQuery.paddingOf(context).top + EsSpace.s3,
          EsSpace.page,
          EsSpace.s8,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: EsBackButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
          ),
          const SizedBox(height: EsSpace.s4),
          Text(
            'Notifications',
            style: EsText.displayL.copyWith(color: c.textPrimary),
          ),
          Text(
            unreadCount == 0
                ? 'Vous êtes à jour.'
                : '$unreadCount nouvelle${unreadCount > 1 ? 's' : ''}',
            style: EsText.bodyM.copyWith(color: c.textSecondary),
          ),
          if (feed.isEmpty)
            const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Rien pour l’instant',
              message: 'Les validations, rappels et changements de vos '
                  'séances apparaîtront ici.',
            ),
          section('À traiter', todo),
          section('Aujourd’hui', today),
          section('Cette semaine', week),
          section('Plus tôt', older),
        ],
      ),
    );
  }
}

(IconData, Color, Color) noticeStyle(EsColors c, NoticeKind k) => switch (k) {
      NoticeKind.toDecide => (Icons.task_alt_rounded, c.pendingBg, c.pendingText),
      NoticeKind.approved => (Icons.qr_code_2_rounded, c.successBg, c.successText),
      NoticeKind.progress => (Icons.hourglass_bottom_rounded, c.reviewBg, c.reviewText),
      NoticeKind.refused => (Icons.close_rounded, c.dangerBg, c.dangerText),
      NoticeKind.cancelled => (Icons.event_busy_outlined, c.dangerBg, c.dangerText),
      NoticeKind.reminder => (Icons.alarm_rounded, c.lilac, c.onLilac),
      NoticeKind.assigned => (Icons.engineering_outlined, c.reviewBg, c.reviewText),
      NoticeKind.closed => (Icons.done_all_rounded, c.neutralBg, c.neutralText),
    };

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({
    required this.notice,
    required this.now,
    required this.unread,
  });
  final Notice notice;
  final DateTime now;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final (icon, bg, fg) = noticeStyle(c, notice.kind);
    return Semantics(
      button: true,
      label: '${unread ? 'Nouveau. ' : ''}${notice.title}. ${notice.body}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(notice.route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon, size: 40, bg: bg, fg: fg),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notice.title,
                            style: EsText.titleS.copyWith(
                              color: c.textPrimary,
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          Fmt.ago(notice.at, now),
                          style: EsText.bodyS.copyWith(color: c.textDisabled),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notice.body,
                      style: EsText.bodyS.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  margin: const EdgeInsets.only(left: 10, top: 6),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bell with a count of unread notifications. Opens the feed.
class NoticeBell extends ConsumerWidget {
  const NoticeBell({super.key, this.onDark = false});
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final n = ref.watch(unreadNoticesProvider);
    return Semantics(
      button: true,
      label: n == 0 ? 'Notifications' : 'Notifications, $n nouvelles',
      excludeSemantics: true,
      child: Material(
        color: onDark ? Colors.white.withValues(alpha: 0.12) : c.bgSurface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push('/notifications'),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  n == 0
                      ? Icons.notifications_none_rounded
                      : Icons.notifications_active_outlined,
                  color: onDark ? Colors.white : c.textPrimary,
                  size: 22,
                ),
                if (n > 0)
                  Positioned(
                    top: 4,
                    right: 2,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.dangerText,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: onDark ? c.bgBrand : c.bgSurface,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        n > 9 ? '9+' : '$n',
                        style: EsText.labelS.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
