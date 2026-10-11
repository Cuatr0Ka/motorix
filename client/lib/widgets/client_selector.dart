import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/client.dart';
import '../services/api_client.dart';
import '../services/clients_service.dart';
import '../utils/tokens.dart';
import 'app_data_table.dart';
import 'state_views.dart';

/// Campo de formulario para elegir al propietario (obligatorio) buscando entre los clientes.
class ClientSelectorField extends FormField<Client> {
  ClientSelectorField({
    super.key,
    super.initialValue,
    required ValueChanged<Client?> onChanged,
    super.enabled,
    String? serverError,
    String label = 'Propietario *',
    String emptyMessage = 'Selecciona un propietario.',
  }) : super(
          validator: (client) => serverError ?? (client == null ? emptyMessage : null),
          builder: (state) {
            final client = state.value;
            return Builder(
              builder: (context) => InkWell(
                borderRadius: BorderRadius.circular(AppRadius.control),
                onTap: !state.widget.enabled
                    ? null
                    : () async {
                        final chosen = await showClientPicker(context);
                        if (chosen != null) {
                          state.didChange(chosen);
                          onChanged(chosen);
                        }
                      },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: label,
                    errorText: state.errorText,
                    suffixIcon: const Icon(Icons.search, size: 20),
                  ),
                  isEmpty: client == null,
                  child: client == null
                      ? const SizedBox.shrink()
                      : Text('${client.name} · ${client.phone}', overflow: TextOverflow.ellipsis),
                ),
              ),
            );
          },
        );
}

/// Diálogo de búsqueda de clientes. Devuelve el cliente elegido o null.
Future<Client?> showClientPicker(BuildContext context) {
  return showDialog<Client>(
    context: context,
    builder: (_) => Provider<ClientsService>.value(
      value: context.read<ClientsService>(),
      child: const _ClientPickerDialog(),
    ),
  );
}

class _ClientPickerDialog extends StatefulWidget {
  const _ClientPickerDialog();

  @override
  State<_ClientPickerDialog> createState() => _ClientPickerDialogState();
}

class _ClientPickerDialogState extends State<_ClientPickerDialog> {
  List<Client>? _items;
  String? _error;
  String _search = '';
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = ++_request;
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final result = await context.read<ClientsService>().list(search: _search, pageSize: 20);
      if (!mounted || id != _request) return;
      setState(() => _items = result.items);
    } on ApiException catch (e) {
      if (mounted && id == _request) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elegir propietario'),
      content: SizedBox(
        width: 480,
        height: 360,
        child: Column(
          children: [
            DebouncedSearchField(
              hint: 'Buscar por nombre o teléfono',
              onChanged: (value) {
                _search = value;
                _load();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : _items == null
                      ? const LoadingView()
                      : _items!.isEmpty
                          ? const EmptyView(message: 'No se encontraron clientes.')
                          : ListView.separated(
                              itemCount: _items!.length,
                              separatorBuilder: (context, index) => const Divider(),
                              itemBuilder: (context, index) {
                                final client = _items![index];
                                return ListTile(
                                  key: ValueKey('propietario-${client.id}'),
                                  dense: true,
                                  title: Text(client.name),
                                  subtitle: Text(client.phone),
                                  onTap: () => Navigator.of(context).pop(client),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      ],
    );
  }
}
