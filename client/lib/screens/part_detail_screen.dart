import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/part.dart';
import '../providers/part_detail_provider.dart';
import '../providers/stock_alerts_provider.dart';
import '../services/parts_service.dart';
import '../utils/formatters.dart';
import '../utils/tokens.dart';
import '../widgets/app_data_table.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import '../widgets/stock_chip.dart';
import 'part_form_screen.dart';

/// Detalle de una refacción (solo administración): datos, stock, movimientos y acciones de inventario
/// (entrada de mercancía, ajuste por conteo, edición y activar o desactivar).
class PartDetailScreen extends StatelessWidget {
  const PartDetailScreen({super.key, required this.partId});

  final int partId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PartDetailProvider>(
      create: (context) => PartDetailProvider(context.read<PartsService>(), partId)..load(),
      child: const _PartDetailView(),
    );
  }
}

class _PartDetailView extends StatelessWidget {
  const _PartDetailView();

  void _report(BuildContext context, String? failure, String success) {
    if (!context.mounted) return;
    if (failure == null) {
      // Cualquier movimiento puede cambiar las alertas de stock bajo.
      context.read<StockAlertsProvider>().refresh();
      showSuccess(context, success);
    } else {
      showFailure(context, failure);
    }
  }

  Future<void> _edit(BuildContext context, Part part) async {
    final provider = context.read<PartDetailProvider>();
    final saved = await Navigator.of(context).push<Part>(MaterialPageRoute(builder: (_) => PartFormScreen(existing: part)));
    if (saved == null || !context.mounted) return;
    await provider.load();
    if (context.mounted) showSuccess(context, 'Refacción actualizada correctamente.');
  }

