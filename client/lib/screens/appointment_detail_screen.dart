import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../models/service_order.dart';
import '../services/api_client.dart';
import '../services/appointments_service.dart';
import '../utils/formatters.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import '../widgets/status_chip.dart';
import 'appointment_form_screen.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';
import 'appointments_list_screen.dart' show askCancelAppointment;

/// Detalle de una cita: datos, cliente, vehículo y orden asociada, con las acciones permitidas.
class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final int appointmentId;

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  Appointment? _appointment;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appointment = await context.read<AppointmentsService>().get(widget.appointmentId);
      if (!mounted) return;
      setState(() => _appointment = appointment);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Appointment>(
      MaterialPageRoute(builder: (_) => AppointmentFormScreen(existing: _appointment)),
    );
    if (updated != null && mounted) {
      await _load();
      if (mounted) showSuccess(context, 'Cita actualizada correctamente.');
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      await _load();
      if (mounted) showSuccess(context, success);
    } on ApiException catch (e) {
      if (mounted) showFailure(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() => _run(() async {
        await context.read<AppointmentsService>().confirm(widget.appointmentId);
      }, 'Cita confirmada.');

  /// Recibe el vehículo: abre el formulario de orden con los datos de la cita.
  Future<void> _receiveVehicle() async {
    final created = await Navigator.of(context).push<ServiceOrder>(
      MaterialPageRoute(builder: (_) => OrderFormScreen(appointment: _appointment)),
    );
    if (created != null && mounted) {
      await _load();
      if (mounted) showSuccess(context, 'Orden ${created.folio} creada correctamente.');
    }
  }

  void _openOrder(AppointmentOrder order) {
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)))
        .then((_) {
      if (mounted) _load();
    });
  }

  Future<void> _cancel() async {
    final reason = await askCancelAppointment(context);
    if (reason == null || !mounted) return;
    await _run(() async {
      await context.read<AppointmentsService>().cancel(widget.appointmentId, reason: reason.isEmpty ? null : reason);
    }, 'Cita cancelada.');
  }

  @override
  Widget build(BuildContext context) {
    final appointment = _appointment;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: appointment == null ? 'Cita' : 'Cita del ${formatDate(appointment.scheduledAt)}',
            subtitle: 'Detalle de la cita',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (appointment != null && appointment.status.isEditable)
                FilledButton.icon(
                  key: const ValueKey('recibir-vehiculo'),
                  onPressed: _busy ? null : _receiveVehicle,
                  icon: const Icon(Icons.assignment_add, size: 18),
                  label: const Text('Recibir vehículo y crear orden'),
                ),
              if (appointment != null && appointment.order != null)
                OutlinedButton.icon(
                  key: const ValueKey('ver-orden'),
                  onPressed: () => _openOrder(appointment.order!),
                  icon: const Icon(Icons.assignment_outlined, size: 18),
                  label: const Text('Ver orden'),
                ),
              if (appointment != null && appointment.status.isEditable) ...[
                OutlinedButton.icon(
                  onPressed: _busy ? null : _edit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
                if (appointment.status == AppointmentStatus.pending)
                  OutlinedButton.icon(
                    key: const ValueKey('confirmar-cita'),
                    onPressed: _busy ? null : _confirm,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Confirmar'),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('cancelar-cita'),
                  onPressed: _busy ? null : _cancel,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancelar cita'),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: _loading && appointment == null
                ? const LoadingView()
                : _error != null && appointment == null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : appointment == null
                        ? const SizedBox.shrink()
                        : SingleChildScrollView(child: _Content(appointment: appointment)),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.appointment});

  final Appointment appointment;

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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                const SizedBox(width: 140, child: Text('Estado')),
                StatusChip.appointment(appointment.status),
              ],
            ),
          ),
          const Divider(),
          DetailRow(label: 'Fecha y hora', value: formatDateTime(appointment.scheduledAt)),
          const Divider(),
          DetailRow(label: 'Cliente', value: appointment.client.name),
          const Divider(),
          DetailRow(label: 'Teléfono', value: appointment.client.phone),
          const Divider(),
          DetailRow(label: 'Vehículo', value: appointment.vehicle.label),
          const Divider(),
          DetailRow(label: 'Motivo', value: appointment.reason),
          const Divider(),
          DetailRow(label: 'Observaciones', value: appointment.notes),
          if (appointment.status == AppointmentStatus.cancelled) ...[
            const Divider(),
            DetailRow(label: 'Motivo de cancelación', value: appointment.cancelReason),
          ],
          if (appointment.order != null) ...[
            const Divider(),
            DetailRow(label: 'Orden asociada', value: '${appointment.order!.folio} · ${appointment.order!.status.label}'),
          ],
        ],
      ),
    );
  }
}
