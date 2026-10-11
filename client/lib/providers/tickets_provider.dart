import '../models/paged_result.dart';
import '../models/ticket.dart';
import '../services/tickets_service.dart';
import 'paged_list_provider.dart';

export 'paged_list_provider.dart' show LoadStatus;

/// Estado del listado de tickets: búsqueda por folio de ticket o de orden, cliente o placa, paginación y carga.
class TicketsProvider extends PagedListProvider<Ticket> {
  TicketsProvider(this._service);

  final TicketsService _service;

  @override
  Future<PagedResult<Ticket>> fetch({required String search, required int page}) => _service.list(search: search, page: page);
}
