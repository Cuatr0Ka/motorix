import '../models/paged_result.dart';
import '../models/payment.dart';
import '../utils/status_labels.dart';
import 'api_client.dart';

/// Consumo de la API de pagos. Nunca envía datos de tarjeta: solo método, importe y una referencia opcional.
class PaymentsService {
  const PaymentsService(this._api);

  final ApiClient _api;

  /// Métodos de pago y su disponibilidad.
  Future<List<PaymentMethodOption>> methods() async {
    final data = (await _api.get('/payments/methods')).map;
    return (data['methods'] as List).map((e) => PaymentMethodOption.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<Payment>> listByOrder(int orderId) async =>
      (await _api.get('/orders/$orderId/payments')).list.map(Payment.fromJson).toList();

  /// Registra el pago de la orden por su total vigente. [amount] es el importe que vio la persona; el servidor
  /// rechaza el cobro si ya no coincide con el total.
  Future<Payment> create(int orderId, PaymentMethod method, {String? reference, String? amount}) async {
    final response = await _api.post('/orders/$orderId/payments', body: {
      'method': method.apiValue,
      'amount': ?amount,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
    });
    return Payment.fromJson(response.map);
  }

  Future<PagedResult<Payment>> list({
    String? search,
    PaymentStatus? status,
    PaymentMethod? method,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _api.get('/payments', query: {
      'search': search,
      'status': status?.apiValue,
      'method': method?.apiValue,
      'page': page,
      'pageSize': pageSize,
    });
    return PagedResult(
      items: response.list.map(Payment.fromJson).toList(),
      total: response.total,
      page: (response.meta?['page'] as num?)?.toInt() ?? page,
      pageSize: (response.meta?['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }

  Future<Payment> get(int id) async => Payment.fromJson((await _api.get('/payments/$id')).map);

  /// Consulta a Mercado Pago el estado de un cobro pendiente.
  Future<Payment> refresh(int id) async => Payment.fromJson((await _api.post('/payments/$id/refresh')).map);

  /// Cancela un cobro pendiente.
  Future<Payment> cancel(int id) async => Payment.fromJson((await _api.post('/payments/$id/cancel')).map);
}
