import '../models/paged_result.dart';
import '../models/vehicle.dart';
import '../services/vehicles_service.dart';
import 'paged_list_provider.dart';

export 'paged_list_provider.dart' show LoadStatus;

/// Estado del listado de vehículos: búsqueda, paginación y carga.
class VehiclesProvider extends PagedListProvider<Vehicle> {
  VehiclesProvider(this._service);

  final VehiclesService _service;

  @override
  Future<PagedResult<Vehicle>> fetch({required String search, required int page}) =>
      _service.list(search: search, page: page);
}
