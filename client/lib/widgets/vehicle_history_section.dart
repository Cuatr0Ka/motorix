import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/history_entry.dart';
import '../models/maintenance.dart';
import '../providers/vehicle_history_provider.dart';
import '../services/vehicles_service.dart';
import '../utils/formatters.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';
import 'maintenance_chip.dart';
import 'state_views.dart';
import 'status_chip.dart';

/// Sección «Historial de servicios» del detalle del vehículo: línea cronológica de los servicios
/// terminados, con el mantenimiento vigente destacado. Es de solo lectura y la ven los tres roles.
class VehicleHistorySection extends StatelessWidget {
  const VehicleHistorySection({super.key, required this.vehicleId});

  final int vehicleId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey('historial-$vehicleId'),
      create: (context) => VehicleHistoryProvider(context.read<VehiclesService>(), vehicleId)..load(),
      child: const _HistoryBody(),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<VehicleHistoryProvider>();
    final textTheme = Theme.of(context).textTheme;

    Widget content;
    if (history.loading && history.entries.isEmpty) {
      content = const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView(label: 'Cargando historial…'));
    } else if (history.error != null && history.entries.isEmpty) {
      content = ErrorView(message: history.error!, onRetry: history.load);
    } else if (history.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: EmptyView(message: 'Este vehículo aún no tiene servicios terminados.'),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in history.entries) ...[
            _HistoryCard(entry: entry),
            const SizedBox(height: AppSpacing.md),
          ],
          if (history.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(history.error!, style: textTheme.bodySmall?.copyWith(color: AppColors.danger)),
            ),
          if (history.hasMore)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const ValueKey('historial-cargar-mas'),
                onPressed: history.loading ? null : history.loadMore,
                child: Text(history.loading ? 'Cargando…' : 'Cargar más servicios'),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historial de servicios', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        if (history.pendingMaintenance != null) ...[
          _PendingMaintenance(maintenance: history.pendingMaintenance!),
          const SizedBox(height: AppSpacing.md),
        ],
        content,
      ],
    );
  }
}

class _PendingMaintenance extends StatelessWidget {
  const _PendingMaintenance({required this.maintenance});

  final Maintenance maintenance;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final target = [
      if (maintenance.dueDate != null) formatDate(maintenance.dueDate!),
      if (maintenance.dueMileage != null) formatMileage(maintenance.dueMileage!),
    ].join(' · ');
    return Container(
      key: const ValueKey('mantenimiento-vigente'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_repeat_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Próximo mantenimiento', style: textTheme.bodySmall),
                Text(maintenance.description, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (target.isNotEmpty) Text(target, style: textTheme.bodySmall),
              ],
            ),
          ),
          MaintenanceChip(indicator: maintenance.indicator, attended: maintenance.isAttended),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = OrderStatus.fromApi(entry.status);
    String lines(List<HistoryLine> items) => items.map((e) => e.description).join(', ');

    Widget detail(String label, String? value) {
      if (value == null || value.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$label: ', style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          TextSpan(text: value, style: textTheme.bodySmall),
        ])),
      );
    }

    return Container(
      key: ValueKey('historial-${entry.orderId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(formatDate(entry.serviceDate), style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: AppSpacing.md),
              Text(entry.folio, style: textTheme.bodySmall),
              if (entry.mileage != null) ...[
                const SizedBox(width: AppSpacing.md),
                Text(formatMileage(entry.mileage!), style: textTheme.bodySmall),
              ],
              const Spacer(),
              StatusChip.order(status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          detail('Problema reportado', entry.reportedProblem),
          detail('Diagnóstico', entry.diagnosis),
          detail('Servicios', lines(entry.services)),
          detail('Mano de obra', lines(entry.labor)),
          detail('Refacciones', entry.parts.map((p) => '${p.quantity} × ${p.name}').join(', ')),
          detail('Mecánico', entry.mechanicName),
          if (entry.maintenance != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Flexible(
                  child: Text('Programó: ${entry.maintenance!.description}', style: textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: AppSpacing.sm),
                MaintenanceChip(indicator: entry.maintenance!.indicator, attended: entry.maintenance!.isAttended),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
