import 'package:flutter/material.dart';

import '../../app/shell.dart';
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
    return ListView(
      padding: EdgeInsets.only(bottom: tabBarSpace(context)),
      children: [
        BrandHeader(title: title, subtitle: milestone),
        EmptyState(
          icon: Icons.construction_rounded,
          title: 'Bientôt ici',
          message: what,
        ),
      ],
    );
  }
}
