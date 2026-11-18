import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/es_button.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/app_state.dart';
import '../../data/directory.dart';
import '../../domain/people.dart';
import '../../core/l10n/text.dart';

enum _Filter {
  all('Tous'),
  requesters('Demandeurs'),
  approvers('Validateurs'),
  studios('Équipe des studios'),
  admins('Administration'),
  disabled('Désactivés');

  const _Filter(this.label);
  final String label;

  bool matches(Person p) => switch (this) {
        _Filter.all => true,
        _Filter.requesters => p.roles.any((r) => r.isRequester),
        _Filter.approvers => p.has(Role.entityApprover),
        _Filter.studios => p.has(Role.studioManager) || p.has(Role.regisseur),
        _Filter.admins => p.has(Role.admin),
        _Filter.disabled => !p.active,
      };
}

/// I3 · Everyone with access, their roles, and a way in to change them.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final search = TextEditingController();
  _Filter filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final me = ref.watch(currentPersonProvider);
    final everyone = [...ref.watch(directoryProvider)]
      ..sort((a, b) => a.lastName.compareTo(b.lastName));
    final q = _fold(search.text.trim());
    final shown = [
      for (final p in everyone)
        if (filter.matches(p) &&
            (q.isEmpty ||
                _fold(p.fullName).contains(q) ||
                _fold(p.title ?? '').contains(q)))
          p,
    ];
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          EsSpace.page,
          top + EsSpace.s3,
          EsSpace.page,
          EsSpace.s8,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: EsBackButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/admin'),
            ),
          ),
          const SizedBox(height: EsSpace.s4),
          Text(
            'Utilisateurs et rôles',
            style: EsText.displayL.copyWith(color: c.textPrimary),
          ),
          Text(
            '${everyone.length} personnes · les comptes sont créés à la '
            'première connexion universitaire.',
            style: EsText.bodyM.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: EsSpace.s4),
          if (!me.has(Role.admin))
            const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Accès réservé',
              message: 'La gestion des accès est réservée à l’administration.',
            )
          else ...[
            TextField(
              controller: search,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: tr('Rechercher un nom ou une fonction'),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in _Filter.values)
                  ChoiceChip(
                    label: Text(
                      '${f.label} · ${everyone.where(f.matches).length}',
                    ),
                    selected: filter == f,
                    onSelected: (_) => setState(() => filter = f),
                  ),
              ],
            ),
            const SizedBox(height: EsSpace.s3),
            if (shown.isEmpty)
              const EmptyState(
                icon: Icons.person_search_outlined,
                title: 'Personne',
                message: 'Aucune personne ne correspond.',
              )
            else
              EsCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, indent: 66, color: c.border),
                      _PersonRow(person: shown[i], me: me),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.me});
  final Person person;
  final Person me;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final p = person;
    final roles = [
      for (final r in Role.values)
        if (p.has(r)) r
    ];
    return InkWell(
      onTap: () => context.push('/admin/users/${p.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Opacity(
              opacity: p.active ? 1 : 0.5,
              child: Avatar(p.initials, size: 38),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.id == me.id ? '${p.fullName} (vous)' : p.fullName,
                    style: EsText.titleS.copyWith(
                      color: p.active ? c.textPrimary : c.textSecondary,
                    ),
                  ),
                  if (p.title != null)
                    Text(
                      p.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EsText.bodyS.copyWith(color: c.textSecondary),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (!p.active)
                        Tag(
                          label: 'Désactivé',
                          background: c.dangerBg,
                          foreground: c.dangerText,
                          icon: Icons.block_rounded,
                        ),
                      for (final r in roles)
                        Tag(
                          label: r.label,
                          background: r == Role.admin
                              ? c.pendingBg
                              : r.isRequester
                                  ? c.bgSubtle
                                  : c.lilac,
                          foreground: r == Role.admin
                              ? c.pendingText
                              : r.isRequester
                                  ? c.textSecondary
                                  : c.onLilac,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textDisabled),
          ],
        ),
      ),
    );
  }
}
