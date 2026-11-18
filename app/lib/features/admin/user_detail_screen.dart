import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../data/admin_state.dart';
import '../../data/app_state.dart';
import '../../data/demo_world.dart';
import '../../data/directory.dart';
import '../../data/people_service.dart';
import '../../domain/activity.dart';
import '../../domain/bookings.dart';
import '../../domain/people.dart';
import '../../domain/rules/admin.dart';
import '../../core/l10n/text.dart';

/// I3 · One person's access: roles, approval scope, clubs, account.
/// Changes are saved together, after a summary, and logged (P-11).
class UserDetailScreen extends ConsumerStatefulWidget {
  const UserDetailScreen({super.key, required this.personId});
  final String personId;

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailState();
}

class _UserDetailState extends ConsumerState<UserDetailScreen> {
  Person? base;
  late Set<Role> roles;
  late List<ApproverScope> scopes;
  late List<String> clubs;
  late bool active;
  bool saving = false;

  /// Establishments picked earlier, kept if a scope is turned off and on.
  final Map<RequesterType, String?> _lastEstablishment = {};

  void _reset(Person p) {
    base = p;
    roles = {...p.roles};
    scopes = [...p.approverScopes];
    clubs = [...p.clubIds];
    active = p.active;
  }

  bool _hasScope(RequesterType t) =>
      scopes.any((s) => s.requesterType == t);

  String? _scopeEstablishment(RequesterType t) =>
      scopes.where((s) => s.requesterType == t).firstOrNull?.establishmentId;

  void _toggleScope(RequesterType t, bool on) => setState(() {
        final current = _scopeEstablishment(t);
        if (!on) _lastEstablishment[t] = current;
        scopes = [
          for (final s in scopes)
            if (s.requesterType != t) s,
          if (on) ApproverScope(t, establishmentId: _lastEstablishment[t]),
        ];
      });

  void _setScopeEstablishment(RequesterType t, String? est) => setState(() {
        scopes = [
          for (final s in scopes)
            if (s.requesterType != t) s,
          ApproverScope(t, establishmentId: est),
        ];
      });

