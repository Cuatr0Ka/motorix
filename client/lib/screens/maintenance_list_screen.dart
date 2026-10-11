import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/maintenance.dart';
import '../models/user.dart';
import '../providers/maintenance_provider.dart';
import '../providers/session_provider.dart';
import '../utils/formatters.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';
import '../widgets/app_data_table.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/maintenance_chip.dart';
import '../widgets/maintenance_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import 'vehicle_detail_screen.dart';

/// Mantenimientos próximos y vencidos (recepción y administración). Muestra cliente y teléfono para
/// avisar al cliente; el administrador puede además editar y marcar como atendido.
class MaintenanceListScreen extends StatefulWidget {
  const MaintenanceListScreen({super.key});

  @override
  State<MaintenanceListScreen> createState() => _MaintenanceListScreenState();
}

class _MaintenanceListScreenState extends State<MaintenanceListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<MaintenanceProvider>();
      provider.setIndicator(null);
      provider.load(search: '', page: 1);
    });
  }

  void _openVehicle(Maintenance maintenance) {
    final vehicle = maintenance.vehicle;
    if (vehicle == null) return;
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: vehicle.id)))
        .then((_) {
      if (mounted) context.read<MaintenanceProvider>().reload();
    });
  }

  Future<void> _edit(Maintenance maintenance) async {
    final provider = context.read<MaintenanceProvider>();
    final input = await showDialog<MaintenanceInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MaintenanceDialog(existing: maintenance),
    );
    if (input == null || !mounted) return;
    final failure = await provider.update(maintenance.id, input);
    if (!mounted) return;
    if (failure == null) {
      showSuccess(context, 'Mantenimiento actualizado correctamente.');
    } else {
      showFailure(context, failure);
    }
  }

  Future<void> _attend(Maintenance maintenance) async {
    final provider = context.read<MaintenanceProvider>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Marcar como atendido',
      message: '¿Confirmas que el mantenimiento "${maintenance.description}" ya fue atendido? '
          'Esta acción no se puede deshacer.',
    );
    if (!confirmed || !mounted) return;
    final failure = await provider.attend(maintenance.id);
    if (!mounted) return;
    if (failure == null) {
      showSuccess(context, 'Mantenimiento marcado como atendido.');
    } else {
      showFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MaintenanceProvider>();
    final isAdmin = context.watch<SessionProvider>().user?.role == UserRole.admin;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Mantenimientos',
            subtitle: 'Próximos y vencidos, para avisar al cliente',
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380, minWidth: 280),
                child: DebouncedSearchField(
                  hint: 'Buscar por cliente o placa',
                  initialValue: provider.search,
                  onChanged: (value) => context.read<MaintenanceProvider>().load(search: value),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<MaintenanceIndicator?>(
                  key: const ValueKey('filtro-indicador'),
                  initialValue: provider.indicatorFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: [
                    const DropdownMenuItem<MaintenanceIndicator?>(value: null, child: Text('Todos')),
                    for (final indicator in MaintenanceIndicator.values)
                      DropdownMenuItem<MaintenanceIndicator?>(value: indicator, child: Text(indicator.label)),
                  ],
                  onChanged: provider.setIndicator,
                ),
              ),
              if (provider.indicatorFilter != null)
                TextButton(onPressed: () => provider.setIndicator(null), child: const Text('Limpiar filtros')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _Body(provider: provider, isAdmin: isAdmin, onOpen: _openVehicle, onEdit: _edit, onAttend: _attend)),
          if (provider.result != null && provider.result!.total > 0)
            PaginationBar(
              result: provider.result!,
              onPage: (page) => context.read<MaintenanceProvider>().load(page: page),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.provider,
    required this.isAdmin,
    required this.onOpen,
    required this.onEdit,
    required this.onAttend,
  });

  final MaintenanceProvider provider;
  final bool isAdmin;
  final ValueChanged<Maintenance> onOpen;
  final ValueChanged<Maintenance> onEdit;
  final ValueChanged<Maintenance> onAttend;

  String _target(Maintenance m) => [
        if (m.dueDate != null) formatDate(m.dueDate!),
        if (m.dueMileage != null) formatMileage(m.dueMileage!),
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final result = provider.result;

    if (result == null) {
      if (provider.status == LoadStatus.error) {
        return ErrorView(message: provider.error ?? 'No se pudo cargar.', onRetry: provider.reload);
      }
      return const LoadingView();
    }
    if (provider.status == LoadStatus.error) {
      return ErrorView(message: provider.error ?? 'No se pudo cargar.', onRetry: provider.reload);
    }
    if (result.items.isEmpty) {
      if (provider.status == LoadStatus.loading) return const LoadingView();
      return EmptyView(
        message: provider.hasSearch ? 'No se encontraron mantenimientos con esos filtros.' : 'Sin mantenimientos pendientes.',
      );
    }

    return AnimatedOpacity(
      duration: AppDurations.state,
      opacity: provider.status == LoadStatus.loading ? 0.6 : 1,
      child: AppDataTable(
        minWidth: isAdmin ? 1000 : 900,
        columns: [
          const DataColumn2(label: Text('Cliente'), size: ColumnSize.M),
          const DataColumn2(label: Text('Teléfono'), fixedWidth: 120),
          const DataColumn2(label: Text('Vehículo'), size: ColumnSize.M),
          const DataColumn2(label: Text('Servicio'), size: ColumnSize.L),
          const DataColumn2(label: Text('Objetivo'), size: ColumnSize.M),
          const DataColumn2(label: Text('Estado'), fixedWidth: 110),
          if (isAdmin) const DataColumn2(label: Text('Acciones'), fixedWidth: 110),
        ],
        rows: [
          for (final m in result.items)
            DataRow2(
              key: ValueKey('mantenimiento-${m.id}'),
              onTap: () => onOpen(m),
              cells: [
                DataCell(Text(m.client?.name ?? '—', overflow: TextOverflow.ellipsis)),
                DataCell(Text(m.client?.phone ?? '—')),
                DataCell(Text(m.vehicle == null ? '—' : '${m.vehicle!.licensePlate} · ${m.vehicle!.brand} ${m.vehicle!.model}',
                    overflow: TextOverflow.ellipsis)),
                DataCell(Text(m.description, overflow: TextOverflow.ellipsis)),
                DataCell(Text(_target(m), overflow: TextOverflow.ellipsis)),
                DataCell(MaintenanceChip(indicator: m.indicator, attended: m.isAttended)),
                if (isAdmin)
                  DataCell(Row(
                    children: [
                      IconButton(
                        key: ValueKey('editar-mantenimiento-${m.id}'),
                        tooltip: 'Editar',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onEdit(m),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                      IconButton(
                        key: ValueKey('atender-mantenimiento-${m.id}'),
                        tooltip: 'Marcar como atendido',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onAttend(m),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                      ),
                    ],
                  )),
              ],
            ),
        ],
      ),
    );
  }
}
