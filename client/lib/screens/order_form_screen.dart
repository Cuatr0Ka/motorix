import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../models/service_order.dart';
import '../models/vehicle.dart';
import '../services/api_client.dart';
import '../services/orders_service.dart';
import '../utils/formatters.dart';
import '../utils/tokens.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/mechanic_selector.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import '../widgets/vehicle_selector.dart';

/// Pide el motivo de una corrección de kilometraje. Devuelve el motivo (mínimo 5 caracteres) o null si se
/// cancela. [message] reproduce el aviso del servidor con el kilometraje registrado.
Future<String?> askMileageCorrection(BuildContext context, {required String message}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MileageCorrectionDialog(message: message),
  );
}

class _MileageCorrectionDialog extends StatefulWidget {
  const _MileageCorrectionDialog({required this.message});

  final String message;

  @override
  State<_MileageCorrectionDialog> createState() => _MileageCorrectionDialogState();
}

class _MileageCorrectionDialogState extends State<_MileageCorrectionDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    final text = _reason.text.trim();
    if (text.length < 5) {
      setState(() => _error = 'El motivo debe tener al menos 5 caracteres.');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Corregir kilometraje'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('motivo-correccion'),
              controller: _reason,
              maxLength: 255,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(labelText: 'Motivo de la corrección *', errorText: _error),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirm, child: const Text('Confirmar')),
      ],
    );
  }
}

/// Formulario de orden de servicio: directa (con vehículo) o desde una cita ([appointment]), en cuyo
/// caso el vehículo y el motivo vienen de la cita. Termina devolviendo (`pop`) la orden creada.
class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key, this.appointment});

  final Appointment? appointment;

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _problem = TextEditingController(text: widget.appointment?.reason);
  final _mileage = TextEditingController();

  Vehicle? _vehicle;
  int? _mechanicId;
  final Map<String, String> _serverErrors = {};
  bool _dirty = false;
  bool _saving = false;

  bool get _fromAppointment => widget.appointment != null;

  @override
  void dispose() {
    _problem.dispose();
    _mileage.dispose();
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

  String? _validateMileage(String? value) {
    if (_serverErrors['entryMileage'] != null) return _serverErrors['entryMileage'];
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'El kilometraje de entrada es obligatorio.';
    final mileage = int.tryParse(text);
    if (mileage == null) return 'El kilometraje debe ser un número entero.';
    if (mileage < 0) return 'El kilometraje no puede ser negativo.';
    if (mileage > 2000000) return 'El kilometraje no puede pasar de 2,000,000.';
    return null;
  }

  Future<void> _save({String? correctionReason}) async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;

    final input = OrderInput(
      vehicleId: _fromAppointment ? null : _vehicle!.id,
      appointmentId: widget.appointment?.id,
      entryMileage: int.parse(_mileage.text.trim()),
      reportedProblem: _problem.text.trim(),
      mechanicId: _mechanicId,
      mileageCorrection: correctionReason != null,
      mileageCorrectionReason: correctionReason,
    );

    setState(() => _saving = true);
    try {
      final created = await context.read<OrdersService>().create(input);
      _dirty = false;
      if (mounted) Navigator.of(context).pop(created);
    } on ApiException catch (e) {
      if (e.code == 'MILEAGE_DECREASE') {
        if (mounted) setState(() => _saving = false);
        await _offerCorrection(e);
        return;
      }
      _showServerError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// El kilometraje es menor al registrado: solo se acepta como corrección explícita con motivo.
  Future<void> _offerCorrection(ApiException e) async {
    final reason = await askMileageCorrection(context, message: e.message);
    if (reason != null && mounted) await _save(correctionReason: reason);
  }

  void _showServerError(ApiException e) {
    final byCode = {
      'OPEN_ORDER_EXISTS': 'vehicleId',
      'VEHICLE_NOT_FOUND': 'vehicleId',
    };
    final fields = e.fieldErrors;
    final field = byCode[e.code];
    if (fields.isNotEmpty || (field != null && !_fromAppointment)) {
      setState(() {
        for (final error in fields) {
          _serverErrors[error.field] = error.message;
        }
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
    final appointment = widget.appointment;
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
                    title: _fromAppointment ? 'Recibir vehículo' : 'Nueva orden',
                    subtitle: _fromAppointment ? 'Se creará la orden de servicio a partir de la cita' : null,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (appointment != null) ...[
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Cliente'),
                      child: Text(appointment.client.name),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Vehículo'),
                      child: Text(appointment.vehicle.label),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Cita del ${formatDateTime(appointment.scheduledAt)}', style: Theme.of(context).textTheme.bodySmall),
                  ] else ...[
                    VehicleSelectorField(
                      key: ValueKey('vehiculo-${_vehicle?.id}-${_serverErrors['vehicleId']}'),
                      initialValue: _vehicle,
                      enabled: !_saving,
                      serverError: _serverErrors['vehicleId'],
                      onChanged: (vehicle) => setState(() {
                        _vehicle = vehicle;
                        _dirty = true;
                        _serverErrors.remove('vehicleId');
                      }),
                    ),
                    if (_vehicle != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Cliente: ${_vehicle!.owner.name}'
                        '${_vehicle!.currentMileage != null ? ' · Kilometraje registrado: ${formatMileage(_vehicle!.currentMileage!)}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _mileage,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _changed('entryMileage'),
                    decoration: const InputDecoration(labelText: 'Kilometraje de entrada *', suffixText: 'km'),
                    validator: _validateMileage,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _problem,
                    onChanged: (_) => _changed('reportedProblem'),
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Problema reportado *'),
                    validator: (value) {
                      if (_serverErrors['reportedProblem'] != null) return _serverErrors['reportedProblem'];
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'El problema reportado es obligatorio.';
                      if (text.length > 1000) return 'El problema reportado no puede pasar de 1000 caracteres.';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  MechanicDropdown(
                    label: 'Mecánico (opcional)',
                    value: _mechanicId,
                    enabled: !_saving,
                    onChanged: (id) => setState(() {
                      _mechanicId = id;
                      _dirty = true;
                    }),
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
                        onPressed: _saving ? null : () => _save(),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_fromAppointment ? 'Crear orden' : 'Guardar'),
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
