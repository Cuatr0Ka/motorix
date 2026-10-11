import 'package:flutter/material.dart';

import '../models/order_work.dart';
import '../utils/tokens.dart';
import 'confirm_dialog.dart';
import 'panel_card.dart';

/// Acciones de la sección de refacciones de la orden. [onAdd] abre el selector; [onUpdate] y [onRemove]
/// devuelven el mensaje de error del servidor (o null si salió bien).
class OrderPartsActions {
  const OrderPartsActions({required this.onAdd, required this.onUpdate, required this.onRemove});

  final Future<void> Function() onAdd;
  final Future<String?> Function(OrderPart line, int quantity) onUpdate;
  final Future<void> Function(OrderPart line) onRemove;
}

/// Tarjeta «Refacciones utilizadas» del detalle de la orden. [actions] llega solo si el rol puede
/// modificarlas (mecánico asignado y administración, con la orden no entregada); sin él, es de consulta.
class OrderPartsSection extends StatelessWidget {
  const OrderPartsSection({super.key, required this.parts, this.actions, this.busy = false});

  final List<OrderPart> parts;
  final OrderPartsActions? actions;
  final bool busy;

  Future<void> _edit(BuildContext context, OrderPart line) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuantityDialog(line: line, onSubmit: (quantity) => actions!.onUpdate(line, quantity)),
    );
  }

  Future<void> _remove(BuildContext context, OrderPart line) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Quitar refacción',
      message: '¿Seguro que quieres quitar "${line.name}" (${line.quantity} ${line.unit}) de la orden? '
          'La cantidad regresa al inventario.',
      confirmLabel: 'Quitar',
    );
    if (!confirmed || !context.mounted) return;
    await actions!.onRemove(line);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PanelCard(
      title: 'Refacciones utilizadas',
      trailing: actions == null
          ? null
          : TextButton.icon(
              key: const ValueKey('agregar-refaccion'),
              onPressed: busy ? null : () => actions!.onAdd(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Agregar refacción'),
            ),
      child: parts.isEmpty
          ? Text('Sin refacciones registradas.', style: theme.textTheme.bodyMedium)
          : Column(
              children: [
                for (final line in parts)
                  Padding(
                    key: ValueKey('refaccion-orden-${line.id}'),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(child: Text('${line.code} · ${line.name}', overflow: TextOverflow.ellipsis)),
                        Text('${line.quantity} ${line.unit}', key: ValueKey('cantidad-orden-${line.id}')),
                        if (actions != null) ...[
                          IconButton(
                            key: ValueKey('editar-refaccion-orden-${line.id}'),
                            tooltip: 'Corregir cantidad',
                            visualDensity: VisualDensity.compact,
                            onPressed: busy ? null : () => _edit(context, line),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
                            key: ValueKey('quitar-refaccion-orden-${line.id}'),
                            tooltip: 'Quitar',
                            visualDensity: VisualDensity.compact,
                            onPressed: busy ? null : () => _remove(context, line),
                            icon: const Icon(Icons.delete_outline, size: 18),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Diálogo para corregir la cantidad total de una línea. Conserva lo capturado si el servidor rechaza el
/// cambio (por ejemplo, por stock insuficiente) y muestra su mensaje.
class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.line, required this.onSubmit});

  final OrderPart line;
  final Future<String?> Function(int quantity) onSubmit;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: '${widget.line.quantity}');
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'La cantidad es obligatoria.';
    final number = int.tryParse(text);
    if (number == null) return 'La cantidad debe ser un número entero.';
    if (number < 1) return 'La cantidad debe ser al menos 1.';
    if (number > 100000) return 'La cantidad no puede pasar de 100,000.';
    return null;
  }

  Future<void> _save() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final failure = await widget.onSubmit(int.parse(_controller.text.trim()));
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _error = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Corregir cantidad · ${widget.line.name}'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const ValueKey('cantidad-corregida'),
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Cantidad total *', suffixText: widget.line.unit),
                validator: _validate,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _error!,
                    key: const ValueKey('error-corregir-refaccion'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _submitting ? null : _save, child: Text(_submitting ? 'Guardando…' : 'Guardar')),
      ],
    );
  }
}
