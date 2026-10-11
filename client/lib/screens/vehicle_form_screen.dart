import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/client.dart';
import '../models/vehicle.dart';
import '../services/api_client.dart';
import '../services/vehicles_service.dart';
import '../utils/tokens.dart';
import '../widgets/client_selector.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';

/// Formulario de vehículo. El propietario es obligatorio; [owner] permite preseleccionarlo
/// (por ejemplo, al registrar un vehículo desde el detalle de un cliente). Con [existing] edita ese
/// vehículo, pidiendo confirmación al cambiar de propietario o al corregir un kilometraje menor.
/// Termina devolviendo (`pop`) el vehículo guardado, o nada si se cancela.
class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key, this.owner, this.existing});

  final Client? owner;
  final Vehicle? existing;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _brand = TextEditingController(text: widget.existing?.brand);
  late final _model = TextEditingController(text: widget.existing?.model);
  late final _year = TextEditingController(text: widget.existing?.year.toString());
  late final _plate = TextEditingController(text: widget.existing?.licensePlate);
  late final _vin = TextEditingController(text: widget.existing?.vin);
  late final _color = TextEditingController(text: widget.existing?.color);
  late final _mileage = TextEditingController(text: widget.existing?.currentMileage?.toString());

  late Client? _owner = widget.existing == null
      ? widget.owner
      : Client(
          id: widget.existing!.owner.id,
          name: widget.existing!.owner.name,
          phone: widget.existing!.owner.phone ?? '',
        );
  final Map<String, String> _serverErrors = {};
  bool _dirty = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final controller in [_brand, _model, _year, _plate, _vin, _color, _mileage]) {
      controller.dispose();
    }
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

  int get _maxYear => DateTime.now().year + 1;

  String? _required(String field, String label, String? value, int max, {bool feminine = true}) {
    if (_serverErrors[field] != null) return _serverErrors[field];
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label es ${feminine ? 'obligatoria' : 'obligatorio'}.';
    if (text.length > max) return '$label no puede pasar de $max caracteres.';
    return null;
  }

  String? _validateYear(String? value) {
    if (_serverErrors['year'] != null) return _serverErrors['year'];
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'El año es obligatorio.';
    final year = int.tryParse(text);
    if (year == null) return 'El año debe ser un número entero.';
    if (year < 1950) return 'El año no puede ser anterior a 1950.';
    if (year > _maxYear) return 'El año no puede pasar de $_maxYear.';
    return null;
  }

  String? _validateVin(String? value) {
    if (_serverErrors['vin'] != null) return _serverErrors['vin'];
    final text = value?.trim().toUpperCase() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(text)) {
      return 'El VIN debe tener 17 caracteres alfanuméricos, sin las letras I, O ni Q.';
    }
    return null;
  }

  String? _validateMileage(String? value) {
    if (_serverErrors['currentMileage'] != null) return _serverErrors['currentMileage'];
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final mileage = int.tryParse(text);
    if (mileage == null) return 'El kilometraje debe ser un número entero.';
    if (mileage < 0) return 'El kilometraje no puede ser negativo.';
    return null;
  }

  String? _optional(String field, String label, String? value, int max) {
    if (_serverErrors[field] != null) return _serverErrors[field];
    if ((value?.trim().length ?? 0) > max) return '$label no puede pasar de $max caracteres.';
    return null;
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final owner = _owner;
    if (owner == null) return;

    final input = VehicleInput(
      clientId: owner.id,
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      year: int.parse(_year.text.trim()),
      licensePlate: _plate.text.trim(),
      vin: _vin.text.trim().isEmpty ? null : _vin.text.trim().toUpperCase(),
      color: _color.text.trim().isEmpty ? null : _color.text.trim(),
      currentMileage: _mileage.text.trim().isEmpty ? null : int.parse(_mileage.text.trim()),
    );

    final service = context.read<VehiclesService>();
    var mileageCorrection = false;

    if (_isEdit) {
      final existing = widget.existing!;

      // Cambiar de propietario es un cambio sensible: pide confirmación.
      if (owner.id != existing.owner.id) {
        final confirmed = await showConfirmDialog(
          context,
          title: 'Cambiar propietario',
          message: '¿Seguro que quieres cambiar el propietario de este vehículo de '
              '${existing.owner.name} a ${owner.name}?',
        );
        if (!confirmed || !mounted) return;
      }

      // Un kilometraje menor al registrado solo se acepta como corrección explícita.
      final previous = existing.currentMileage;
      final next = input.currentMileage;
      if (previous != null && (next == null || next < previous)) {
        final confirmed = await showConfirmDialog(
          context,
          title: 'Corregir kilometraje',
          message: next == null
              ? 'Vas a borrar el kilometraje registrado ($previous km). ¿Es una corrección?'
              : 'El kilometraje nuevo ($next km) es menor al registrado ($previous km). ¿Es una corrección?',
        );
        if (!confirmed || !mounted) return;
        mileageCorrection = true;
      }
    }

    setState(() => _saving = true);
    try {
      final saved = _isEdit
          ? await service.update(widget.existing!.id, input, mileageCorrection: mileageCorrection)
          : await service.create(input);
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
      'PLATE_DUPLICATE': 'licensePlate',
      'VIN_DUPLICATE': 'vin',
      'OWNER_NOT_FOUND': 'clientId',
      'MILEAGE_DECREASE': 'currentMileage',
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
      // El selector de propietario recibe el error por parámetro: se valida cuando ya se reconstruyó.
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
                    title: _isEdit ? 'Editar vehículo' : 'Nuevo vehículo',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ClientSelectorField(
                    initialValue: _owner,
                    enabled: !_saving,
                    serverError: _serverErrors['clientId'],
                    onChanged: (client) => setState(() {
                      _owner = client;
                      _dirty = true;
                      _serverErrors.remove('clientId');
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _plate,
                    onChanged: (_) => _changed('licensePlate'),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Placa *'),
                    validator: (v) => _required('licensePlate', 'La placa', v, 15),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _brand,
                          onChanged: (_) => _changed('brand'),
                          decoration: const InputDecoration(labelText: 'Marca *'),
                          validator: (v) => _required('brand', 'La marca', v, 60),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: TextFormField(
                          controller: _model,
                          onChanged: (_) => _changed('model'),
                          decoration: const InputDecoration(labelText: 'Modelo *'),
                          validator: (v) => _required('model', 'El modelo', v, 60, feminine: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _year,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _changed('year'),
                          decoration: const InputDecoration(labelText: 'Año *'),
                          validator: _validateYear,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: TextFormField(
                          controller: _color,
                          onChanged: (_) => _changed('color'),
                          decoration: const InputDecoration(labelText: 'Color'),
                          validator: (v) => _optional('color', 'El color', v, 40),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _vin,
                    onChanged: (_) => _changed('vin'),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Número de serie (VIN)'),
                    validator: _validateVin,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _mileage,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _changed('currentMileage'),
                    decoration: const InputDecoration(labelText: 'Kilometraje actual', suffixText: 'km'),
                    validator: _validateMileage,
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
