import 'package:flutter/material.dart';

import '../utils/status_labels.dart';
import '../utils/tokens.dart';

/// Tarjeta numérica de un indicador del panel. El tono (rojo, ámbar o neutro) refuerza el valor, pero el color
/// nunca es la única señal: la etiqueta siempre describe qué se cuenta. Al seleccionarla lleva a su listado.
class IndicatorCard extends StatelessWidget {
  const IndicatorCard({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.tone = StatusTone.neutral,
    this.hint,
  });

  final String label;
  final int value;
  final VoidCallback onTap;
  final StatusTone tone;

  /// Texto breve de apoyo (por ejemplo, «últimos 30 días»).
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Un valor en cero no alerta: se muestra en neutro y con un texto de estado vacío.
    final color = value == 0 ? AppColors.textSecondary : (tone == StatusTone.neutral ? AppColors.textPrimary : tone.color);
    return Semantics(
      button: true,
      label: '$label: $value',
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: BorderSide(color: value > 0 && tone != StatusTone.neutral ? tone.color.withValues(alpha: 0.5) : AppColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 210,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$value', key: ValueKey('valor-$label'), style: theme.textTheme.headlineMedium?.copyWith(color: color)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(label, style: theme.textTheme.bodyMedium),
                  if (hint != null) Text(hint!, style: theme.textTheme.bodySmall),
                  if (value == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text('Sin registros', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
