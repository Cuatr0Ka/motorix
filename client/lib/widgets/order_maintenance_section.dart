import 'package:flutter/material.dart';

import '../models/maintenance.dart';
import '../models/service_order.dart';
import '../utils/formatters.dart';
import '../utils/tokens.dart';
import 'confirm_dialog.dart';
import 'maintenance_chip.dart';
import 'maintenance_dialog.dart';
import 'panel_card.dart';

/// Acciones de la sección de mantenimiento de la orden. Cada callback devuelve cuando la acción termina.
class OrderMaintenanceActions {
  const OrderMaintenanceActions({
    required this.onSetServiceMileage,
    required this.onSchedule,
    required this.onUpdate,
    required this.onAttend,
  });

  final Future<void> Function(int mileage) onSetServiceMileage;
  final Future<void> Function(MaintenanceInput input) onSchedule;
  final Future<void> Function(Maintenance maintenance, MaintenanceInput input) onUpdate;
  final Future<void> Function(Maintenance maintenance) onAttend;
}

/// Tarjeta con el kilometraje del servicio y el próximo mantenimiento de una orden concluida.
/// [actions] llega solo si el rol puede registrarlos (mecánico asignado y administración); sin él, la
/// sección es de consulta.
class OrderMaintenanceSection extends StatelessWidget {
  const OrderMaintenanceSection({super.key, required this.order, this.actions, this.busy = false});

  final ServiceOrder order;
  final OrderMaintenanceActions? actions;
  final bool busy;

  Future<void> _registerMileage(BuildContext context) async {
    final value = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ServiceMileageDialog(entryMileage: order.entryMileage, current: order.serviceMileage),
    );
    if (value == null || !context.mounted) return;
    await actions!.onSetServiceMileage(value);
  }

  Future<void> _schedule(BuildContext context, {Maintenance? existing}) async {
    final input = await showDialog<MaintenanceInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MaintenanceDialog(existing: existing),
    );
    if (input == null || !context.mounted) return;
    if (existing == null) {
      await actions!.onSchedule(input);
    } else {
      await actions!.onUpdate(existing, input);
    }
  }

  Future<void> _attend(BuildContext context, Maintenance maintenance) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Marcar como atendido',
      message: '¿Confirmas que el mantenimiento "${maintenance.description}" ya fue atendido? '
          'Esta acción no se puede deshacer.',
    );
    if (!confirmed || !context.mounted) return;
    await actions!.onAttend(maintenance);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maintenance = order.maintenance;
    final canMileage = actions != null && order.status.apiValue == 'TERMINADO';
    final canSchedule = actions != null && order.isFinishedOrDelivered;

    String target(Maintenance m) => [
          if (m.dueDate != null) formatDate(m.dueDate!),
          if (m.dueMileage != null) formatMileage(m.dueMileage!),
        ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelCard(
          title: 'Kilometraje del servicio',
          trailing: canMileage
              ? TextButton.icon(
                  key: const ValueKey('registrar-kilometraje'),
                  onPressed: busy ? null : () => _registerMileage(context),
                  icon: const Icon(Icons.speed_outlined, size: 16),
                  label: Text(order.serviceMileage == null ? 'Registrar kilometraje' : 'Corregir kilometraje'),
                )
              : null,
          child: Text(
            order.serviceMileage == null ? 'Sin registrar.' : formatMileage(order.serviceMileage!),
            key: const ValueKey('kilometraje-servicio'),
            style: theme.textTheme.bodyMedium,
          ),
        ),
        PanelCard(
          title: 'Próximo mantenimiento',
          trailing: canSchedule
              ? TextButton.icon(
                  key: const ValueKey('programar-mantenimiento'),
                  onPressed: busy ? null : () => _schedule(context),
                  icon: const Icon(Icons.event_repeat_outlined, size: 16),
                  label: Text(maintenance == null || maintenance.isAttended ? 'Programar mantenimiento' : 'Reemplazar'),
                )
              : null,
          child: maintenance == null
              ? Text('Sin mantenimiento programado.', style: theme.textTheme.bodyMedium)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            maintenance.description,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        MaintenanceChip(indicator: maintenance.indicator, attended: maintenance.isAttended),
                      ],
                    ),
                    if (target(maintenance).isNotEmpty) Text(target(maintenance), style: theme.textTheme.bodySmall),
                    if (actions != null && !maintenance.isAttended)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            TextButton.icon(
                              key: const ValueKey('editar-mantenimiento'),
                              onPressed: busy ? null : () => _schedule(context, existing: maintenance),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Editar'),
                            ),
                            TextButton.icon(
                              key: const ValueKey('atender-mantenimiento'),
                              onPressed: busy ? null : () => _attend(context, maintenance),
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: const Text('Marcar como atendido'),
                            ),
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

/// Diálogo para capturar el kilometraje del servicio (entero entre el de entrada y 2 000 000).
class _ServiceMileageDialog extends StatefulWidget {
  const _ServiceMileageDialog({required this.entryMileage, this.current});

  final int entryMileage;
  final int? current;

  @override
  State<_ServiceMileageDialog> createState() => _ServiceMileageDialogState();
}

class _ServiceMileageDialogState extends State<_ServiceMileageDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: '${widget.current ?? widget.entryMileage}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'El kilometraje es obligatorio.';
    final number = int.tryParse(text);
    if (number == null || number < 0) return 'El kilometraje debe ser un número entero.';
    if (number > 2000000) return 'El kilometraje no puede pasar de 2,000,000.';
    if (number < widget.entryMileage) {
      return 'No puede ser menor al kilometraje de entrada (${formatMileage(widget.entryMileage)}).';
    }
    return null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(int.parse(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kilometraje del servicio'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: TextFormField(
            key: const ValueKey('km-servicio'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Kilometraje *',
              helperText: 'Kilometraje de entrada: ${formatMileage(widget.entryMileage)}',
              suffixText: 'km',
            ),
            validator: _validate,
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
