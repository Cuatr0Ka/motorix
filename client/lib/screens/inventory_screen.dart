import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/part.dart';
import '../providers/parts_provider.dart';
import '../providers/stock_alerts_provider.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';
import '../widgets/app_data_table.dart';
import '../widgets/page_header.dart';
import '../widgets/stock_alerts_banner.dart';
import '../widgets/state_views.dart';
import '../widgets/stock_chip.dart';
import 'part_detail_screen.dart';
import 'part_form_screen.dart';

/// Inventario de refacciones (solo administración): búsqueda por código o nombre, filtros de estado de
/// stock y de activas, y acceso al alta y al detalle de cada refacción.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<PartsProvider>();
      provider.setFilters();
      provider.load(search: '', page: 1);
      context.read<StockAlertsProvider>().refresh();
    });
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Part>(MaterialPageRoute(builder: (_) => const PartFormScreen()));
    if (created != null && mounted) {
      await context.read<PartsProvider>().reload();
      if (!mounted) return;
      context.read<StockAlertsProvider>().refresh();
      showSuccess(context, 'Refacción registrada correctamente.');
    }
  }

  void _open(Part part) {
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => PartDetailScreen(partId: part.id)))
        .then((_) {
      if (!mounted) return;
      context.read<PartsProvider>().reload();
      context.read<StockAlertsProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PartsProvider>();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Inventario',
            subtitle: 'Refacciones del taller y su existencia',
            actions: [
              FilledButton.icon(
                key: const ValueKey('nueva-refaccion'),
                onPressed: _create,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva refacción'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          StockAlertsBanner(onOpenPart: _open),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380, minWidth: 280),
                child: DebouncedSearchField(
                  hint: 'Buscar por código o nombre',
                  initialValue: provider.search,
                  onChanged: (value) => context.read<PartsProvider>().load(search: value),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<StockStatus?>(
                  key: const ValueKey('filtro-estado-stock'),
                  initialValue: provider.stockFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Estado de stock'),
                  items: [
                    const DropdownMenuItem<StockStatus?>(value: null, child: Text('Todos')),
                    for (final status in StockStatus.values)
                      DropdownMenuItem<StockStatus?>(value: status, child: Text(status.label)),
                  ],
                  onChanged: (status) => provider.setFilters(stockStatus: status, active: provider.activeFilter),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<bool?>(
                  key: const ValueKey('filtro-activas'),
                  initialValue: provider.activeFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Refacciones'),
                  items: const [
                    DropdownMenuItem<bool?>(value: null, child: Text('Todas')),
                    DropdownMenuItem<bool?>(value: true, child: Text('Activas')),
                    DropdownMenuItem<bool?>(value: false, child: Text('Inactivas')),
                  ],
                  onChanged: (active) => provider.setFilters(stockStatus: provider.stockFilter, active: active),
                ),
              ),
              if (provider.stockFilter != null || provider.activeFilter != null)
                TextButton(onPressed: () => provider.setFilters(), child: const Text('Limpiar filtros')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _Body(provider: provider, onCreate: _create, onOpen: _open)),
          if (provider.result != null && provider.result!.total > 0)
            PaginationBar(
              result: provider.result!,
              onPage: (page) => context.read<PartsProvider>().load(page: page),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider, required this.onCreate, required this.onOpen});

  final PartsProvider provider;
  final VoidCallback onCreate;
  final ValueChanged<Part> onOpen;

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
          ? const EmptyView(message: 'No se encontraron refacciones con esos filtros.')
          : EmptyView(
              message: 'Todavía no hay refacciones registradas.',
              actionLabel: 'Registrar la primera refacción',
              onAction: onCreate,
            );
    }

    return AnimatedOpacity(
      duration: AppDurations.state,
      opacity: provider.status == LoadStatus.loading ? 0.6 : 1,
      child: AppDataTable(
        minWidth: 820,
        columns: const [
          DataColumn2(label: Text('Código'), size: ColumnSize.S),
          DataColumn2(label: Text('Nombre'), size: ColumnSize.L),
          DataColumn2(label: Text('Unidad'), fixedWidth: 100),
          DataColumn2(label: Text('Stock'), fixedWidth: 90, numeric: true),
          DataColumn2(label: Text('Mínimo'), fixedWidth: 90, numeric: true),
          DataColumn2(label: Text('Estado'), fixedWidth: 130),
        ],
        rows: [
          for (final part in result.items)
            DataRow2(
              key: ValueKey('refaccion-${part.id}'),
              onTap: () => onOpen(part),
              cells: [
                DataCell(Text(part.code)),
                DataCell(Text(part.name, overflow: TextOverflow.ellipsis)),
                DataCell(Text(part.unit)),
                DataCell(Text('${part.stock}')),
                DataCell(Text('${part.minStock}')),
                DataCell(StockChip(status: part.stockStatus, active: part.active)),
              ],
            ),
        ],
      ),
    );
  }
}
