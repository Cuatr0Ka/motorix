import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vehicle.dart';
import '../services/api_client.dart';
import '../services/vehicles_service.dart';
import '../utils/tokens.dart';
import 'app_data_table.dart';
import 'state_views.dart';

/// Campo de formulario para elegir un vehículo (obligatorio) buscando entre los registrados.
/// Con [clientId] solo ofrece los vehículos de ese cliente.
class VehicleSelectorField extends FormField<Vehicle> {
  VehicleSelectorField({
    super.key,
    super.initialValue,
    required ValueChanged<Vehicle?> onChanged,
    super.enabled,
    int? clientId,
    String? serverError,
    String label = 'Vehículo *',
  }) : super(
          validator: (vehicle) => serverError ?? (vehicle == null ? 'Selecciona un vehículo.' : null),
          builder: (state) {
            final vehicle = state.value;
            return Builder(
              builder: (context) => InkWell(
                borderRadius: BorderRadius.circular(AppRadius.control),
                onTap: !state.widget.enabled
                    ? null
                    : () async {
                        final chosen = await showVehiclePicker(context, clientId: clientId);
                        if (chosen != null) {
                          state.didChange(chosen);
                          onChanged(chosen);
                        }
                      },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: label,
                    errorText: state.errorText,
                    suffixIcon: const Icon(Icons.search, size: 20),
                  ),
                  isEmpty: vehicle == null,
                  child: vehicle == null
                      ? const SizedBox.shrink()
                      : Text(
                          '${vehicle.licensePlate} · ${vehicle.brand} ${vehicle.model} · ${vehicle.owner.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            );
          },
        );
}

/// Diálogo de búsqueda de vehículos. Devuelve el vehículo elegido o null.
Future<Vehicle?> showVehiclePicker(BuildContext context, {int? clientId}) {
  return showDialog<Vehicle>(
    context: context,
    builder: (_) => Provider<VehiclesService>.value(
      value: context.read<VehiclesService>(),
      child: _VehiclePickerDialog(clientId: clientId),
    ),
  );
}

class _VehiclePickerDialog extends StatefulWidget {
  const _VehiclePickerDialog({this.clientId});

  final int? clientId;

  @override
  State<_VehiclePickerDialog> createState() => _VehiclePickerDialogState();
}

class _VehiclePickerDialogState extends State<_VehiclePickerDialog> {
  List<Vehicle>? _items;
  String? _error;
  String _search = '';
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = ++_request;
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final result = await context
          .read<VehiclesService>()
          .list(search: _search, clientId: widget.clientId, pageSize: 20);
      if (!mounted || id != _request) return;
      setState(() => _items = result.items);
    } on ApiException catch (e) {
      if (mounted && id == _request) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elegir vehículo'),
      content: SizedBox(
        width: 520,
        height: 360,
        child: Column(
          children: [
            DebouncedSearchField(
              hint: 'Buscar por placa, marca, modelo o propietario',
              onChanged: (value) {
                _search = value;
                _load();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : _items == null
                      ? const LoadingView()
                      : _items!.isEmpty
                          ? EmptyView(
                              message: widget.clientId != null
                                  ? 'Este cliente no tiene vehículos que coincidan.'
                                  : 'No se encontraron vehículos.',
                            )
                          : ListView.separated(
                              itemCount: _items!.length,
                              separatorBuilder: (context, index) => const Divider(),
                              itemBuilder: (context, index) {
                                final vehicle = _items![index];
                                return ListTile(
                                  key: ValueKey('vehiculo-opcion-${vehicle.id}'),
                                  dense: true,
                                  title: Text('${vehicle.licensePlate} · ${vehicle.brand} ${vehicle.model}'),
                                  subtitle: Text(vehicle.owner.name),
                                  onTap: () => Navigator.of(context).pop(vehicle),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      ],
    );
  }
}
