import 'data.dart';
import 'fake_api.dart';

/// Orden simulada con cobro: registrar, actualizar y cancelar pagos cambia las lecturas.
class FakeBilledOrder {
  FakeBilledOrder({this.status = 'TERMINADO', this.mercadoPagoAvailable = true, this.total = '1250.00'});

  String status;
  bool mercadoPagoAvailable;
  String total;
  final List<Map<String, dynamic>> payments = [];
  Map<String, dynamic>? ticket;

  /// Resultado que reporta el proveedor al actualizar un cobro pendiente: `approved`, `rejected` o `pending`.
  String providerState = 'pending';
  String? lastCheckedAt;
  int _nextPayment = 1;

  Map<String, dynamic>? get active => payments.cast<Map<String, dynamic>?>().firstWhere(
        (p) => p!['status'] == 'PENDIENTE' || p['status'] == 'PAGADO',
        orElse: () => null,
      );

  Map<String, dynamic> detail() => orderDetailJson(
        1,
        status: status,
        mechanic: {'id': 3, 'name': 'Mario Mecánico'},
        allowedTransitions: status == 'TERMINADO' ? const ['ENTREGADO'] : const [],
        billing: billingJson(
          total: total,
          payments: payments.reversed.toList(),
          canCharge: status == 'TERMINADO' || status == 'ENTREGADO',
          ticket: ticket,
        ),
      );

  FakeHandler handler({FakeHandler? extra}) => ordersHandler(
        items: [orderSummaryJson(1, status: status, mechanic: {'id': 3, 'name': 'Mario Mecánico'})],
        extra: (r) {
          final custom = extra?.call(r);
          if (custom != null) return custom;
          if (r.method == 'GET' && r.path == '/orders/1') return ok(detail());
          if (r.method == 'POST' && r.path == '/orders/1/status') {
            status = '${r.body['status']}';
            return ok(detail());
          }
          if (r.method == 'POST' && r.path == '/orders/1/ticket') {
            if (!payments.any((p) => p['status'] == 'PAGADO')) {
              return failure(409, 'TICKET_REQUIRES_PAYMENT', 'La orden debe estar cobrada (pago Pagado) para generar su ticket.');
            }
            final created = ticket == null;
            ticket ??= {'id': 1, 'folio': 'TK-000001'};
            return jsonResponse(created ? 201 : 200, {'data': {'ticket': ticketJson(1), 'created': created}});
          }
          if (r.method == 'GET' && r.path == '/tickets/1') return ok(ticketJson(1));
          if (r.method == 'GET' && r.path == '/tickets') {
            final list = ticket == null ? <Map<String, dynamic>>[] : [ticketJson(1, full: false)];
            return ok(list, meta: {'page': 1, 'pageSize': 20, 'total': list.length});
          }
          if (r.method == 'GET' && r.path == '/payments/methods') {
            return ok({
              'methods': [
                {'method': 'EFECTIVO', 'available': true},
                {'method': 'TARJETA', 'available': true},
                {'method': 'TRANSFERENCIA', 'available': true},
                if (mercadoPagoAvailable)
                  {'method': 'MERCADO_PAGO', 'available': true}
                else
                  {'method': 'MERCADO_PAGO', 'available': false, 'reason': 'Mercado Pago no está configurado en este entorno.'},
              ],
            });
          }
          if (r.method == 'GET' && r.path == '/payments') {
            return ok(payments.reversed.toList(), meta: {'page': 1, 'pageSize': 20, 'total': payments.length});
          }
          if (r.method == 'POST' && r.path == '/orders/1/payments') {
            if (active != null) {
              return failure(409, 'PAYMENT_ALREADY_EXISTS', 'La orden ya tiene un pago registrado.');
            }
            if (r.body['amount'] != null && r.body['amount'] != total) {
              return failure(422, 'AMOUNT_MISMATCH', 'El importe no coincide con el total vigente de la orden (\$$total).');
            }
            final method = '${r.body['method']}';
            final isMp = method == 'MERCADO_PAGO';
            final id = _nextPayment++;
            payments.add(paymentJson(
              id,
              method: method,
              status: isMp ? 'PENDIENTE' : 'PAGADO',
              amount: total,
              reference: r.body['reference'] as String?,
              checkoutUrl: isMp ? 'https://sandbox.mercadopago.simulado/pay/$id' : null,
            ));
            return created(payments.last);
          }
          final match = RegExp(r'^/payments/(\d+)/(refresh|cancel)$').firstMatch(r.path);
          if (r.method == 'POST' && match != null) {
            final index = payments.indexWhere((p) => p['id'] == int.parse(match.group(1)!));
            final payment = payments[index];
            if (match.group(2) == 'cancel') {
              if (payment['status'] != 'PENDIENTE') {
                return failure(409, 'PAYMENT_NOT_CANCELLABLE', 'Solo se puede cancelar un pago que esté Pendiente.');
              }
              payments[index] = {...payment, 'status': 'CANCELADO'};
              return ok(payments[index]);
            }
            if (payment['status'] == 'PENDIENTE') {
              lastCheckedAt = '2030-10-11T15:30:00.000Z';
              if (providerState == 'approved') {
                payments[index] = {
                  ...payment,
                  'status': 'PAGADO',
                  'paidAt': '2030-10-11T15:30:00.000Z',
                  'externalPaymentId': '987654',
                  'lastCheckedAt': lastCheckedAt,
                };
              } else if (providerState == 'rejected') {
                payments[index] = {...payment, 'status': 'RECHAZADO', 'lastCheckedAt': lastCheckedAt};
              } else {
                payments[index] = {...payment, 'lastCheckedAt': lastCheckedAt};
              }
            }
            return ok(payments[index]);
          }
          return null;
        },
      );
}
