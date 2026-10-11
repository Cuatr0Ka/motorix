import 'package:flutter/material.dart';

import '../models/maintenance.dart';
import '../utils/tokens.dart';

/// Diálogo para programar o editar un mantenimiento. Exige al menos fecha o kilometraje.
class MaintenanceDialog extends StatefulWidget {
  const MaintenanceDialog({super.key, this.existing});

  final Maintenance? existing;

  @override
  State<MaintenanceDialog> createState() => _MaintenanceDialogState();
}

class _MaintenanceDialogState extends State<MaintenanceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _date = TextEditingController(text: widget.existing?.dueDate == null ? '' : _iso(widget.existing!.dueDate!));
  late final _mileage = TextEditingController(text: widget.existing?.dueMileage?.toString() ?? '');
  String? _targetError;

  static String _iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _description.dispose();
    _date.dispose();
    _mileage.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String text) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
    final parsed = DateTime.tryParse(text);
    return parsed != null && _iso(parsed) == text ? parsed : null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseDate(_date.text.trim()) ?? now.add(const Duration(days: 180)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _date.text = _iso(picked));
  }

  String? _validateDate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = _parseDate(text);
    if (parsed == null) return 'Usa el formato AAAA-MM-DD.';
    final now = DateTime.now();
    if (parsed.isBefore(DateTime(now.year, now.month, now.day))) return 'La fecha no puede ser anterior a hoy.';
    return null;
  }

  String? _validateMileage(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    if (number == null || number < 0) return 'El kilometraje debe ser un número entero.';
    if (number > 2000000) return 'El kilometraje no puede pasar de 2,000,000.';
    return null;
  }

  void _save() {
    final valid = _formKey.currentState?.validate() ?? false;
    final hasDate = _date.text.trim().isNotEmpty;
    final hasMileage = _mileage.text.trim().isNotEmpty;
    setState(() => _targetError = hasDate || hasMileage ? null : 'Indica una fecha, un kilometraje o ambos.');
    if (!valid || (!hasDate && !hasMileage)) return;
    Navigator.of(context).pop(
      MaintenanceInput(
        description: _description.text.trim(),
        dueDate: hasDate ? _parseDate(_date.text.trim()) : null,
        dueMileage: hasMileage ? int.parse(_mileage.text.trim()) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Programar próximo mantenimiento' : 'Editar mantenimiento'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const ValueKey('mantenimiento-descripcion'),
                controller: _description,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Servicio por realizar *'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 3) return 'La descripción debe tener al menos 3 caracteres.';
                  if (text.length > 255) return 'La descripción no puede pasar de 255 caracteres.';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const ValueKey('mantenimiento-fecha'),
                controller: _date,
                decoration: InputDecoration(
                  labelText: 'Fecha objetivo (AAAA-MM-DD)',
                  suffixIcon: IconButton(
                    tooltip: 'Elegir fecha',
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    onPressed: _pickDate,
                  ),
                ),
                validator: _validateDate,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const ValueKey('mantenimiento-kilometraje'),
                controller: _mileage,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kilometraje objetivo', suffixText: 'km'),
                validator: _validateMileage,
              ),
              if (_targetError != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _targetError!,
                    key: const ValueKey('mantenimiento-objetivo-error'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
