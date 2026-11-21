import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/client_notice.dart';
import '../providers/client_notices_provider.dart';
import '../providers/notifications_provider.dart';
import '../utils/formatters.dart';
import '../utils/tokens.dart';
import '../widgets/app_data_table.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import '../widgets/status_chip.dart';

/// Clientes por avisar (administración y recepción): vehículo listo, cita de mañana y mantenimiento próximo o
/// vencido, con el teléfono para llamar. El sistema solo registra que se avisó; no envía mensajes.
class ClientNoticesScreen extends StatefulWidget {
  const ClientNoticesScreen({super.key});

  @override
  State<ClientNoticesScreen> createState() => _ClientNoticesScreenState();
}

class _ClientNoticesScreenState extends State<ClientNoticesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ClientNoticesProvider>().load();
    });
  }

  Future<void> _markNotified(PendingClientNotice notice) async {
    final provider = context.read<ClientNoticesProvider>();
    final notifications = context.read<NotificationsProvider>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Marcar como avisado',
      message: '¿Ya avisaste a ${notice.client.name} por ${notice.reason.label.toLowerCase()}?',
      confirmLabel: 'Sí, avisado',
    );
    if (!confirmed || !mounted) return;

    final outcome = await provider.markNotified(notice);
    if (!mounted) return;
    switch (outcome) {
      case NotifiedOutcome.done:
        showSuccess(context, 'Cliente marcado como avisado');
        notifications.refresh();
      case NotifiedOutcome.notApplicable:
        showFailure(context, 'Este aviso ya no aplica');
        notifications.refresh();
      case NotifiedOutcome.failed:
        showFailure(context, provider.lastFailure ?? 'No se pudo registrar el aviso.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientNoticesProvider>();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Clientes por avisar',
            subtitle: 'Llama o avisa en persona y marca al cliente como avisado. El sistema no envía mensajes.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _Body(provider: provider, onMarkNotified: _markNotified)),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider, required this.onMarkNotified});

  final ClientNoticesProvider provider;
  final ValueChanged<PendingClientNotice> onMarkNotified;

  @override
  Widget build(BuildContext context) {
    if (!provider.loaded) {
      if (provider.error != null) {
        return ErrorView(message: provider.error!, onRetry: provider.load);
      }
      return const LoadingView();
    }
    if (provider.error != null) {
      return ErrorView(message: provider.error!, onRetry: provider.load);
    }
    if (provider.items.isEmpty) {
      return const EmptyView(message: 'No hay clientes por avisar');
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (provider.total > provider.items.length)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text('Mostrando ${provider.items.length} de ${provider.total}', style: theme.textTheme.bodySmall),
          ),
        Expanded(
          child: AnimatedOpacity(
            duration: AppDurations.state,
            opacity: provider.loading ? 0.6 : 1,
            child: AppDataTable(
              minWidth: 980,
              columns: const [
                DataColumn2(label: Text('Cliente'), size: ColumnSize.M),
                DataColumn2(label: Text('Teléfono'), fixedWidth: 140),
                DataColumn2(label: Text('Vehículo'), size: ColumnSize.M),
                DataColumn2(label: Text('Motivo'), fixedWidth: 190),
                DataColumn2(label: Text('Fecha'), fixedWidth: 110),
                DataColumn2(label: Text('Acción'), fixedWidth: 130),
              ],
              rows: [
                for (final notice in provider.items)
                  DataRow2(
                    key: ValueKey('aviso-cliente-${notice.rowKey}'),
                    cells: [
                      DataCell(Text(notice.client.name, overflow: TextOverflow.ellipsis)),
                      DataCell(
                        notice.client.hasPhone
                            ? Text(notice.client.phone)
                            : Text(
                                'Sin teléfono registrado',
                                key: ValueKey('sin-telefono-${notice.rowKey}'),
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      DataCell(Text(notice.vehicle.label, overflow: TextOverflow.ellipsis)),
                      DataCell(StatusChip(label: notice.reason.label, tone: notice.reason.tone)),
                      DataCell(Text(notice.factDate == null ? '—' : formatDate(notice.factDate!))),
                      DataCell(
                        FilledButton.tonal(
                          key: ValueKey('avisado-${notice.rowKey}'),
                          onPressed: () => onMarkNotified(notice),
                          child: const Text('Avisado'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
