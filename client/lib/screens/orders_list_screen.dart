import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/service_order.dart';
import '../providers/orders_provider.dart';
import '../utils/formatters.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';
import '../widgets/app_data_table.dart';
import '../widgets/mechanic_selector.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import '../widgets/status_chip.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';

/// Listado de órdenes de servicio. Con [mine] es la vista «Mis órdenes» del mecánico: el servidor
/// devuelve solo las asignadas a quien consulta y, por defecto, sin las entregadas.
class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key, this.mine = false});

  final bool mine;

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<OrdersProvider>();
      provider.setFilters();
      provider.load(search: '', page: 1);
    });
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<ServiceOrder>(
      MaterialPageRoute(builder: (_) => const OrderFormScreen()),
    );
    if (created != null && mounted) {
      await context.read<OrdersProvider>().reload();
      if (mounted) showSuccess(context, 'Orden ${created.folio} creada correctamente.');
    }
  }

  void _open(ServiceOrder order) {
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)))
        .then((_) {
      if (mounted) context.read<OrdersProvider>().reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdersProvider>();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: widget.mine ? 'Mis órdenes' : 'Órdenes de servicio',
            subtitle: widget.mine
                ? 'Órdenes que tienes asignadas'
                : 'Trabajos del taller, desde la recepción hasta la entrega',
            actions: [
              if (!widget.mine)
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva orden'),
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
                constraints: const BoxConstraints(maxWidth: 380, minWidth: 280),
                child: DebouncedSearchField(
                  hint: widget.mine ? 'Buscar por folio, cliente o placa' : 'Buscar por folio, cliente o placa',
                  initialValue: provider.search,
                  onChanged: (value) => context.read<OrdersProvider>().load(search: value),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<OrderStatus?>(
                  key: const ValueKey('filtro-estado-orden'),
                  initialValue: provider.statusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: [
                    DropdownMenuItem<OrderStatus?>(value: null, child: Text(widget.mine ? 'En curso' : 'Todos')),
                    for (final status in OrderStatus.values)
                      DropdownMenuItem<OrderStatus?>(value: status, child: Text(status.label)),
                  ],
                  onChanged: (status) => provider.setFilters(status: status, mechanicId: provider.mechanicFilter),
                ),
              ),
              if (!widget.mine)
                SizedBox(
                  width: 220,
                  child: MechanicDropdown(
                    key: const ValueKey('filtro-mecanico-orden'),
                    label: 'Mecánico',
                    noneLabel: 'Todos',
                    value: provider.mechanicFilter,
                    onChanged: (id) => provider.setFilters(status: provider.statusFilter, mechanicId: id),
                  ),
                ),
              if (provider.statusFilter != null || provider.mechanicFilter != null)
                TextButton(onPressed: () => provider.setFilters(), child: const Text('Limpiar filtros')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _Body(provider: provider, mine: widget.mine, onCreate: _create, onOpen: _open)),
          if (provider.result != null && provider.result!.total > 0)
            PaginationBar(
              result: provider.result!,
              onPage: (page) => context.read<OrdersProvider>().load(page: page),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider, required this.mine, required this.onCreate, required this.onOpen});

  final OrdersProvider provider;
  final bool mine;
  final VoidCallback onCreate;
  final ValueChanged<ServiceOrder> onOpen;

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
      if (provider.hasSearch) return const EmptyView(message: 'No se encontraron órdenes con esos filtros.');
      return mine
          ? const EmptyView(message: 'No tienes órdenes asignadas.')
          : EmptyView(
              message: 'Todavía no hay órdenes de servicio.',
              actionLabel: 'Crear la primera orden',
              onAction: onCreate,
            );
    }

    return AnimatedOpacity(
      duration: AppDurations.state,
      opacity: provider.status == LoadStatus.loading ? 0.6 : 1,
      child: AppDataTable(
        minWidth: 960,
        columns: const [
          DataColumn2(label: Text('Folio'), fixedWidth: 110),
          DataColumn2(label: Text('Fecha'), fixedWidth: 110),
          DataColumn2(label: Text('Cliente'), size: ColumnSize.L),
          DataColumn2(label: Text('Vehículo'), size: ColumnSize.M),
          DataColumn2(label: Text('Mecánico'), size: ColumnSize.M),
          DataColumn2(label: Text('Estado'), fixedWidth: 210),
          DataColumn2(label: Text('Acciones'), fixedWidth: 110),
        ],
        rows: [
          for (final order in result.items)
            DataRow2(
              key: ValueKey('orden-${order.id}'),
              onTap: () => onOpen(order),
              cells: [
                DataCell(Text(order.folio)),
                DataCell(Text(formatDate(order.createdAt))),
                DataCell(Text(order.client.name, overflow: TextOverflow.ellipsis)),
                DataCell(Text(order.vehicle.licensePlate)),
                DataCell(Text(order.mechanic?.name ?? 'Sin asignar', overflow: TextOverflow.ellipsis)),
                DataCell(StatusChip.order(order.status)),
                DataCell(RowActionButton.view(tooltip: 'Ver detalle de la orden', onPressed: () => onOpen(order))),
              ],
            ),
        ],
      ),
    );
  }
}
