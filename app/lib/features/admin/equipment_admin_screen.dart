import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/layout.dart';
import '../../data/admin_service.dart';
import '../../data/app_state.dart';
import '../../data/catalog.dart';
import '../../domain/bookings.dart';
import 'admin_page.dart';

/// I5 · Equipment catalogue and stock. Requests can't ask for more than
/// what is in stock.
class EquipmentAdminScreen extends ConsumerWidget {
  const EquipmentAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.es;
    final w = ref.watch(worldProvider);
    // Busiest future demand per item (one session), to warn before lowering.
    int peak(String id) {
      var top = 0;
      for (final b in w.bookings) {
        if (b.end.isBefore(w.now) ||
            !(b.status == BookingStatus.approved || b.status.isPending)) {
          continue;
        }
        for (final e in b.equipment) {
          if (e.itemId == id && e.quantity > top) top = e.quantity;
        }
      }
      return top;
    }

    return AdminPage(
      title: 'Matériel',
      subtitle: 'Les quantités disponibles au prêt avec les studios.',
      children: [
        EsCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < Catalog.equipment.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 16, color: c.border),
                _ItemRow(
                  item: Catalog.equipment[i],
                  peak: peak(Catalog.equipment[i].id),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Ajouter un nouvel article au catalogue se fait avec la Direction '
          'des Studios (photo, description).',
          style: EsText.bodyS.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _ItemRow extends ConsumerStatefulWidget {
  const _ItemRow({required this.item, required this.peak});
  final EquipmentItem item;
  final int peak;

  @override
  ConsumerState<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends ConsumerState<_ItemRow> {
  int? draft;
  bool busy = false;

  Future<void> _save() async {
    setState(() => busy = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminServiceProvider)
          .setStock(ref.read(currentPersonProvider), widget.item.id, draft!);
      m.showSnackBar(SnackBar(content: Text('${widget.item.name} : stock mis à jour.')));
      if (mounted) setState(() => draft = null);
    } on AdminProblem catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    final it = widget.item;
    final v = draft ?? it.stock;
    final changed = draft != null && draft != it.stock;
    final short = v < widget.peak;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.name, style: EsText.titleS),
                    Text(
                      it.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: EsText.bodyS.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Moins',
                onPressed: busy || v <= 0 ? null : () => setState(() => draft = v - 1),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              SizedBox(
                width: 36,
                child: Semantics(
                  label: '${it.name} : $v en stock',
                  liveRegion: true,
                  child: Text(
                    '$v',
                    textAlign: TextAlign.center,
                    style: EsText.titleM.copyWith(color: c.textPrimary),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Plus',
                onPressed: busy || v >= 999 ? null : () => setState(() => draft = v + 1),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          if (short)
            Text(
              'Attention : une séance à venir en demande ${widget.peak}.',
              style: EsText.bodyS.copyWith(color: c.pendingText),
            ),
          if (changed)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => setState(() => draft = null),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: busy ? null : _save,
                    child: Text('Enregistrer ($v)'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
