import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order_work.dart';
import '../models/service_order.dart';
import '../models/user.dart';
import '../providers/order_detail_provider.dart';
import '../providers/session_provider.dart';
import '../services/orders_service.dart';
import '../utils/formatters.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/mechanic_selector.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import '../widgets/status_chip.dart';

/// Detalle de una orden: datos generales, trabajo registrado, totales e historial de estados.
/// Según el rol, permite asignar mecánico (recepción y administración), registrar el trabajo (mecánico
/// asignado y administración) y cambiar el estado. El servidor valida todos los permisos.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OrderDetailProvider>(
      create: (context) => OrderDetailProvider(context.read<OrdersService>(), orderId)..load(),
      child: const _OrderDetailView(),
    );
  }
}

class _OrderDetailView extends StatelessWidget {
  const _OrderDetailView();

  /// Muestra el resultado de una acción: éxito breve o el error del servidor en español.
  void _report(BuildContext context, String? failure, String success) {
    if (!context.mounted) return;
    if (failure == null) {
      showSuccess(context, success);
    } else {
      showFailure(context, failure);
    }
  }

  Future<void> _assign(BuildContext context, ServiceOrder order) async {
    final provider = context.read<OrderDetailProvider>();
    final chosen = await showDialog<({int? id})>(
      context: context,
      builder: (_) => _AssignMechanicDialog(current: order.mechanic?.id, canClear: order.status == OrderStatus.received),
    );
    if (chosen == null || !context.mounted) return;
    final failure = await provider.assignMechanic(chosen.id);
    if (!context.mounted) return;
    _report(
      context,
      failure,
      chosen.id == null ? 'Se quitó la asignación del mecánico.' : 'Mecánico asignado correctamente.',
    );
  }

