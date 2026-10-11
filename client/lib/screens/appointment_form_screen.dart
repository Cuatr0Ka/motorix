import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../models/client.dart';
import '../models/vehicle.dart';
import '../services/api_client.dart';
import '../services/appointments_service.dart';
import '../utils/formatters.dart';
import '../utils/tokens.dart';
import '../widgets/client_selector.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import '../widgets/vehicle_selector.dart';

/// Formulario de cita. Con [existing] edita fecha, hora, motivo y observaciones (el cliente y el
/// vehículo no cambian). Termina devolviendo (`pop`) la cita guardada, o nada si se cancela.
class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({super.key, this.existing});

  final Appointment? existing;

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _reason = TextEditingController(text: widget.existing?.reason);
  late final _notes = TextEditingController(text: widget.existing?.notes);

  Client? _client;
  Vehicle? _vehicle;
  late DateTime? _when = widget.existing?.scheduledAt.toLocal();
  final Map<String, String> _serverErrors = {};
  bool _dirty = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _changed(String field) {
    if (!_dirty || _serverErrors.containsKey(field)) {
      setState(() {
        _dirty = true;
        _serverErrors.remove(field);
      });
    }
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final initial = _when ?? now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: 'Fecha de la cita',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Hora de la cita',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (time == null || !mounted) return;
    setState(() {
      _when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _dirty = true;
      _serverErrors.remove('scheduledAt');
    });
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final when = _when;
    if (when == null) return;
    final service = context.read<AppointmentsService>();

    final input = AppointmentInput(
      clientId: _isEdit ? widget.existing!.client.id : _client!.id,
      vehicleId: _isEdit ? widget.existing!.vehicle.id : _vehicle!.id,
      scheduledAt: when,
      reason: _reason.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );

    setState(() => _saving = true);
    try {
      final saved = _isEdit ? await service.update(widget.existing!.id, input) : await service.create(input);
      _dirty = false;
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      _showServerError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showServerError(ApiException e) {
    final byCode = {
      'APPOINTMENT_IN_PAST': 'scheduledAt',
      'APPOINTMENT_SLOT_TAKEN': 'scheduledAt',
      'VEHICLE_CLIENT_MISMATCH': 'vehicleId',
      'VEHICLE_NOT_FOUND': 'vehicleId',
    };
    final fields = e.fieldErrors;
    if (fields.isNotEmpty || byCode.containsKey(e.code)) {
      setState(() {
        for (final error in fields) {
          _serverErrors[error.field] = error.message;
        }
        final field = byCode[e.code];
        if (field != null) _serverErrors[field] = e.message;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _formKey.currentState?.validate());
    } else {
      showFailure(context, e.message);
    }
  }

  Future<void> _confirmExit() async {
    final leave = await showConfirmDialog(
      context,
      title: 'Salir sin guardar',
      message: 'Tienes cambios sin guardar. ¿Seguro que quieres salir?',
    );
    if (leave && mounted) {
      setState(() => _dirty = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: _isEdit ? 'Editar cita' : 'Nueva cita',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (_isEdit) ...[
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Cliente'),
                      child: Text(existing!.client.name),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Vehículo'),
                      child: Text(existing.vehicle.label),
                    ),
                  ] else ...[
                    ClientSelectorField(
                      label: 'Cliente *',
                      emptyMessage: 'Selecciona un cliente.',
                      initialValue: _client,
                      enabled: !_saving,
                      onChanged: (client) => setState(() {
                        // Al cambiar de cliente, el vehículo elegido deja de ser válido.
                        if (_client?.id != client?.id) _vehicle = null;
                        _client = client;
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    VehicleSelectorField(
                      // La llave fuerza a reconstruir el campo al cambiar de cliente o limpiar el vehículo.
                      key: ValueKey('vehiculo-${_client?.id}-${_vehicle?.id}'),
                      initialValue: _vehicle,
                      enabled: !_saving && _client != null,
                      clientId: _client?.id,
                      serverError: _serverErrors['vehicleId'],
                      onChanged: (vehicle) => setState(() {
                        _vehicle = vehicle;
                        _dirty = true;
                        _serverErrors.remove('vehicleId');
                      }),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FormField<DateTime>(
                    key: ValueKey('fecha-${_when?.millisecondsSinceEpoch}-${_serverErrors['scheduledAt']}'),
                    initialValue: _when,
                    validator: (value) => _serverErrors['scheduledAt'] ?? (value == null ? 'Elige la fecha y la hora.' : null),
                    builder: (state) => InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      onTap: _saving ? null : _pickWhen,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Fecha y hora *',
                          errorText: state.errorText,
                          suffixIcon: const Icon(Icons.event, size: 20),
                        ),
                        isEmpty: _when == null,
                        child: _when == null ? const SizedBox.shrink() : Text(formatDateTime(_when!)),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _reason,
                    onChanged: (_) => _changed('reason'),
                    decoration: const InputDecoration(labelText: 'Motivo *'),
                    validator: (value) {
                      if (_serverErrors['reason'] != null) return _serverErrors['reason'];
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'El motivo es obligatorio.';
                      if (text.length > 255) return 'El motivo no puede pasar de 255 caracteres.';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _notes,
                    onChanged: (_) => _changed('notes'),
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Observaciones'),
                    validator: (value) {
                      if (_serverErrors['notes'] != null) return _serverErrors['notes'];
                      if ((value?.trim().length ?? 0) > 1000) return 'Las observaciones no pueden pasar de 1000 caracteres.';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Guardar'),
                      ),
                    ],
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
