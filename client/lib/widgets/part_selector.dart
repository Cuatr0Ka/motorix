import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/part.dart';
import '../services/api_client.dart';
import '../services/parts_service.dart';
import '../utils/tokens.dart';

/// Diálogo para agregar una refacción a una orden: busca en el catálogo (solo activas, con su
/// existencia), muestra las agotadas deshabilitadas y pide la cantidad. [onSubmit] envía la operación y
/// devuelve el mensaje de error del servidor (o null si salió bien); si falla, el diálogo conserva lo
/// capturado y muestra el error, por ejemplo «solo hay N disponibles».
class AddPartDialog extends StatefulWidget {
  const AddPartDialog({super.key, required this.onSubmit});

  final Future<String?> Function(Part part, int quantity) onSubmit;

  @override
  State<AddPartDialog> createState() => _AddPartDialogState();
}

class _AddPartDialogState extends State<AddPartDialog> {
  final _formKey = GlobalKey<FormState>();
  final _search = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  Timer? _timer;

  List<Part> _parts = [];
  Part? _selected;
  String? _listError;
  String? _submitError;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadParts('');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _loadParts(String term) async {
    setState(() {
      _loading = true;
      _listError = null;
    });
    try {
      final result = await context.read<PartsService>().list(search: term, pageSize: 50);
      if (!mounted) return;
      setState(() {
        _parts = result.items;
        if (_selected != null && !_parts.any((p) => p.id == _selected!.id)) _selected = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _listError = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String value) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () => _loadParts(value.trim()));
  }

  String? _validateQuantity(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'La cantidad es obligatoria.';
    final number = int.tryParse(text);
    if (number == null) return 'La cantidad debe ser un número entero.';
    if (number < 1) return 'La cantidad debe ser al menos 1.';
    if (number > 100000) return 'La cantidad no puede pasar de 100,000.';
    return null;
  }

  Future<void> _submit() async {
    final part = _selected;
    if (part == null) {
      setState(() => _submitError = 'Elige una refacción de la lista.');
      return;
    }
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final failure = await widget.onSubmit(part, int.parse(_quantity.text.trim()));
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _submitError = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Agregar refacción'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('buscar-refaccion'),
                controller: _search,
                autofocus: true,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  labelText: 'Buscar refacción',
                  hintText: 'Código o nombre',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 220,
                child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                    : _listError != null
                        ? Center(child: Text(_listError!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger)))
                        : _parts.isEmpty
                            ? Center(child: Text('No se encontraron refacciones activas.', style: theme.textTheme.bodyMedium))
                            : ListView(
                                children: [
                                  for (final part in _parts)
                                    ListTile(
                                      key: ValueKey('opcion-refaccion-${part.id}'),
                                      dense: true,
                                      selected: _selected?.id == part.id,
                                      selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                      enabled: !part.isOutOfStock,
                                      title: Text(part.label, overflow: TextOverflow.ellipsis),
                                      subtitle: Text(part.isOutOfStock ? 'Agotada' : 'Existencia: ${part.stock} ${part.unit}'),
                                      trailing: _selected?.id == part.id ? const Icon(Icons.check, size: 18) : null,
                                      onTap: part.isOutOfStock
                                          ? null
                                          : () => setState(() {
                                                _selected = part;
                                                _submitError = null;
                                              }),
                                    ),
                                ],
                              ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey('cantidad-refaccion'),
                controller: _quantity,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (_submitError != null) setState(() => _submitError = null);
                },
                decoration: InputDecoration(
                  labelText: 'Cantidad *',
                  helperText: _selected == null ? null : 'Existencia: ${_selected!.stock} ${_selected!.unit}',
                ),
                validator: _validateQuantity,
              ),
              if (_submitError != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _submitError!,
                    key: const ValueKey('error-agregar-refaccion'),
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('confirmar-agregar-refaccion'),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Guardando…' : 'Agregar'),
        ),
      ],
    );
  }
}
