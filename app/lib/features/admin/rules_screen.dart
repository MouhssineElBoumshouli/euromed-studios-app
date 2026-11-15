import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/layout.dart';
import '../../data/admin_service.dart';
import '../../data/app_state.dart';
import '../../domain/rules/settings_rules.dart';
import 'admin_page.dart';

/// I6 · The rules everyone books by. Changes apply at once to new
/// requests; requests already made are not changed.
class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen> {
  RulesDraft? draft;
  bool saving = false;

  String _hours(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
  }

  Future<void> _save(RulesDraft base, List<String> changes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appliquer les nouvelles règles ?'),
        content: Text(
          '${changes.join('\n')}\n\nElles s’appliquent tout de suite aux '
          'nouvelles demandes. Les demandes déjà faites ne changent pas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => saving = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminServiceProvider)
          .updateRules(ref.read(currentPersonProvider), draft!);
      m.showSnackBar(const SnackBar(content: Text('Règles mises à jour.')));
      if (mounted) setState(() => draft = null);
    } on AdminProblem catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final policy = ref.watch(worldProvider).policy;
    final base = RulesDraft.of(policy);
    final d = draft ?? base;
    final changes = rulesChanges(base, d);
    final problem = rulesProblem(d);
    void set(RulesDraft n) => setState(() => draft = n);

    return AdminPage(
      title: 'Règles',
      subtitle: 'Les règles de réservation, réglables sans mise à jour de '
          'l’application.',
      bar: SaveBar(
        changes: changes,
        problem: problem == null ? null : adminProblemText(problem),
        saving: saving,
        onCancel: () => setState(() => draft = null),
        onSave: () => _save(base, changes),
      ),
      children: [
        const Overline('Horaires'),
        const SizedBox(height: 8),
        EsCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Hour(
                      label: 'Ouverture',
                      value: d.openingHour,
                      onChanged: (v) => set(d.copyWith(openingHour: v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Hour(
                      label: 'Fermeture',
                      value: d.closingHour,
                      onChanged: (v) => set(d.copyWith(closingHour: v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Jours d’ouverture : du lundi au vendredi (question Q3 en '
                'attente de l’UEMF).',
                style: EsText.bodyS.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: EsSpace.s4),
        const Overline('Créneaux'),
        const SizedBox(height: 8),
        EsCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Durée d’un créneau', style: EsText.titleS),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  for (final m in allowedSlotMinutes)
                    ButtonSegment(value: m, label: Text(_hours(m))),
                ],
                selected: {d.slotMinutes},
                onSelectionChanged: (s) => set(d.copyWith(slotMinutes: s.first)),
              ),
              const SizedBox(height: 6),
              Text(
                'Changer la durée ne déplace pas les séances déjà réservées.',
                style: EsText.bodyS.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: EsSpace.s4),
        const Overline('Limites'),
        const SizedBox(height: 8),
        EsCard(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
          child: Column(
            children: [
              _Stepper(
                label: 'Réservation possible jusqu’à',
                help: 'Combien de jours à l’avance on peut réserver.',
                value: d.maxAdvanceDays,
                display: '${d.maxAdvanceDays} jours',
                step: d.maxAdvanceDays >= 30 ? 7 : 1,
                min: 1,
                max: 180,
                onChanged: (v) => set(d.copyWith(maxAdvanceDays: v)),
              ),
              Divider(color: c.border, height: 1),
              _Stepper(
                label: 'Quota étudiant',
                help: 'Heures de studio par semaine et par étudiant (R-05).',
                value: d.studentQuotaMinutes,
                display: '${_hours(d.studentQuotaMinutes)} / semaine',
                step: 30,
                min: 30,
                max: 2400,
                onChanged: (v) => set(d.copyWith(studentQuotaMinutes: v)),
              ),
              Divider(color: c.border, height: 1),
              _Stepper(
                label: 'Accès avant la séance',
                help: 'Le QR code ouvre la porte ce nombre de minutes avant.',
                value: d.qrGraceMinutes,
                display: '${d.qrGraceMinutes} min',
                step: 5,
                min: 0,
                max: 60,
                onChanged: (v) => set(d.copyWith(qrGraceMinutes: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hour extends StatelessWidget {
  const _Hour({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
        // A new key when the value changes from outside (e.g. "Annuler").
        key: ValueKey('$label-$value'),
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (var h = 6; h <= 23; h++)
            DropdownMenuItem(value: h, child: Text('$h h 00')),
        ],
        onChanged: (v) => v == null ? null : onChanged(v),
      );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.help,
    required this.value,
    required this.display,
    required this.step,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final String help;
  final int value;
  final String display;
  final int step;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: EsText.titleS),
                Text(help,
                    style: EsText.bodyS.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          IconButton.outlined(
            tooltip: 'Moins',
            onPressed: value - step < min
                ? null
                : () => onChanged((value - step).clamp(min, max)),
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 104,
            child: Semantics(
              label: '$label : $display',
              liveRegion: true,
              child: Text(
                display,
                textAlign: TextAlign.center,
                style: EsText.titleS.copyWith(color: c.textPrimary),
              ),
            ),
          ),
          IconButton.outlined(
            tooltip: 'Plus',
            onPressed: value + step > max
                ? null
                : () => onChanged((value + step).clamp(min, max)),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
