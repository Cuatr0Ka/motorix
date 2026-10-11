import '../models/client.dart';
import '../models/paged_result.dart';
import '../services/clients_service.dart';
import 'paged_list_provider.dart';

export 'paged_list_provider.dart' show LoadStatus;

/// Estado del listado de clientes: búsqueda, paginación y carga.
class ClientsProvider extends PagedListProvider<Client> {
  ClientsProvider(this._service);

  final ClientsService _service;

  @override
  Future<PagedResult<Client>> fetch({required String search, required int page}) =>
      _service.list(search: search, page: page);
}