  Future<void> _save(Person me, List<String> changes) async {
    final serious = !active ||
        roles.contains(Role.admin) != base!.has(Role.admin);
    final w = ref.read(worldProvider);
    final turningOff = !active && base!.active;
    final waiting = turningOff
        ? w.bookings
            .where((b) => b.requesterId == base!.id && b.status.isPending)
            .length
        : 0;
    final upcoming = turningOff
        ? w.bookings
            .where(
              (b) =>
                  b.requesterId == base!.id &&
                  b.status == BookingStatus.approved &&
                  b.start.isAfter(w.now),
            )
            .length
        : 0;
    var cancelPending = true;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final c = ctx.es;
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(EsSpace.page, 0, EsSpace.page, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Modifier l’accès de ${base!.firstName} ?',
                  style: EsText.displayM.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: 10),
                for (final ch in changes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.arrow_right_rounded, color: c.accent),
                        Expanded(
                          child: Text(
                            ch,
                            style:
                                EsText.bodyM.copyWith(color: c.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (waiting > 0)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: cancelPending,
                    onChanged: (v) => setSheet(() => cancelPending = v!),
                    title: Text(
                      'Annuler ses $waiting demande${waiting > 1 ? 's' : ''} '
                      'en attente',
                      style: EsText.titleS,
                    ),
                    subtitle: const Text(
                      'Sinon, elles restent dans la file des validateurs.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (upcoming > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: InfoBanner(
                      tone: BannerTone.warning,
                      icon: Icons.event_busy_outlined,
                      title: '$upcoming séance${upcoming > 1 ? 's' : ''} '
                          'validée${upcoming > 1 ? 's' : ''} à venir',
                      text: 'Elles ne sont pas annulées automatiquement. '
                          'Prévenez la régie ou annulez-les depuis la '
                          'réservation.',
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  !active
                      ? 'La personne sera déconnectée et ne pourra plus se '
                          'connecter. Ses réservations restent dans '
                          'l’historique.'
                      : 'Le changement s’applique tout de suite et sera '
                          'inscrit au journal d’activité.',
                  style: EsText.bodyS.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: 18),
                EsButton(
                  'Enregistrer',
                  style: serious
                      ? EsButtonStyle.destructive
                      : EsButtonStyle.primary,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
                const SizedBox(height: 8),
                EsButton(
                  'Annuler',
                  style: EsButtonStyle.ghost,
                  onPressed: () => Navigator.pop(ctx, false),
                ),
              ],
            ),
          ),
        );
      }),
    );
    if (ok != true || !mounted) return;
    setState(() => saving = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await ref.read(peopleServiceProvider).setAccess(
            by: me,
            target: base!,
            roles: roles,
            scopes: scopes,
            clubs: clubs,
            active: active,
            cancelPending: waiting > 0 && cancelPending,
          );
      m.showSnackBar(const SnackBar(content: Text('Accès mis à jour.')));
      if (mounted) {
        final fresh = Directory.people
            .where((p) => p.id == widget.personId)
            .firstOrNull;
        if (fresh != null) setState(() => _reset(fresh));
      }
    } on AccessProblem catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final me = ref.watch(currentPersonProvider);
    final everyone = ref.watch(directoryProvider);
    final person =
        everyone.where((p) => p.id == widget.personId).firstOrNull;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    Widget shell(List<Widget> children, {Widget? bar}) => Scaffold(
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    EsSpace.page,
                    top + EsSpace.s3,
                    EsSpace.page,
                    EsSpace.s6,
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: EsBackButton(
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/admin/users'),
                      ),
                    ),
                    const SizedBox(height: EsSpace.s4),
                    ...children,
                  ],
                ),
              ),
              if (bar != null) bar,
            ],
          ),
        );

    if (!me.has(Role.admin)) {
      return shell(const [
        EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Accès réservé',
          message: 'La gestion des accès est réservée à l’administration.',
        ),
      ]);
    }
    if (person == null) {
      return shell(const [
        EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Personne introuvable',
          message: 'Ce compte n’existe plus.',
        ),
      ]);
    }
    if (base == null || (base!.id != person.id)) _reset(person);

    final changes = accessChanges(
      base!,
      roles: roles,
      scopes: scopes,
      clubs: clubs,
      active: active,
    );
    final problem = accessProblem(
      by: me,
      target: base!,
      roles: roles,
      scopes: roles.contains(Role.entityApprover) ? scopes : const [],
      clubs: roles.contains(Role.clubRepresentative) ? clubs : const [],
      active: active,
      everyone: everyone,
    );
    final changedElsewhere = !person.sameAs(base!);
    final history = [
      for (final a in ref.watch(adminProvider).audit)
        if (a.targetType == 'person' && a.targetId == person.id) a,
    ];
    final est = DemoWorld.establishments
        .where((e) => e.id == person.establishmentId)
        .firstOrNull;
    final self = person.id == me.id;

    final bar = Container(
      padding: EdgeInsets.fromLTRB(
        EsSpace.page,
        EsSpace.s3,
        EsSpace.page,
        EsSpace.s3 + bottom,
      ),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(EsRadius.xl)),
        boxShadow: esShadow(c, strength: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (changes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                problem != null
                    ? accessProblemText(problem)
                    : changes.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: EsText.bodyS.copyWith(
                  color: problem != null ? c.dangerText : c.textSecondary,
                ),
              ),
            ),
          Row(
            children: [
              if (changes.isNotEmpty) ...[
                Expanded(
                  child: EsButton(
                    'Annuler',
                    style: EsButtonStyle.secondary,
                    onPressed:
                        saving ? null : () => setState(() => _reset(person)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: EsButton(
                  changes.isEmpty ? 'Aucune modification' : 'Enregistrer',
                  loading: saving,
                  onPressed: changes.isEmpty || problem != null || saving
                      ? null
                      : () => _save(me, changes),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return shell(
      [
        Row(
          children: [
            Opacity(
              opacity: person.active ? 1 : 0.5,
              child: Avatar(person.initials, size: 56),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.fullName,
                    style: EsText.displayM.copyWith(color: c.textPrimary),
                  ),
                  if (person.title != null)
                    Text(
                      person.title!,
                      style: EsText.bodyM.copyWith(color: c.textSecondary),
                    ),
                  if (est != null)
                    Text(
                      est.name,
                      style: EsText.bodyS.copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (changedElsewhere) ...[
          const SizedBox(height: EsSpace.s3),
          InfoBanner(
            tone: BannerTone.warning,
            icon: Icons.sync_problem_rounded,
            title: 'Modifié entre-temps',
            text: 'Cet accès a changé depuis l’ouverture de la page.',
            action: TextButton(
              onPressed: () => setState(() => _reset(person)),
              child: const Text('Recharger'),
            ),
          ),
        ],
        if (self) ...[
          const SizedBox(height: EsSpace.s3),
          const InfoBanner(
            icon: Icons.info_outline_rounded,
            title: 'C’est votre compte',
            text: 'Vous ne pouvez pas retirer votre propre accès '
                'administrateur ni désactiver votre compte.',
          ),
        ],
        const SizedBox(height: EsSpace.s5),
        for (final (group, list) in roleGroups) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Overline(group),
          ),
          EsCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final r in list)
                  CheckboxListTile(
                    value: roles.contains(r),
                    onChanged: saving ||
                            (self && r == Role.admin)
                        ? null
                        : (v) => setState(() {
                              if (v == true) {
                                roles.add(r);
                              } else {
                                roles.remove(r);
                              }
                            }),
                    title: Text(r.label, style: EsText.titleS),
                    subtitle: Text(
                      self && r == Role.admin
                          ? 'Vous ne pouvez pas retirer votre propre rôle '
                              'd’administrateur.'
                          : roleHelp[r] ?? '',
                      style: EsText.bodyS.copyWith(color: c.textSecondary),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ),
          ),
          const SizedBox(height: EsSpace.s3),
        ],
        if (roles.contains(Role.entityApprover)) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 4, top: 4),
            child: Overline('Périmètre de validation (niveau 1)'),
          ),
          Text(
            'Les demandes que cette personne valide au premier niveau.',
            style: EsText.bodyS.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 8),
          EsCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final t in RequesterType.values) ...[
                  CheckboxListTile(
                    value: _hasScope(t),
                    onChanged: saving ? null : (v) => _toggleScope(t, v == true),
                    title: Text(t.label, style: EsText.titleS),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (_hasScope(t) && t != RequesterType.external)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(56, 0, 16, 10),
                      child: DropdownButtonFormField<String?>(
                        initialValue: _scopeEstablishment(t),
                        decoration: InputDecoration(
                          labelText: tr('Établissement'),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tous les établissements'),
                          ),
                          for (final e in DemoWorld.establishments)
                            DropdownMenuItem<String?>(
                              value: e.id,
                              child: Text(e.short),
                            ),
                        ],
                        onChanged: saving
                            ? null
                            : (v) => _setScopeEstablishment(t, v),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: EsSpace.s3),
        ],
        if (roles.contains(Role.clubRepresentative)) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8, top: 4),
            child: Overline('Clubs représentés'),
          ),
          EsCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final club in DemoWorld.clubs)
                  CheckboxListTile(
                    value: clubs.contains(club.id),
                    onChanged: saving
                        ? null
                        : (v) => setState(() {
                              clubs = [
                                for (final x in clubs)
                                  if (x != club.id) x,
                                if (v == true) club.id,
                              ];
                            }),
                    title: Text(club.name, style: EsText.titleS),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ),
          ),
          const SizedBox(height: EsSpace.s3),
        ],
        const Padding(
          padding: EdgeInsets.only(bottom: 8, top: 4),
          child: Overline('Compte'),
        ),
        EsCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SwitchListTile(
            value: active,
            onChanged: saving || self ? null : (v) => setState(() => active = v),
            title: Text(
              active ? 'Compte actif' : 'Compte désactivé',
              style: EsText.titleS,
            ),
            subtitle: Text(
              active
                  ? 'La personne peut se connecter.'
                  : 'La personne ne peut plus se connecter.',
              style: EsText.bodyS.copyWith(color: c.textSecondary),
            ),
          ),
        ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: EsSpace.s5),
          const SectionTitle('Historique des accès'),
          const SizedBox(height: EsSpace.s2),
          EsCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final a in history.take(10)) _AuditLine(entry: a),
              ],
            ),
          ),
        ],
      ],
      bar: bar,
    );
  }
}

class _AuditLine extends StatelessWidget {
  const _AuditLine({required this.entry});
  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final who = entry.actorId == null
        ? 'Système'
        : personById(entry.actorId!).fullName;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.summary,
              style: EsText.bodyM.copyWith(color: c.textPrimary)),
          Text(
            '$who · ${Fmt.dateTime(entry.at)}',
            style: EsText.bodyS.copyWith(color: c.textDisabled),
          ),
        ],
      ),
    );
  }
}
