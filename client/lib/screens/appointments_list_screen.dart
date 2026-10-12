import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../providers/appointments_provider.dart';
import '../services/api_client.dart';
import '../services/appointments_service.dart';
import '../utils/formatters.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';
import '../widgets/app_data_table.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import '../widgets/status_chip.dart';
import 'appointment_detail_screen.dart';
import 'appointment_form_screen.dart';

/// Pide la confirmación para cancelar una cita, con un motivo opcional. Devuelve null si se cancela el
/// diálogo; de lo contrario, el motivo (cadena vacía si no se capturó).
Future<String?> askCancelAppointment(BuildContext context) async {
  // No se libera el controlador a mano: el diálogo sigue animando su cierre cuando esta función termina.
  final controller = TextEditingController();
  final confirmed = await showConfirmDialog(
    context,
    title: 'Cancelar cita',
    message: '¿Seguro que quieres cancelar esta cita? La cita se conserva en el historial, pero ya no podrá modificarse.',
    confirmLabel: 'Confirmar',
    cancelLabel: 'Volver',
    extra: TextField(
      key: const ValueKey('motivo-cancelacion'),
      controller: controller,
      maxLength: 255,
      decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
    ),
  );
  return confirmed ? controller.text.trim() : null;
}

/// Listado de citas con búsqueda por cliente o placa y filtros de estado y fechas.
class AppointmentsListScreen extends StatefulWidget {
  const AppointmentsListScreen({super.key});

  @override
  State<AppointmentsListScreen> createState() => _AppointmentsListScreenState();
}

