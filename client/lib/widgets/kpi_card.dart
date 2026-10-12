import 'package:flutter/material.dart';

import '../utils/status_labels.dart';
import '../utils/tokens.dart';

/// Tarjeta de un indicador principal del panel: etiqueta, ícono, número grande y una línea de apoyo. El tono (rojo o
/// ámbar) refuerza el valor, pero el color nunca es la única señal: la etiqueta siempre describe qué se cuenta.
/// Al seleccionarla lleva a su listado.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.tone = StatusTone.neutral,
    this.hint,
  });

  final String label;
  final int value;
  final IconData icon;
  final VoidCallback onTap;
  final StatusTone tone;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alert = value > 0 && tone != StatusTone.neutral;
    final accent = alert ? tone.color : AppColors.textSecondary;
    return Semantics(
      button: true,
      label: '$label: $value',
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: BorderSide(color: alert ? tone.color.withValues(alpha: 0.5) : AppColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                      child: Icon(icon, size: 20, color: accent),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$value',
                  key: ValueKey('valor-$label'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 36,
                    color: value == 0 ? AppColors.textSecondary : (alert ? tone.color : AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(value == 0 && hint == null ? 'Sin registros' : (hint ?? ''), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
