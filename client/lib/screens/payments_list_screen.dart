import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/payment.dart';
import '../providers/payments_provider.dart';
import '../utils/formatters.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';
import '../widgets/app_data_table.dart';
import '../widgets/page_header.dart';
import '../widgets/payment_chip.dart';
import '../widgets/state_views.dart';
import 'order_detail_screen.dart';

/// Listado de pagos (administración y recepción): búsqueda por folio de orden, cliente o placa, filtros de estado y
/// método. Desde aquí se abre la orden y se actualiza el estado de los cobros pendientes de Mercado Pago.
class PaymentsListScreen extends StatefulWidget {
  const PaymentsListScreen({super.key});

  @override
  State<PaymentsListScreen> createState() => _PaymentsListScreenState();
}

class _PaymentsListScreenState extends State<PaymentsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<PaymentsProvider>();
      provider.setFilters();
      provider.load(search: '', page: 1);
    });
  }

  void _openOrder(Payment payment) {
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: payment.orderId)))
        .then((_) {
      if (mounted) context.read<PaymentsProvider>().reload();
    });
  }

  Future<void> _refresh(Payment payment) async {
    final failure = await context.read<PaymentsProvider>().refreshPayment(payment.id);
    if (!mounted) return;
    if (failure == null) {
      showSuccess(context, 'Estado del cobro actualizado.');
    } else {
      showFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaymentsProvider>();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'Pagos', subtitle: 'Cobros de las órdenes de servicio'),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380, minWidth: 280),
                child: DebouncedSearchField(
                  hint: 'Buscar por folio, cliente o placa',
                  initialValue: provider.search,
                  onChanged: (value) => context.read<PaymentsProvider>().load(search: value),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<PaymentStatus?>(
                  key: const ValueKey('filtro-estado-pago'),
                  initialValue: provider.statusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: [
                    const DropdownMenuItem<PaymentStatus?>(value: null, child: Text('Todos')),
                    for (final status in PaymentStatus.values) DropdownMenuItem<PaymentStatus?>(value: status, child: Text(status.label)),
                  ],
                  onChanged: (status) => provider.setFilters(status: status, method: provider.methodFilter),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<PaymentMethod?>(
                  key: const ValueKey('filtro-metodo-pago'),
                  initialValue: provider.methodFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Método'),
                  items: [
                    const DropdownMenuItem<PaymentMethod?>(value: null, child: Text('Todos')),
                    for (final method in PaymentMethod.values) DropdownMenuItem<PaymentMethod?>(value: method, child: Text(method.label)),
                  ],
                  onChanged: (method) => provider.setFilters(status: provider.statusFilter, method: method),
                ),
              ),
              if (provider.statusFilter != null || provider.methodFilter != null)
                TextButton(onPressed: () => provider.setFilters(), child: const Text('Limpiar filtros')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _Body(provider: provider, onOpen: _openOrder, onRefresh: _refresh)),
          if (provider.result != null && provider.result!.total > 0)
            PaginationBar(
              result: provider.result!,
              onPage: (page) => context.read<PaymentsProvider>().load(page: page),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider, required this.onOpen, required this.onRefresh});

  final PaymentsProvider provider;
  final ValueChanged<Payment> onOpen;
  final ValueChanged<Payment> onRefresh;

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
      return EmptyView(message: provider.hasSearch ? 'No se encontraron pagos con esos filtros.' : 'Todavía no hay pagos registrados.');
    }

    return AnimatedOpacity(
      duration: AppDurations.state,
      opacity: provider.status == LoadStatus.loading ? 0.6 : 1,
      child: AppDataTable(
        minWidth: 1000,
        columns: const [
          DataColumn2(label: Text('Fecha'), fixedWidth: 150),
          DataColumn2(label: Text('Orden'), fixedWidth: 110),
          DataColumn2(label: Text('Cliente'), size: ColumnSize.L),
          DataColumn2(label: Text('Placa'), fixedWidth: 120),
          DataColumn2(label: Text('Método'), fixedWidth: 130),
          DataColumn2(label: Text('Importe'), fixedWidth: 110, numeric: true),
          DataColumn2(label: Text('Estado'), fixedWidth: 120),
          DataColumn2(label: Text('Acciones'), fixedWidth: 90),
        ],
        rows: [
          for (final payment in result.items)
            DataRow2(
              key: ValueKey('pago-${payment.id}'),
              onTap: () => onOpen(payment),
              cells: [
                DataCell(Text(formatDateTime(payment.paidAt ?? payment.createdAt))),
                DataCell(Text(payment.orderFolio)),
                DataCell(Text(payment.clientName ?? '—', overflow: TextOverflow.ellipsis)),
                DataCell(Text(payment.vehiclePlate ?? '—')),
                DataCell(Text(payment.method.label)),
                DataCell(Text(formatMoney(payment.amount))),
                DataCell(PaymentChip(status: payment.status)),
                DataCell(
                  payment.isPendingMercadoPago
                      ? RowActionButton(
                          key: ValueKey('actualizar-pago-${payment.id}'),
                          icon: Icons.sync,
                          tooltip: 'Actualizar estado',
                          onPressed: () => onRefresh(payment),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
