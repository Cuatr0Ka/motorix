import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vehicle.dart';
import '../providers/session_provider.dart';
import '../services/api_client.dart';
import '../services/vehicles_service.dart';
import '../utils/tokens.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import 'client_detail_screen.dart';
import 'vehicle_form_screen.dart';

/// Detalle de un vehículo: sus datos y su propietario (con enlace al detalle del cliente).
class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final int vehicleId;

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  Vehicle? _vehicle;
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
      final vehicle = await context.read<VehiclesService>().get(widget.vehicleId);
      if (!mounted) return;
      setState(() => _vehicle = vehicle);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute(builder: (_) => VehicleFormScreen(existing: _vehicle)),
    );
    if (updated != null && mounted) {
      await _load();
      if (mounted) showSuccess(context, 'Vehículo actualizado correctamente.');
    }
  }

  void _openOwner(VehicleOwner owner) {
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => ClientDetailScreen(clientId: owner.id)))
        .then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.watch<SessionProvider>().user?.canEditRecords ?? false;
    final vehicle = _vehicle;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: vehicle == null ? 'Vehículo' : '${vehicle.brand} ${vehicle.model} · ${vehicle.licensePlate}',
            subtitle: 'Detalle del vehículo',
            onBack: () => Navigator.of(context).maybePop(),
            actions: [
              if (canEdit && vehicle != null)
                OutlinedButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: _loading && vehicle == null
                ? const LoadingView()
                : _error != null && vehicle == null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : vehicle == null
                        ? const SizedBox.shrink()
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Panel(children: [
                                  DetailRow(label: 'Placa', value: vehicle.licensePlate),
                                  const Divider(),
                                  DetailRow(label: 'Marca', value: vehicle.brand),
                                  const Divider(),
                                  DetailRow(label: 'Modelo', value: vehicle.model),
                                  const Divider(),
                                  DetailRow(label: 'Año', value: '${vehicle.year}'),
                                  const Divider(),
                                  DetailRow(label: 'Color', value: vehicle.color),
                                  const Divider(),
                                  DetailRow(label: 'Número de serie (VIN)', value: vehicle.vin),
                                  const Divider(),
                                  DetailRow(
                                    label: 'Kilometraje actual',
                                    value: vehicle.currentMileage == null ? null : '${vehicle.currentMileage} km',
                                  ),
                                ]),
                                const SizedBox(height: AppSpacing.xl),
                                Text('Propietario', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: AppSpacing.md),
                                _Panel(children: [
                                  DetailRow(label: 'Nombre', value: vehicle.owner.name),
                                  const Divider(),
                                  DetailRow(label: 'Teléfono', value: vehicle.owner.phone),
                                  const Divider(),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      key: const ValueKey('ver-propietario'),
                                      onPressed: () => _openOwner(vehicle.owner),
                                      child: const Text('Ver detalle del cliente'),
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(children: children),
    );
  }
}
