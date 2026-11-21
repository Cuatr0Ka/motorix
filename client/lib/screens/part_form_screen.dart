import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/part.dart';
import '../services/api_client.dart';
import '../services/parts_service.dart';
import '../utils/formatters.dart';
import '../utils/tokens.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';

/// Formulario de refacción. Al crear pide el stock inicial; al editar ([existing]) el código no se puede
/// cambiar y el stock solo se modifica con entradas y ajustes. Termina devolviendo (`pop`) la refacción
/// guardada, o nada si se cancela.
class PartFormScreen extends StatefulWidget {
  const PartFormScreen({super.key, this.existing});

  final Part? existing;

  @override
  State<PartFormScreen> createState() => _PartFormScreenState();
}

class _PartFormScreenState extends State<PartFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.existing?.code);
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _unit = TextEditingController(text: widget.existing?.unit);
  late final _minStock = TextEditingController(text: widget.existing?.minStock.toString() ?? '0');
  final _initialStock = TextEditingController(text: '0');
  late final _category = TextEditingController(text: widget.existing?.category);
  late final _brand = TextEditingController(text: widget.existing?.brand);
  late final _purchasePrice = TextEditingController(text: widget.existing?.purchasePrice);
  late final _salePrice = TextEditingController(text: widget.existing?.salePrice);

  final Map<String, String> _serverErrors = {};
  bool _dirty = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final controller in [_code, _name, _description, _unit, _minStock, _initialStock, _category, _brand, _purchasePrice, _salePrice]) {
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

  String? _validateCode(String? value) {
    if (_serverErrors['code'] != null) return _serverErrors['code'];
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'El código es obligatorio.';
    if (text.length < 2) return 'El código debe tener al menos 2 caracteres.';
    if (text.length > 40) return 'El código no puede pasar de 40 caracteres.';
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(text)) return 'El código solo admite letras, números, guion y guion bajo.';
    return null;
  }

  String? _validateName(String? value) {
    if (_serverErrors['name'] != null) return _serverErrors['name'];
    final text = value?.trim() ?? '';
    if (text.length < 2) return 'El nombre debe tener al menos 2 caracteres.';
    if (text.length > 120) return 'El nombre no puede pasar de 120 caracteres.';
    return null;
  }

  String? _validateUnit(String? value) {
    if (_serverErrors['unit'] != null) return _serverErrors['unit'];
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'La unidad de medida es obligatoria.';
    if (text.length > 20) return 'La unidad no puede pasar de 20 caracteres.';
    return null;
  }

  String? _validateCount(String field, String label, String? value) {
    if (_serverErrors[field] != null) return _serverErrors[field];
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label es obligatorio.';
    final number = int.tryParse(text);
    if (number == null) return '$label debe ser un número entero.';
    if (number < 0) return '$label no puede ser negativo.';
    if (number > 1000000) return '$label no puede pasar de 1,000,000.';
    return null;
  }

  String? _validateText(String field, String label, String? value, int max) {
    if (_serverErrors[field] != null) return _serverErrors[field];
    if ((value?.trim().length ?? 0) > max) return '$label no puede pasar de $max caracteres.';
    return null;
  }

  /// Precio en pesos: opcional salvo [required]; sin negativos, con a lo sumo dos decimales y hasta 9,999,999.99.
  /// El precio de venta ([positive]) debe ser mayor a cero.
  String? _validatePrice(String field, String label, String? value, {bool positive = false, bool required = false}) {
    if (_serverErrors[field] != null) return _serverErrors[field];
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? '$label es obligatorio.' : null;
    if (text.startsWith('-')) return '$label no puede ser negativo.';
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) return '$label debe ser un número.';
    final parts = text.split('.');
    if (parts.length == 2 && parts[1].length > 2) return '$label puede tener a lo sumo dos decimales.';
    final cents = int.parse(parts[0]) * 100 + (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
    if (cents > 999999999) return '$label no puede pasar de 9,999,999.99.';
    if (positive && cents == 0) return '$label debe ser mayor a cero.';
    return null;
  }

  /// Texto de un precio capturado ("180.5" → "180.50"); vacío → null.
  String? _priceOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    final parts = text.split('.');
    return '${int.parse(parts[0])}.${(parts.length == 2 ? parts[1] : '').padRight(2, '0')}';
  }

  String? _textOrNull(TextEditingController controller) => controller.text.trim().isEmpty ? null : controller.text.trim();

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final input = PartInput(
      code: _isEdit ? null : _code.text.trim(),
      name: _name.text.trim(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      unit: _unit.text.trim(),
      minStock: int.parse(_minStock.text.trim()),
      initialStock: _isEdit ? null : int.parse(_initialStock.text.trim()),
      category: _textOrNull(_category),
      brand: _textOrNull(_brand),
      purchasePrice: _priceOrNull(_purchasePrice),
      salePrice: _priceOrNull(_salePrice),
    );
    await _submit(input);
  }

  /// Envía el formulario. Si el servidor avisa de una venta por debajo del costo (`PRICE_BELOW_COST`), pide la
  /// confirmación explícita y, solo si se acepta, reenvía con la bandera; cancelar no guarda nada.
  Future<void> _submit(PartInput input) async {
    setState(() => _saving = true);
    try {
      final service = context.read<PartsService>();
      final saved = _isEdit ? await service.update(widget.existing!.id, input) : await service.create(input);
      _dirty = false;
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'PRICE_BELOW_COST') {
        final sale = '${e.detailsMap['salePrice'] ?? input.salePrice}';
        final purchase = '${e.detailsMap['purchasePrice'] ?? input.purchasePrice}';
        final accepted = await showConfirmDialog(
          context,
          title: 'Venta por debajo del costo',
          message: 'El precio de venta (${formatMoney(sale)}) es menor al de compra (${formatMoney(purchase)}). ¿Guardar de todos modos?',
          confirmLabel: 'Guardar de todos modos',
        );
        if (accepted && mounted) {
          await _submit(input.confirmed());
          return;
        }
      } else {
        _showServerError(e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showServerError(ApiException e) {
    final fields = e.fieldErrors;
    if (fields.isNotEmpty || e.code == 'PART_CODE_TAKEN') {
      setState(() {
        for (final error in fields) {
          _serverErrors[error.field] = error.message;
        }
        if (e.code == 'PART_CODE_TAKEN') _serverErrors['code'] = e.message;
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
                    title: _isEdit ? 'Editar refacción' : 'Nueva refacción',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    key: const ValueKey('refaccion-codigo'),
                    controller: _code,
                    enabled: !_isEdit && !_saving,
                    onChanged: (_) => _changed('code'),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Código *',
                      helperText: _isEdit ? 'El código no se puede cambiar.' : null,
                    ),
                    validator: _isEdit ? null : _validateCode,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    key: const ValueKey('refaccion-nombre'),
                    controller: _name,
                    enabled: !_saving,
                    onChanged: (_) => _changed('name'),
                    decoration: const InputDecoration(labelText: 'Nombre *'),
                    validator: _validateName,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    key: const ValueKey('refaccion-descripcion'),
                    controller: _description,
                    enabled: !_saving,
                    onChanged: (_) => _changed('description'),
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    validator: (v) => (v?.trim().length ?? 0) > 500 ? 'La descripción no puede pasar de 500 caracteres.' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('refaccion-unidad'),
                          controller: _unit,
                          enabled: !_saving,
                          onChanged: (_) => _changed('unit'),
                          decoration: const InputDecoration(labelText: 'Unidad de medida *', hintText: 'pieza, litro, juego…'),
                          validator: _validateUnit,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('refaccion-minimo'),
                          controller: _minStock,
                          enabled: !_saving,
                          onChanged: (_) => _changed('minStock'),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Stock mínimo *'),
                          validator: (v) => _validateCount('minStock', 'El stock mínimo', v),
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
                          key: const ValueKey('refaccion-categoria'),
                          controller: _category,
                          enabled: !_saving,
                          onChanged: (_) => _changed('category'),
                          decoration: const InputDecoration(labelText: 'Categoría', hintText: 'Frenos, filtros, aceites…'),
                          validator: (v) => _validateText('category', 'La categoría', v, 60),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('refaccion-marca'),
                          controller: _brand,
                          enabled: !_saving,
                          onChanged: (_) => _changed('brand'),
                          decoration: const InputDecoration(labelText: 'Marca'),
                          validator: (v) => _validateText('brand', 'La marca', v, 60),
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
                          key: const ValueKey('refaccion-precio-compra'),
                          controller: _purchasePrice,
                          enabled: !_saving,
                          onChanged: (_) => _changed('purchasePrice'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Precio de compra', prefixText: '\$ '),
                          validator: (v) => _validatePrice('purchasePrice', 'El precio de compra', v),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('refaccion-precio-venta'),
                          controller: _salePrice,
                          enabled: !_saving,
                          onChanged: (_) => _changed('salePrice'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Precio de venta${widget.existing?.salePrice != null ? ' *' : ''}',
                            prefixText: '\$ ',
                            helperText: 'Sin precio de venta no se puede agregar a una orden.',
                            helperMaxLines: 2,
                          ),
                          validator: (v) => _validatePrice(
                            'salePrice',
                            'El precio de venta',
                            v,
                            positive: true,
                            required: widget.existing?.salePrice != null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_isEdit) ...[
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      key: const ValueKey('refaccion-stock-inicial'),
                      controller: _initialStock,
                      enabled: !_saving,
                      onChanged: (_) => _changed('initialStock'),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock inicial *',
                        helperText: 'Genera un movimiento de entrada «Stock inicial».',
                      ),
                      validator: (v) => _validateCount('initialStock', 'El stock inicial', v),
                    ),
                  ],
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
                        key: const ValueKey('guardar-refaccion'),
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Guardando…' : 'Guardar'),
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