  Future<void> _editField(BuildContext context, {required String field, required String title, required String? current}) async {
    final provider = context.read<OrderDetailProvider>();
    final text = await showDialog<({String value})>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TextEditDialog(title: title, initial: current ?? ''),
    );
    if (text == null || !context.mounted) return;
    final failure = await provider.saveWorkField(field, text.value.trim().isEmpty ? null : text.value.trim());
    if (!context.mounted) return;
    _report(context, failure, 'Información guardada correctamente.');
  }

  Future<void> _editLine(BuildContext context, OrderLineKind kind, {OrderLine? line}) async {
    final provider = context.read<OrderDetailProvider>();
    final input = await showDialog<OrderLineInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LineDialog(kind: kind, existing: line),
    );
    if (input == null || !context.mounted) return;
    final failure = line == null ? await provider.addLine(kind, input) : await provider.updateLine(kind, line.id, input);
    if (!context.mounted) return;
    _report(context, failure, line == null ? 'Línea agregada correctamente.' : 'Línea actualizada correctamente.');
  }

  Future<void> _removeLine(BuildContext context, OrderLineKind kind, OrderLine line) async {
    final provider = context.read<OrderDetailProvider>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Quitar línea',
      message: '¿Seguro que quieres quitar "${line.description}" (${formatMoney(line.amount)}) de la orden?',
    );
    if (!confirmed || !context.mounted) return;
    final failure = await provider.removeLine(kind, line.id);
    if (!context.mounted) return;
    _report(context, failure, 'Línea quitada correctamente.');
  }

  /// Cambia el estado. La entrega pide confirmación; el servidor valida la secuencia, el rol y la pertenencia.
  Future<void> _changeStatus(BuildContext context, ServiceOrder order, OrderStatus status) async {
    final provider = context.read<OrderDetailProvider>();
    if (status == OrderStatus.delivered) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Registrar entrega',
        message: '¿Confirmas la entrega de la orden ${order.folio} al cliente? Una orden entregada queda como '
            'historial y ya no puede modificarse.',
      );
      if (!confirmed || !context.mounted) return;
    }
    final failure = await provider.changeStatus(status);
    if (!context.mounted) return;
    _report(context, failure, 'Estado actualizado a ${status.label}.');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderDetailProvider>();
    final order = provider.order;
    final role = context.watch<SessionProvider>().user?.role;
    final canAssign = (role == UserRole.admin || role == UserRole.receptionist) && (order?.isAssignable ?? false);
    final canEditWork = (role == UserRole.admin || role == UserRole.mechanic) && !(order?.isDelivered ?? true);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: order?.folio ?? 'Orden',
            subtitle: 'Orden de servicio',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: provider.loading && order == null
                ? const LoadingView()
                : provider.error != null && order == null
                    ? ErrorView(message: provider.error!, onRetry: provider.load)
                    : order == null
                        ? const SizedBox.shrink()
                        : SingleChildScrollView(
                            child: OrderSections(
                              order: order,
                              busy: provider.busy,
                              onChangeStatus: (status) => _changeStatus(context, order, status),
                              assignAction: canAssign
                                  ? OutlinedButton.icon(
                                      key: const ValueKey('asignar-mecanico'),
                                      onPressed: provider.busy ? null : () => _assign(context, order),
                                      icon: const Icon(Icons.engineering_outlined, size: 18),
                                      label: Text(order.mechanic == null ? 'Asignar mecánico' : 'Reasignar mecánico'),
                                    )
                                  : null,
                              editing: canEditWork
                                  ? OrderEditing(
                                      onEditDiagnosis: () =>
                                          _editField(context, field: 'diagnosis', title: 'Diagnóstico', current: order.diagnosis),
                                      onEditObservations: () => _editField(
                                        context,
                                        field: 'observations',
                                        title: 'Observaciones',
                                        current: order.observations,
                                      ),
                                      onEditRecommendations: () => _editField(
                                        context,
                                        field: 'recommendations',
                                        title: 'Recomendaciones',
                                        current: order.recommendations,
                                      ),
                                      onAddLine: (kind) => _editLine(context, kind),
                                      onEditLine: (kind, line) => _editLine(context, kind, line: line),
                                      onRemoveLine: (kind, line) => _removeLine(context, kind, line),
                                    )
                                  : null,
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

/// Acciones de edición del trabajo de la orden. Si es null, las secciones se muestran en solo lectura.
class OrderEditing {
  const OrderEditing({
    required this.onEditDiagnosis,
    required this.onEditObservations,
    required this.onEditRecommendations,
    required this.onAddLine,
    required this.onEditLine,
    required this.onRemoveLine,
  });

  final VoidCallback onEditDiagnosis;
  final VoidCallback onEditObservations;
  final VoidCallback onEditRecommendations;
  final void Function(OrderLineKind kind) onAddLine;
  final void Function(OrderLineKind kind, OrderLine line) onEditLine;
  final void Function(OrderLineKind kind, OrderLine line) onRemoveLine;
}

/// Texto del botón de una transición, según el estado de origen.
String _transitionLabel(OrderStatus from, OrderStatus to) {
  switch (to) {
    case OrderStatus.diagnosis:
      return 'Iniciar diagnóstico';
    case OrderStatus.repairing:
      return from == OrderStatus.waitingPart ? 'Reanudar reparación' : 'Iniciar reparación';
    case OrderStatus.waitingPart:
      return 'Esperando refacción';
    case OrderStatus.finished:
      return 'Marcar como terminada';
    case OrderStatus.delivered:
      return 'Registrar entrega';
    case OrderStatus.received:
      return to.label;
  }
}

/// Panel con borde fino del sistema de diseño.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Secciones del detalle de la orden. [assignAction] y [editing] llegan solo si el rol puede usarlos.
class OrderSections extends StatelessWidget {
  const OrderSections({
    super.key,
    required this.order,
    this.assignAction,
    this.editing,
    this.busy = false,
    this.onChangeStatus,
  });

  final ServiceOrder order;

  /// Cambia el estado de la orden. Los botones se generan con `order.allowedTransitions`, que el servidor ya
  /// filtra por rol y pertenencia, de modo que la matriz de estados no se duplica en el cliente.
  final ValueChanged<OrderStatus>? onChangeStatus;

  /// Botón para asignar o reasignar mecánico (solo recepción y administración, mientras la orden siga abierta).
  final Widget? assignAction;

  /// Acciones para registrar el trabajo (mecánico asignado y administración, mientras no esté entregada).
  final OrderEditing? editing;

  /// Hay una acción en curso: se deshabilitan los botones de edición.
  final bool busy;

  Widget _editButton(String key, String label, VoidCallback? onPressed) => TextButton.icon(
        key: ValueKey(key),
        onPressed: busy ? null : onPressed,
        icon: const Icon(Icons.edit_outlined, size: 16),
        label: Text(label),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = this.editing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order.isDelivered)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
            ),
            child: Text('Orden entregada: solo lectura.', style: theme.textTheme.bodyMedium),
          ),
        SectionCard(
          title: 'Datos de la orden',
          trailing: StatusChip.order(order.status),
          child: Column(
            children: [
              DetailRow(label: 'Folio', value: order.folio),
              const Divider(),
              DetailRow(label: 'Fecha de recepción', value: formatDateTime(order.createdAt)),
              const Divider(),
              DetailRow(label: 'Cliente', value: order.client.name),
              const Divider(),
              DetailRow(label: 'Vehículo', value: order.vehicle.label),
              const Divider(),
              DetailRow(label: 'Kilometraje de entrada', value: formatMileage(order.entryMileage)),
              if (order.mileageCorrection) ...[
                const Divider(),
                DetailRow(label: 'Corrección de kilometraje', value: order.mileageCorrectionReason),
              ],
              const Divider(),
              DetailRow(label: 'Mecánico', value: order.mechanic?.name ?? 'Sin asignar'),
              if (assignAction != null) Align(alignment: Alignment.centerRight, child: assignAction),
              const Divider(),
              DetailRow(label: 'Problema reportado', value: order.reportedProblem),
            ],
          ),
        ),
        if (!order.isDelivered && (order.allowedTransitions.isNotEmpty || (order.mechanic == null && order.status == OrderStatus.received)))
          SectionCard(
            title: 'Avance de la orden',
            child: order.allowedTransitions.isEmpty
                ? Text('Asigna un mecánico para iniciar el trabajo.', style: theme.textTheme.bodyMedium)
                : Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final next in order.allowedTransitions)
                        FilledButton(
                          key: ValueKey('cambiar-estado-${next.apiValue}'),
                          onPressed: busy || onChangeStatus == null ? null : () => onChangeStatus!(next),
                          child: Text(_transitionLabel(order.status, next)),
                        ),
                    ],
                  ),
          ),
        SectionCard(
          title: 'Diagnóstico',
          trailing: editing == null ? null : _editButton('editar-diagnostico', 'Editar', editing.onEditDiagnosis),
          child: Text(
            (order.diagnosis == null || order.diagnosis!.isEmpty) ? 'Sin diagnóstico registrado.' : order.diagnosis!,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        SectionCard(
          title: 'Servicios realizados',
          trailing: editing == null
              ? null
              : _editButton('agregar-servicio', 'Agregar servicio', () => editing.onAddLine(OrderLineKind.services)),
          child: _Lines(
            kind: OrderLineKind.services,
            lines: order.services,
            emptyText: 'Sin servicios registrados.',
            editing: editing,
            busy: busy,
          ),
        ),
        SectionCard(
          title: 'Mano de obra',
          trailing: editing == null
              ? null
              : _editButton('agregar-mano-de-obra', 'Agregar mano de obra', () => editing.onAddLine(OrderLineKind.labor)),
          child: _Lines(
            kind: OrderLineKind.labor,
            lines: order.labor,
            emptyText: 'Sin mano de obra registrada.',
            editing: editing,
            busy: busy,
          ),
        ),
        SectionCard(
          title: 'Totales',
          child: Column(
            children: [
              DetailRow(label: 'Servicios', value: formatMoney(order.totals.services)),
              DetailRow(label: 'Mano de obra', value: formatMoney(order.totals.labor)),
              const Divider(),
              DetailRow(label: 'Total', value: formatMoney(order.totals.total)),
            ],
          ),
        ),
        SectionCard(
          title: 'Observaciones y recomendaciones',
          child: Column(
            children: [
              DetailRow(label: 'Observaciones', value: order.observations),
              if (editing != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: _editButton('editar-observaciones', 'Editar observaciones', editing.onEditObservations),
                ),
              const Divider(),
              DetailRow(label: 'Recomendaciones', value: order.recommendations),
              if (editing != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: _editButton('editar-recomendaciones', 'Editar recomendaciones', editing.onEditRecommendations),
                ),
            ],
          ),
        ),
        SectionCard(
          title: 'Historial de estados',
          child: Column(
            children: [
              for (final change in order.statusHistory)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      SizedBox(width: 150, child: Text(formatDateTime(change.changedAt), style: theme.textTheme.bodySmall)),
                      StatusChip.order(change.toStatus),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(change.changedBy, style: theme.textTheme.bodySmall)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({
    required this.kind,
    required this.lines,
    required this.emptyText,
    required this.editing,
    required this.busy,
  });

  final OrderLineKind kind;
  final List<OrderLine> lines;
  final String emptyText;
  final OrderEditing? editing;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return Text(emptyText, style: Theme.of(context).textTheme.bodyMedium);
    return Column(
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(child: Text(line.description)),
                Text(formatMoney(line.amount)),
                if (editing != null) ...[
                  IconButton(
                    key: ValueKey('editar-${kind.path}-${line.id}'),
                    tooltip: 'Editar',
                    visualDensity: VisualDensity.compact,
                    onPressed: busy ? null : () => editing!.onEditLine(kind, line),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    key: ValueKey('quitar-${kind.path}-${line.id}'),
                    tooltip: 'Quitar',
                    visualDensity: VisualDensity.compact,
                    onPressed: busy ? null : () => editing!.onRemoveLine(kind, line),
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Diálogo para elegir el mecánico de la orden. Devuelve `(id: ...)` o null si se cancela; `id` null
/// significa quitar la asignación (solo mientras la orden esté Recibida).
class _AssignMechanicDialog extends StatefulWidget {
  const _AssignMechanicDialog({required this.current, required this.canClear});

  final int? current;
  final bool canClear;

  @override
  State<_AssignMechanicDialog> createState() => _AssignMechanicDialogState();
}

class _AssignMechanicDialogState extends State<_AssignMechanicDialog> {
  late int? _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    final changed = _selected != widget.current;
    final canConfirm = changed && (_selected != null || widget.canClear);
    return AlertDialog(
      title: Text(widget.current == null ? 'Asignar mecánico' : 'Reasignar mecánico'),
      content: SizedBox(
        width: 380,
        child: MechanicDropdown(
          value: _selected,
          label: 'Mecánico',
          onChanged: (id) => setState(() => _selected = id),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: canConfirm ? () => Navigator.of(context).pop((id: _selected)) : null,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

/// Diálogo con un campo de texto largo (diagnóstico, observaciones o recomendaciones).
class _TextEditDialog extends StatefulWidget {
  const _TextEditDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_controller.text.trim().length > 5000) {
      setState(() => _error = '${widget.title} no puede pasar de 5,000 caracteres.');
      return;
    }
    Navigator.of(context).pop((value: _controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: TextField(
          key: const ValueKey('texto-trabajo'),
          controller: _controller,
          autofocus: true,
          minLines: 4,
          maxLines: 10,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(labelText: widget.title, errorText: _error),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

/// Diálogo para agregar o corregir una línea de servicio o de mano de obra.
class _LineDialog extends StatefulWidget {
  const _LineDialog({required this.kind, this.existing});

  final OrderLineKind kind;
  final OrderLine? existing;

  @override
  State<_LineDialog> createState() => _LineDialogState();
}

class _LineDialogState extends State<_LineDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _amount = TextEditingController(text: widget.existing?.amount);

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'El importe es obligatorio.';
    if (text.startsWith('-')) return 'El importe no puede ser negativo.';
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) return 'El importe debe ser un número.';
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) return 'El importe admite hasta dos decimales.';
    if (double.parse(text) > 9999999.99) return 'El importe no puede pasar de 9,999,999.99.';
    return null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(OrderLineInput(description: _description.text.trim(), amount: _amount.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final isService = widget.kind == OrderLineKind.services;
    final noun = isService ? 'servicio' : 'mano de obra';
    return AlertDialog(
      title: Text(widget.existing == null ? 'Agregar $noun' : 'Editar $noun'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('linea-descripcion'),
                controller: _description,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Descripción *'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'La descripción es obligatoria.';
                  if (text.length > 255) return 'La descripción no puede pasar de 255 caracteres.';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const ValueKey('linea-importe'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Importe *', prefixText: '\$ '),
                validator: _validateAmount,
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
