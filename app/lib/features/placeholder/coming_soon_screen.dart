import 'package:flutter/material.dart';

import '../../core/theme/es_colors.dart';
import '../../core/theme/es_text.dart';
import '../../core/widgets/layout.dart';

/// Temporary screen for tabs built in a later milestone.
/// Says plainly what will be here and when.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.milestone,
    required this.what,
  });
  final String title;
  final String milestone;
  final String what;

  @override
  Widget build(BuildContext context) {
    final c = context.es;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Text(title.toUpperCase(), style: EsText.displayL.copyWith(color: c.textPrimary)),
        const SizedBox(height: 24),
        EmptyState(
          icon: Icons.construction_rounded,
          title: 'En construction · $milestone',
          message: what,
        ),
      ],
    );
  }
}
