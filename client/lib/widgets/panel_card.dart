import 'package:flutter/material.dart';

import '../utils/tokens.dart';

/// Panel con borde fino y título del sistema de diseño, con una acción opcional a la derecha del título.
class PanelCard extends StatelessWidget {
  const PanelCard({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)), ?trailing]),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
