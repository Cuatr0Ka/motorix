import '../models/mechanic.dart';
import '../models/order_work.dart';
import '../models/paged_result.dart';
import '../models/service_order.dart';
import '../utils/status_labels.dart';
import 'api_client.dart';

class OrdersService {
  const OrdersService(this._api);

  final ApiClient _api;

  Future<PagedResult<ServiceOrder>> list({
    String? search,
    OrderStatus? status,
    int? mechanicId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _api.get('/orders', query: {
      'search': search,
      'status': status?.apiValue,
      'mechanicId': mechanicId,
      'page': page,
      'pageSize': pageSize,
    });
    return PagedResult(
      items: response.list.map(ServiceOrder.fromJson).toList(),
      total: response.total,
      page: (response.meta?['page'] as num?)?.toInt() ?? page,
      pageSize: (response.meta?['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }

  Future<ServiceOrder> get(int id) async => ServiceOrder.fromJson((await _api.get('/orders/$id')).map);

  Future<ServiceOrder> create(OrderInput input) async =>
      ServiceOrder.fromJson((await _api.post('/orders', body: input.toJson())).map);

  /// Mecánicos activos que se pueden asignar (recepción y administración).
  Future<List<Mechanic>> listMechanics() async => (await _api.get('/mechanics')).list.map(Mechanic.fromJson).toList();

  /// Asigna o reasigna el mecánico de la orden; `null` quita la asignación (solo en órdenes Recibidas).
  Future<ServiceOrder> assignMechanic(int orderId, int? mechanicId) async => ServiceOrder.fromJson(
        (await _api.put('/orders/$orderId/mechanic', body: {'mechanicId': mechanicId})).map,
      );

  /// Registra o edita el diagnóstico, las observaciones y las recomendaciones. Solo viajan las claves de
  /// [fields] (`diagnosis`, `observations`, `recommendations`); un texto vacío o null borra el campo.
  Future<ServiceOrder> updateWork(int orderId, Map<String, String?> fields) async =>
      ServiceOrder.fromJson((await _api.patch('/orders/$orderId/work', body: fields)).map);

  /// Cambia el estado de la orden. El servidor valida la secuencia, el rol y la pertenencia; si otra persona
  /// la cambió antes responde `STATE_CONFLICT`.
  Future<ServiceOrder> changeStatus(int orderId, OrderStatus status) async => ServiceOrder.fromJson(
        (await _api.post('/orders/$orderId/status', body: {'status': status.apiValue})).map,
      );

  Future<OrderLineResult> addLine(int orderId, OrderLineKind kind, OrderLineInput input) async {
    final response = await _api.post('/orders/$orderId/${kind.path}', body: input.toJson());
    return _lineResult(response.map);
  }

  Future<OrderLineResult> updateLine(int orderId, OrderLineKind kind, int lineId, OrderLineInput input) async {
    final response = await _api.patch('/orders/$orderId/${kind.path}/$lineId', body: input.toJson());
    return _lineResult(response.map);
  }

  /// Quita una línea y devuelve los totales recalculados.
  Future<OrderTotals> removeLine(int orderId, OrderLineKind kind, int lineId) async {
    final response = await _api.delete('/orders/$orderId/${kind.path}/$lineId');
    return OrderTotals.fromJson(Map<String, dynamic>.from(response.map['totals'] as Map));
  }

  OrderLineResult _lineResult(Map<String, dynamic> data) => OrderLineResult(
        line: OrderLine.fromJson(Map<String, dynamic>.from(data['item'] as Map)),
        totals: OrderTotals.fromJson(Map<String, dynamic>.from(data['totals'] as Map)),
      );
}
