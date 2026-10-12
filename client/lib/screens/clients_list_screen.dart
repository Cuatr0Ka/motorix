import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/client.dart';
import '../providers/clients_provider.dart';
import '../providers/session_provider.dart';
import '../utils/tokens.dart';
import '../widgets/app_data_table.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import 'client_detail_screen.dart';
import 'client_form_screen.dart';

/// Listado de clientes con búsqueda por nombre o teléfono y paginación.
class ClientsListScreen extends StatefulWidget {
  const ClientsListScreen({super.key});

  @override
  State<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends State<ClientsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ClientsProvider>().load(search: '', page: 1);
    });
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Client>(
      MaterialPageRoute(builder: (_) => const ClientFormScreen()),
    );
    if (created != null && mounted) {
      await context.read<ClientsProvider>().reload();
      if (mounted) showSuccess(context, 'Cliente registrado correctamente.');
    }
  }

  Future<void> _edit(Client client) async {
    final updated = await Navigator.of(context).push<Client>(
      MaterialPageRoute(builder: (_) => ClientFormScreen(existing: client)),
    );
    if (updated != null && mounted) {
      await context.read<ClientsProvider>().reload();
      if (mounted) showSuccess(context, 'Cliente actualizado correctamente.');
    }
  }

  void _open(Client client) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ClientDetailScreen(clientId: client.id)),
    ).then((_) {
      if (mounted) context.read<ClientsProvider>().reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientsProvider>();
    final canEdit = context.watch<SessionProvider>().user?.canEditRecords ?? false;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Clientes',
            subtitle: 'Propietarios de los vehículos atendidos',
            actions: [
              if (canEdit)
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nuevo cliente'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DebouncedSearchField(
              hint: 'Buscar por nombre o teléfono',
              initialValue: provider.search,
              onChanged: (value) => context.read<ClientsProvider>().load(search: value),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: _Body(provider: provider, canEdit: canEdit, onCreate: _create, onOpen: _open, onEdit: _edit),
          ),
          if (provider.result != null && provider.result!.total > 0)
            PaginationBar(
              result: provider.result!,
              onPage: (page) => context.read<ClientsProvider>().load(page: page),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.provider,
    required this.canEdit,
    required this.onCreate,
    required this.onOpen,
    required this.onEdit,
  });

  final ClientsProvider provider;
  final bool canEdit;
  final VoidCallback onCreate;
  final ValueChanged<Client> onOpen;
  final ValueChanged<Client> onEdit;

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
          ? const EmptyView(message: 'No se encontraron clientes con esa búsqueda.')
          : EmptyView(
              message: 'Todavía no hay clientes registrados.',
              actionLabel: canEdit ? 'Registrar el primer cliente' : null,
              onAction: canEdit ? onCreate : null,
            );
    }

    return AnimatedOpacity(
      duration: AppDurations.state,
      opacity: provider.status == LoadStatus.loading ? 0.6 : 1,
      child: AppDataTable(
        columns: const [
          DataColumn2(label: Text('Nombre'), size: ColumnSize.L),
          DataColumn2(label: Text('Teléfono'), size: ColumnSize.M),
          DataColumn2(label: Text('Correo'), size: ColumnSize.L),
          DataColumn2(label: Text('Vehículos'), size: ColumnSize.S, numeric: true),
          DataColumn2(label: Text('Acciones'), fixedWidth: 110),
        ],
        rows: [
          for (final client in result.items)
            DataRow2(
              key: ValueKey('cliente-${client.id}'),
              onTap: () => onOpen(client),
              cells: [
                DataCell(Text(client.name, overflow: TextOverflow.ellipsis)),
                DataCell(Text(client.phone)),
                DataCell(Text(client.email ?? '—', overflow: TextOverflow.ellipsis)),
                DataCell(Text('${client.vehicleCount}')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RowActionButton.view(
                        tooltip: 'Ver detalle de ${client.name}',
                        onPressed: () => onOpen(client),
                      ),
                      if (canEdit)
                        RowActionButton.edit(
                          tooltip: 'Editar a ${client.name}',
                          onPressed: () => onEdit(client),
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
