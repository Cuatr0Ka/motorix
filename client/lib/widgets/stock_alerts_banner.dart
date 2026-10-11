import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/part.dart';
import '../providers/stock_alerts_provider.dart';
import '../utils/tokens.dart';
import 'stock_chip.dart';

/// Texto del resumen de alertas: «3 refacciones con stock bajo, 1 agotada».
String stockAlertsSummary(int count, int outOfStock) {
  final low = count == 1 ? '1 refacción con stock bajo' : '$count refacciones con stock bajo';
  if (outOfStock == 0) return low;
  return '$low, ${outOfStock == 1 ? '1 agotada' : '$outOfStock agotadas'}';
}

/// Banner de alertas de stock bajo del Inventario: muestra el conteo y permite abrir la lista con el
/// stock y el mínimo de cada refacción. Sin alertas, indica que el inventario está en orden.
class StockAlertsBanner extends StatefulWidget {
  const StockAlertsBanner({super.key, required this.onOpenPart});

  final ValueChanged<Part> onOpenPart;

  @override
  State<StockAlertsBanner> createState() => _StockAlertsBannerState();
}

class _StockAlertsBannerState extends State<StockAlertsBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StockAlertsProvider>();
    final theme = Theme.of(context);

    if (provider.error != null && !provider.loaded) {
      return _frame(
        color: AppColors.danger,
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(provider.error!, style: theme.textTheme.bodyMedium)),
            TextButton(onPressed: provider.refresh, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (!provider.loaded) return const SizedBox.shrink();

    if (provider.count == 0) {
      return _frame(
        color: AppColors.success,
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
            const SizedBox(width: AppSpacing.md),
            Text('El inventario está en orden: no hay refacciones con stock bajo.',
                key: const ValueKey('inventario-en-orden'), style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return _frame(
      color: provider.outOfStock > 0 ? AppColors.danger : AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined,
                  color: provider.outOfStock > 0 ? AppColors.danger : AppColors.warning, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  stockAlertsSummary(provider.count, provider.outOfStock),
                  key: const ValueKey('resumen-alertas'),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                key: const ValueKey('ver-alertas'),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Ocultar alertas' : 'Ver alertas'),
              ),
            ],
          ),
          if (_expanded) ...[
            const Divider(),
            for (final part in provider.alerts.items)
              InkWell(
                key: ValueKey('alerta-${part.id}'),
                onTap: () => widget.onOpenPart(part),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(child: Text(part.label, overflow: TextOverflow.ellipsis)),
                      Text('Stock ${part.stock} · mínimo ${part.minStock}', style: theme.textTheme.bodySmall),
                      const SizedBox(width: AppSpacing.md),
                      StockChip(status: part.stockStatus),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _frame({required Color color, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}
