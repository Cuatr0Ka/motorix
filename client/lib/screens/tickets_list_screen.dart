import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ticket.dart';
import '../providers/tickets_provider.dart';
import '../utils/formatters.dart';
import '../utils/tokens.dart';
import '../widgets/app_data_table.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import 'ticket_screen.dart';

/// Listado de tickets (administración y recepción): búsqueda por folio de ticket o de orden, cliente o placa.
class TicketsListScreen extends StatefulWidget {
  const TicketsListScreen({super.key});

  @override
  State<TicketsListScreen> createState() => _TicketsListScreenState();
}

class _TicketsListScreenState extends State<TicketsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TicketsProvider>().load(search: '', page: 1);
    });
  }

  void _open(Ticket ticket) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => TicketScreen(ticketId: ticket.id)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketsProvider>();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'Tickets', subtitle: 'Comprobantes de las órdenes cobradas'),
          const SizedBox(height: AppSpacing.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DebouncedSearchField(
              hint: 'Buscar por folio, cliente o placa',
              initialValue: provider.search,
              onChanged: (value) => context.read<TicketsProvider>().load(search: value),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _Body(provider: provider, onOpen: _open)),
          if (provider.result != null && provider.result!.total > 0)
            PaginationBar(
              result: provider.result!,
              onPage: (page) => context.read<TicketsProvider>().load(page: page),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider, required this.onOpen});

  final TicketsProvider provider;
  final ValueChanged<Ticket> onOpen;

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
      return EmptyView(
        message: provider.hasSearch ? 'No se encontraron tickets con esa búsqueda.' : 'Todavía no hay tickets generados.',
      );
    }

    return AnimatedOpacity(
      duration: AppDurations.state,
      opacity: provider.status == LoadStatus.loading ? 0.6 : 1,
      child: AppDataTable(
        minWidth: 860,
        columns: const [
          DataColumn2(label: Text('Ticket'), fixedWidth: 120),
          DataColumn2(label: Text('Fecha'), fixedWidth: 150),
          DataColumn2(label: Text('Orden'), fixedWidth: 120),
          DataColumn2(label: Text('Cliente'), size: ColumnSize.L),
          DataColumn2(label: Text('Placa'), fixedWidth: 120),
          DataColumn2(label: Text('Total'), fixedWidth: 120, numeric: true),
        ],
        rows: [
          for (final ticket in result.items)
            DataRow2(
              key: ValueKey('ticket-${ticket.id}'),
              onTap: () => onOpen(ticket),
              cells: [
                DataCell(Text(ticket.folio)),
                DataCell(Text(formatDateTime(ticket.generatedAt))),
                DataCell(Text(ticket.orderFolio)),
                DataCell(Text(ticket.clientName ?? '—', overflow: TextOverflow.ellipsis)),
                DataCell(Text(ticket.plate ?? '—')),
                DataCell(Text(ticket.total == null ? '—' : formatMoney(ticket.total!))),
              ],
            ),
        ],
      ),
    );
  }
}