class _AppointmentsListScreenState extends State<AppointmentsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppointmentsProvider>().load(search: '', page: 1);
    });
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Appointment>(
      MaterialPageRoute(builder: (_) => const AppointmentFormScreen()),
    );
    if (created != null && mounted) {
      await context.read<AppointmentsProvider>().reload();
      if (mounted) showSuccess(context, 'Cita registrada correctamente.');
    }
  }

  void _open(Appointment appointment) {
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => AppointmentDetailScreen(appointmentId: appointment.id)))
        .then((_) {
      if (mounted) context.read<AppointmentsProvider>().reload();
    });
  }

  Future<void> _confirm(Appointment appointment) async {
    try {
      await context.read<AppointmentsService>().confirm(appointment.id);
      if (!mounted) return;
      await context.read<AppointmentsProvider>().reload();
      if (mounted) showSuccess(context, 'Cita confirmada.');
    } on ApiException catch (e) {
      if (mounted) showFailure(context, e.message);
    }
  }

  Future<void> _cancel(Appointment appointment) async {
    final reason = await askCancelAppointment(context);
    if (reason == null || !mounted) return;
    try {
      await context.read<AppointmentsService>().cancel(appointment.id, reason: reason.isEmpty ? null : reason);
      if (!mounted) return;
      await context.read<AppointmentsProvider>().reload();
      if (mounted) showSuccess(context, 'Cita cancelada.');
    } on ApiException catch (e) {
      if (mounted) showFailure(context, e.message);
    }
  }

  Future<void> _pickRange() async {
    final provider = context.read<AppointmentsProvider>();
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
      initialDateRange: provider.from != null && provider.to != null
          ? DateTimeRange(start: provider.from!, end: provider.to!)
          : null,
      helpText: 'Filtrar por fechas',
      saveText: 'Aplicar',
    );
    if (range == null || !mounted) return;
    await provider.setFilters(
      status: provider.statusFilter,
      from: DateTime(range.start.year, range.start.month, range.start.day),
      to: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentsProvider>();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Citas',
            subtitle: 'Llegada programada de los vehículos al taller',
            actions: [
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva cita'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360, minWidth: 280),
                child: DebouncedSearchField(
                  hint: 'Buscar por cliente o placa',
                  initialValue: provider.search,
                  onChanged: (value) => context.read<AppointmentsProvider>().load(search: value),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<AppointmentStatus?>(
                  key: const ValueKey('filtro-estado-cita'),
                  initialValue: provider.statusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: [
                    const DropdownMenuItem<AppointmentStatus?>(value: null, child: Text('Todos')),
                    for (final status in AppointmentStatus.values)
                      DropdownMenuItem<AppointmentStatus?>(value: status, child: Text(status.label)),
                  ],
                  onChanged: (status) => provider.setFilters(status: status, from: provider.from, to: provider.to),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('filtro-fechas-cita'),
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  provider.from == null || provider.to == null
                      ? 'Fechas'
                      : '${formatDate(provider.from!)} – ${formatDate(provider.to!)}',
                ),
              ),
              if (provider.from != null || provider.statusFilter != null)
                TextButton(
                  onPressed: () => provider.setFilters(),
                  child: const Text('Limpiar filtros'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: _Body(provider: provider, onCreate: _create, onOpen: _open, onConfirm: _confirm, onCancel: _cancel),
          ),
          if (provider.result != null && provider.result!.total > 0)
            PaginationBar(
              result: provider.result!,
              onPage: (page) => context.read<AppointmentsProvider>().load(page: page),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.provider,
    required this.onCreate,
    required this.onOpen,
    required this.onConfirm,
    required this.onCancel,
  });

  final AppointmentsProvider provider;
  final VoidCallback onCreate;
  final ValueChanged<Appointment> onOpen;
  final ValueChanged<Appointment> onConfirm;
  final ValueChanged<Appointment> onCancel;

  @override
  Widget build(BuildContext context) {
    final result = provider.result;

    if (result == null) {
      if (provider.status == LoadStatus.error) {
        return ErrorView(message: provider.error ?? 'No se pudo cargar.', onRetry: provider.reload);
      }
      return const LoadingView();
    }
    if (provider.status == LoadStatus.error) {
      return ErrorView(message: provider.error ?? 'No se pudo cargar.', onRetry: provider.reload);
    }
    if (result.items.isEmpty) {
      if (provider.status == LoadStatus.loading) return const LoadingView();
      return provider.hasSearch
          ? const EmptyView(message: 'No se encontraron citas con esos filtros.')
          : EmptyView(
              message: 'Todavía no hay citas registradas.',
              actionLabel: 'Registrar la primera cita',
              onAction: onCreate,
            );
    }

    return AnimatedOpacity(
      duration: AppDurations.state,
      opacity: provider.status == LoadStatus.loading ? 0.6 : 1,
      child: AppDataTable(
        minWidth: 1000,
        columns: const [
          DataColumn2(label: Text('Fecha y hora'), size: ColumnSize.M),
          DataColumn2(label: Text('Cliente'), size: ColumnSize.L),
          DataColumn2(label: Text('Vehículo'), size: ColumnSize.M),
          DataColumn2(label: Text('Motivo'), size: ColumnSize.L),
          DataColumn2(label: Text('Estado'), fixedWidth: 130),
          DataColumn2(label: Text('Acciones'), fixedWidth: 150),
        ],
        rows: [
          for (final appointment in result.items)
            DataRow2(
              key: ValueKey('cita-${appointment.id}'),
              onTap: () => onOpen(appointment),
              cells: [
                DataCell(Text(formatDateTime(appointment.scheduledAt))),
                DataCell(Text(appointment.client.name, overflow: TextOverflow.ellipsis)),
                DataCell(Text(appointment.vehicle.licensePlate)),
                DataCell(Text(appointment.reason, overflow: TextOverflow.ellipsis)),
                DataCell(StatusChip.appointment(appointment.status)),
                DataCell(
                  Row(
                    children: [
                      RowActionButton.view(tooltip: 'Ver detalle de la cita', onPressed: () => onOpen(appointment)),
                      if (appointment.status == AppointmentStatus.pending)
                        RowActionButton(
                          key: ValueKey('confirmar-cita-${appointment.id}'),
                          icon: Icons.check_circle_outline,
                          tooltip: 'Confirmar cita',
                          color: AppColors.success,
                          onPressed: () => onConfirm(appointment),
                        ),
                      if (appointment.status.isEditable)
                        RowActionButton(
                          key: ValueKey('cancelar-cita-${appointment.id}'),
                          icon: Icons.cancel_outlined,
                          tooltip: 'Cancelar cita',
                          color: AppColors.danger,
                          onPressed: () => onCancel(appointment),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
