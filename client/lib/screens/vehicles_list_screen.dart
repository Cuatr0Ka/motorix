import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vehicle.dart';
import '../providers/session_provider.dart';
import '../providers/vehicles_provider.dart';
import '../utils/tokens.dart';
import '../widgets/app_data_table.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import 'vehicle_detail_screen.dart';
import 'vehicle_form_screen.dart';

/// Listado de vehículos con búsqueda por placa, marca, modelo o propietario.
class VehiclesListScreen extends StatefulWidget {
  const VehiclesListScreen({super.key});

  @override
  State<VehiclesListScreen> createState() => _VehiclesListScreenState();
}

class _VehiclesListScreenState extends State<VehiclesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<VehiclesProvider>().load(search: '', page: 1);
    });
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute(builder: (_) => const VehicleFormScreen()),
    );
    if (created != null && mounted) {
      await context.read<VehiclesProvider>().reload();
      if (mounted) showSuccess(context, 'Vehículo registrado correctamente.');
    }
  }

  void _open(Vehicle vehicle) {
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: vehicle.id)))
        .then((_) {
      if (mounted) context.read<VehiclesProvider>().reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VehiclesProvider>();
    final canEdit = context.watch<SessionProvider>().user?.canEditRecords ?? false;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Vehículos',
            subtitle: 'Automóviles atendidos en el taller',
            actions: [
              if (canEdit)
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nuevo vehículo'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DebouncedSearchField(
              hint: 'Buscar por placa, marca, modelo o propietario',
              initialValue: provider.search,
              onChanged: (value) => context.read<VehiclesProvider>().load(search: value),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _Body(provider: provider, canEdit: canEdit, onCreate: _create, onOpen: _open)),
          if (provider.result != null && provider.result!.total > 0)
            PaginationBar(
              result: provider.result!,
              onPage: (page) => context.read<VehiclesProvider>().load(page: page),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider, required this.canEdit, required this.onCreate, required this.onOpen});

  final VehiclesProvider provider;
  final bool canEdit;
  final VoidCallback onCreate;
  final ValueChanged<Vehicle> onOpen;

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
      return provider.hasSearch
          ? const EmptyView(message: 'No se encontraron vehículos con esa búsqueda.')
          : EmptyView(
              message: 'Todavía no hay vehículos registrados.',
              actionLabel: canEdit ? 'Registrar el primer vehículo' : null,
              onAction: canEdit ? onCreate : null,
            );
    }

    return AnimatedOpacity(
      duration: AppDurations.state,
      opacity: provider.status == LoadStatus.loading ? 0.6 : 1,
      child: AppDataTable(
        minWidth: 760,
        columns: const [
          DataColumn2(label: Text('Placa'), size: ColumnSize.S),
          DataColumn2(label: Text('Marca'), size: ColumnSize.M),
          DataColumn2(label: Text('Modelo'), size: ColumnSize.M),
          DataColumn2(label: Text('Año'), fixedWidth: 80, numeric: true),
          DataColumn2(label: Text('Propietario'), size: ColumnSize.L),
          DataColumn2(label: Text('Acciones'), fixedWidth: 110),
        ],
        rows: [
          for (final vehicle in result.items)
            DataRow2(
              key: ValueKey('vehiculo-${vehicle.id}'),
              onTap: () => onOpen(vehicle),
              cells: [
                DataCell(Text(vehicle.licensePlate)),
                DataCell(Text(vehicle.brand, overflow: TextOverflow.ellipsis)),
                DataCell(Text(vehicle.model, overflow: TextOverflow.ellipsis)),
                DataCell(Text('${vehicle.year}')),
                DataCell(Text(vehicle.owner.name, overflow: TextOverflow.ellipsis)),
                DataCell(RowActionButton.view(tooltip: 'Ver detalle del vehículo', onPressed: () => onOpen(vehicle))),
              ],
            ),
        ],
      ),
    );
  }
}
