import '../utils/status_labels.dart';

/// Pago de una orden. Nunca contiene datos de tarjeta: solo importe, método, estado y referencias de la operación.
class Payment {
  const Payment({
    required this.id,
    required this.orderId,
    required this.orderFolio,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.reference,
    this.externalPaymentId,
    this.checkoutUrl,
    this.lastCheckedAt,
    this.paidAt,
    this.createdBy,
    this.clientName,
    this.vehiclePlate,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: (json['id'] as num).toInt(),
        orderId: (json['orderId'] as num).toInt(),
        orderFolio: '${json['orderFolio']}',
        amount: '${json['amount']}',
        method: PaymentMethod.fromApi(json['method'] as String?),
        status: PaymentStatus.fromApi(json['status'] as String?),
        createdAt: DateTime.parse('${json['createdAt']}'),
        reference: json['reference'] as String?,
        externalPaymentId: json['externalPaymentId'] as String?,
        checkoutUrl: json['checkoutUrl'] as String?,
        lastCheckedAt: json['lastCheckedAt'] == null ? null : DateTime.parse('${json['lastCheckedAt']}'),
        paidAt: json['paidAt'] == null ? null : DateTime.parse('${json['paidAt']}'),
        createdBy: json['createdBy'] == null ? null : '${(json['createdBy'] as Map)['name']}',
        clientName: json['client'] == null ? null : '${(json['client'] as Map)['name']}',
        vehiclePlate: json['vehicle'] == null ? null : '${(json['vehicle'] as Map)['licensePlate']}',
      );

  final int id;
  final int orderId;
  final String orderFolio;
  final String amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final DateTime createdAt;
  final String? reference;
  final String? externalPaymentId;
  final String? checkoutUrl;
  final DateTime? lastCheckedAt;
  final DateTime? paidAt;
  final String? createdBy;
  final String? clientName;
  final String? vehiclePlate;

  /// Cobro de Mercado Pago que aún espera la confirmación del proveedor.
  bool get isPendingMercadoPago => method == PaymentMethod.mercadoPago && status == PaymentStatus.pending;
}

/// Referencia al ticket de una orden.
class TicketRef {
  const TicketRef({required this.id, required this.folio});

  factory TicketRef.fromJson(Map<String, dynamic> json) => TicketRef(id: (json['id'] as num).toInt(), folio: '${json['folio']}');

  final int id;
  final String folio;
}

/// Bloque de cobro del detalle de una orden (solo lo reciben administración y recepción).
class Billing {
  const Billing({
    required this.total,
    required this.paidAmount,
    required this.collectionStatus,
    required this.amountOutdated,
    required this.canCharge,
    required this.payments,
    this.ticket,
  });

  factory Billing.fromJson(Map<String, dynamic> json) => Billing(
        total: '${json['total']}',
        paidAmount: '${json['paidAmount']}',
        collectionStatus: CollectionStatus.fromApi(json['collectionStatus'] as String?),
        amountOutdated: json['amountOutdated'] as bool? ?? false,
        canCharge: json['canCharge'] as bool? ?? false,
        payments: (json['payments'] as List? ?? const []).map((e) => Payment.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        ticket: json['ticket'] == null ? null : TicketRef.fromJson(Map<String, dynamic>.from(json['ticket'] as Map)),
      );

  final String total;
  final String paidAmount;
  final CollectionStatus collectionStatus;
  final bool amountOutdated;
  final bool canCharge;
  final List<Payment> payments;
  final TicketRef? ticket;

  bool get isPaid => collectionStatus == CollectionStatus.paid;
}

/// Método de pago y si está disponible (Mercado Pago necesita sus credenciales de pruebas).
class PaymentMethodOption {
  const PaymentMethodOption({required this.method, required this.available, this.reason});

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) => PaymentMethodOption(
        method: PaymentMethod.fromApi(json['method'] as String?),
        available: json['available'] as bool? ?? false,
        reason: json['reason'] as String?,
      );

  final PaymentMethod method;
  final bool available;
  final String? reason;
}
