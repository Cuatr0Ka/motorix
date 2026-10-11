import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/client.dart';
import '../models/vehicle.dart';
import '../providers/session_provider.dart';
import '../services/api_client.dart';
import '../services/clients_service.dart';
import '../utils/tokens.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import 'client_form_screen.dart';
import 'vehicle_detail_screen.dart';
import 'vehicle_form_screen.dart';

/// Detalle de un cliente: sus datos y la lista de sus vehículos.
class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final int clientId;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  Client? _client;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = await context.read<ClientsService>().get(widget.clientId);
      if (!mounted) return;
      setState(() => _client = client);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Client>(
      MaterialPageRoute(builder: (_) => ClientFormScreen(existing: _client)),
    );
    if (updated != null && mounted) {
      await _load();
      if (mounted) showSuccess(context, 'Cliente actualizado correctamente.');
    }
  }

  /// Registra un vehículo con este cliente como propietario ya seleccionado.
  Future<void> _addVehicle() async {
    final created = await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute(builder: (_) => VehicleFormScreen(owner: _client)),
    );
    if (created != null && mounted) {
      await _load();
      if (mounted) showSuccess(context, 'Vehículo registrado correctamente.');
    }
  }

  void _openVehicle(VehicleSummary vehicle) {
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: vehicle.id)))
        .then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.watch<SessionProvider>().user?.canEditRecords ?? false;
    final client = _client;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: client?.name ?? 'Cliente',
            subtitle: 'Detalle del cliente',
            onBack: () => Navigator.of(context).maybePop(),
            actions: [
              if (canEdit && client != null)
                OutlinedButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
              if (canEdit && client != null)
                FilledButton.icon(
                  onPressed: _addVehicle,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Registrar vehículo'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: _loading && client == null
                ? const LoadingView()
                : _error != null && client == null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : client == null
                        ? const SizedBox.shrink()
                        : SingleChildScrollView(child: _Content(client: client, onOpenVehicle: _openVehicle)),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.client, required this.onOpenVehicle});

  final Client client;
  final ValueChanged<VehicleSummary> onOpenVehicle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.panel),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            children: [
              DetailRow(label: 'Nombre', value: client.name),
              const Divider(),
              DetailRow(label: 'Teléfono', value: client.phone),
              const Divider(),
              DetailRow(label: 'Correo electrónico', value: client.email),
              const Divider(),
              DetailRow(label: 'Dirección', value: client.address),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Vehículos (${client.vehicles.length})', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        if (client.vehicles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(color: AppColors.outline),
            ),
            child: Text('Este cliente todavía no tiene vehículos registrados.', style: theme.textTheme.bodyMedium),
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(color: AppColors.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Placa')),
                  DataColumn(label: Text('Marca')),
                  DataColumn(label: Text('Modelo')),
                  DataColumn(label: Text('Año'), numeric: true),
                  DataColumn(label: Text('Kilometraje'), numeric: true),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: [
                  for (final vehicle in client.vehicles)
                    DataRow(
                      key: ValueKey('vehiculo-${vehicle.id}'),
                      cells: [
                        DataCell(Text(vehicle.licensePlate)),
                        DataCell(Text(vehicle.brand)),
                        DataCell(Text(vehicle.model)),
                        DataCell(Text('${vehicle.year}')),
                        DataCell(Text(vehicle.currentMileage == null ? '—' : '${vehicle.currentMileage} km')),
                        DataCell(TextButton(
                          key: ValueKey('ver-vehiculo-${vehicle.id}'),
                          onPressed: () => onOpenVehicle(vehicle),
                          child: const Text('Ver detalle'),
                        )),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
