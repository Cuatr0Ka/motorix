import '../models/paged_result.dart';
import '../models/payment.dart';
import '../services/api_client.dart';
import '../services/payments_service.dart';
import '../utils/status_labels.dart';
import 'paged_list_provider.dart';

export 'paged_list_provider.dart' show LoadStatus;

/// Estado del listado de pagos: búsqueda por folio, cliente o placa, filtros de estado y método, paginación y carga.
class PaymentsProvider extends PagedListProvider<Payment> {
  PaymentsProvider(this._service);

  final PaymentsService _service;

  PaymentStatus? _statusFilter;
  PaymentMethod? _methodFilter;

  PaymentStatus? get statusFilter => _statusFilter;
  PaymentMethod? get methodFilter => _methodFilter;

  @override
  bool get hasSearch => super.hasSearch || _statusFilter != null || _methodFilter != null;

  /// Aplica los filtros y vuelve a la primera página.
  Future<void> setFilters({PaymentStatus? status, PaymentMethod? method}) {
    _statusFilter = status;
    _methodFilter = method;
    return load(page: 1);
  }

  @override
  Future<PagedResult<Payment>> fetch({required String search, required int page}) =>
      _service.list(search: search, status: _statusFilter, method: _methodFilter, page: page);

  /// Consulta el estado de un cobro de Mercado Pago y recarga el listado. Devuelve el error en español, o null.
  Future<String?> refreshPayment(int id) async {
    try {
      await _service.refresh(id);
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
    await reload();
    return null;
  }
}