  Future<void> _receive(BuildContext context) async {
    final provider = context.read<PartDetailProvider>();
    final entry = await showDialog<({int quantity, String? reason})>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _EntryDialog(),
    );
    if (entry == null || !context.mounted) return;
    final failure = await provider.receive(entry.quantity, reason: entry.reason);
    if (!context.mounted) return;
    _report(context, failure, 'Entrada registrada correctamente.');
  }

  Future<void> _adjust(BuildContext context, Part part) async {
    final provider = context.read<PartDetailProvider>();
    final adjustment = await showDialog<({int counted, String reason})>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdjustDialog(stock: part.stock),
    );
    if (adjustment == null || !context.mounted) return;
    final difference = adjustment.counted - part.stock;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Aplicar ajuste de inventario',
      message: 'Stock actual: ${part.stock}. Cantidad contada: ${adjustment.counted}. '
          'Diferencia: ${difference > 0 ? '+$difference' : '$difference'}. '
          'El ajuste queda registrado y no se puede deshacer.',
      confirmLabel: 'Aplicar ajuste',
    );
    if (!confirmed || !context.mounted) return;
    final failure = await provider.adjust(adjustment.counted, adjustment.reason);
    if (!context.mounted) return;
    _report(context, failure, 'Ajuste aplicado correctamente.');
  }

  Future<void> _toggleActive(BuildContext context, Part part) async {
    final provider = context.read<PartDetailProvider>();
    if (part.active) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Desactivar refacción',
        message: '¿Seguro que quieres desactivar "${part.name}"? Dejará de ofrecerse para nuevas órdenes, '
            'pero se conserva su historial.',
        confirmLabel: 'Desactivar',
      );
      if (!confirmed || !context.mounted) return;
    }
    final failure = await provider.setActive(!part.active);
    if (!context.mounted) return;
    _report(context, failure, part.active ? 'Refacción desactivada.' : 'Refacción reactivada.');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PartDetailProvider>();
    final part = provider.part;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: part == null ? 'Refacción' : '${part.code} · ${part.name}',
            subtitle: 'Detalle de la refacción',
            onBack: () => Navigator.of(context).maybePop(),
            actions: [
              if (part != null) ...[
                OutlinedButton.icon(
                  key: const ValueKey('editar-refaccion'),
                  onPressed: provider.busy ? null : () => _edit(context, part),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: provider.loading && part == null
                ? const LoadingView()
                : provider.error != null && part == null
                    ? ErrorView(message: provider.error!, onRetry: provider.load)
                    : part == null
                        ? const SizedBox.shrink()
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DataPanel(part: part),
                                const SizedBox(height: AppSpacing.lg),
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: [
                                    FilledButton.icon(
                                      key: const ValueKey('registrar-entrada'),
                                      onPressed: provider.busy || !part.active ? null : () => _receive(context),
                                      icon: const Icon(Icons.add_box_outlined, size: 18),
                                      label: const Text('Registrar entrada'),
                                    ),
                                    OutlinedButton.icon(
                                      key: const ValueKey('ajustar-inventario'),
                                      onPressed: provider.busy ? null : () => _adjust(context, part),
                                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                                      label: const Text('Ajustar inventario'),
                                    ),
                                    OutlinedButton.icon(
                                      key: const ValueKey('activar-refaccion'),
                                      onPressed: provider.busy ? null : () => _toggleActive(context, part),
                                      icon: Icon(part.active ? Icons.block : Icons.check_circle_outline, size: 18),
                                      label: Text(part.active ? 'Desactivar' : 'Reactivar'),
                                    ),
                                  ],
                                ),
                                if (!part.active)
                                  Padding(
                                    padding: const EdgeInsets.only(top: AppSpacing.md),
                                    child: Text(
                                      'Refacción inactiva: no se ofrece en nuevas órdenes ni admite entradas.',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                const SizedBox(height: AppSpacing.xl),
                                Text('Movimientos', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: AppSpacing.md),
                                _Movements(part: part),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({required this.part});

  final Part part;

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
      child: Column(
        children: [
          DetailRow(label: 'Código', value: part.code),
          const Divider(),
          DetailRow(label: 'Nombre', value: part.name),
          const Divider(),
          DetailRow(label: 'Descripción', value: part.description),
          const Divider(),
          DetailRow(label: 'Unidad', value: part.unit),
          const Divider(),
          DetailRow(label: 'Stock actual', value: '${part.stock}'),
          const Divider(),
          DetailRow(label: 'Stock mínimo', value: '${part.minStock}'),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(width: 140, child: Text('Estado', style: Theme.of(context).textTheme.bodySmall)),
                StockChip(status: part.stockStatus, active: part.active),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Movements extends StatelessWidget {
  const _Movements({required this.part});

  final Part part;

  @override
  Widget build(BuildContext context) {
    if (part.movements.isEmpty) {
      return const EmptyView(message: 'Esta refacción todavía no tiene movimientos.');
    }
    return SizedBox(
      height: 52.0 * (part.movements.length + 1) + 8,
      child: AppDataTable(
        minWidth: 760,
        columns: const [
          DataColumn2(label: Text('Fecha'), fixedWidth: 150),
          DataColumn2(label: Text('Tipo'), fixedWidth: 90),
          DataColumn2(label: Text('Cantidad'), fixedWidth: 100, numeric: true),
          DataColumn2(label: Text('Motivo'), size: ColumnSize.L),
          DataColumn2(label: Text('Orden'), fixedWidth: 110),
          DataColumn2(label: Text('Persona'), size: ColumnSize.M),
        ],
        rows: [
          for (final movement in part.movements)
            DataRow2(
              key: ValueKey('movimiento-${movement.id}'),
              cells: [
                DataCell(Text(formatDateTime(movement.createdAt))),
                DataCell(Text(movement.type.label)),
                DataCell(Text(movement.signedLabel)),
                DataCell(Text(movement.reason ?? '—', overflow: TextOverflow.ellipsis)),
                DataCell(Text(movement.orderFolio ?? '—')),
                DataCell(Text(movement.createdBy ?? '—', overflow: TextOverflow.ellipsis)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Diálogo de entrada de mercancía: cantidad entera positiva y motivo opcional.
class _EntryDialog extends StatefulWidget {
  const _EntryDialog();

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
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

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final reason = _reason.text.trim();
    Navigator.of(context).pop((quantity: int.parse(_quantity.text.trim()), reason: reason.isEmpty ? null : reason));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar entrada'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('entrada-cantidad'),
                controller: _quantity,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad *'),
                validator: _validateQuantity,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const ValueKey('entrada-motivo'),
                controller: _reason,
                decoration: const InputDecoration(labelText: 'Motivo', hintText: 'Compra a proveedor'),
                validator: (v) => (v?.trim().length ?? 0) > 255 ? 'El motivo no puede pasar de 255 caracteres.' : null,
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

/// Diálogo de ajuste por conteo físico: cantidad contada (≥ 0) y motivo obligatorio. Muestra la diferencia.
class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.stock});

  final int stock;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final _formKey = GlobalKey<FormState>();
  final _counted = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _counted.dispose();
    _reason.dispose();
    super.dispose();
  }

  int? get _countedValue => int.tryParse(_counted.text.trim());

  String? _validateCounted(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'La cantidad contada es obligatoria.';
    final number = int.tryParse(text);
    if (number == null) return 'La cantidad contada debe ser un número entero.';
    if (number < 0) return 'La cantidad contada no puede ser negativa.';
    if (number > 1000000) return 'La cantidad contada no puede pasar de 1,000,000.';
    if (number == widget.stock) return 'La cantidad contada es igual al stock actual: no hay nada que ajustar.';
    return null;
  }

  String? _validateReason(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 5) return 'El motivo debe tener al menos 5 caracteres.';
    if (text.length > 255) return 'El motivo no puede pasar de 255 caracteres.';
    return null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((counted: int.parse(_counted.text.trim()), reason: _reason.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final counted = _countedValue;
    final difference = counted == null ? null : counted - widget.stock;
    return AlertDialog(
      title: const Text('Ajustar inventario'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stock actual: ${widget.stock}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey('ajuste-contada'),
                controller: _counted,
                autofocus: true,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Cantidad contada *'),
                validator: _validateCounted,
              ),
              if (difference != null && difference != 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'Diferencia: ${difference > 0 ? '+$difference' : '$difference'}',
                    key: const ValueKey('ajuste-diferencia'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const ValueKey('ajuste-motivo'),
                controller: _reason,
                decoration: const InputDecoration(labelText: 'Motivo *', hintText: 'Conteo físico de octubre'),
                validator: _validateReason,
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Continuar')),
      ],
    );
  }
}
