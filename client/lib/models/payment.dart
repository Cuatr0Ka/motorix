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

/// Línea de servicio o de mano de obra del desglose del cobro.
class BillingLine {
  const BillingLine({required this.id, required this.description, required this.amount});

  factory BillingLine.fromJson(Map<String, dynamic> json) =>
      BillingLine(id: (json['id'] as num).toInt(), description: '${json['description']}', amount: '${json['amount']}');

  final int id;
  final String description;
  final String amount;
}

/// Refacción del desglose del cobro: cantidad, precio guardado al agregarla e importe. [legacy] marca las líneas
/// anteriores a los precios (precio 0), que no suman al total.
class BillingPart {
  const BillingPart({
    required this.id,
    required this.code,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    required this.legacy,
  });

  factory BillingPart.fromJson(Map<String, dynamic> json) => BillingPart(
        id: (json['id'] as num).toInt(),
        code: '${json['code']}',
        name: '${json['name']}',
        unit: '${json['unit']}',
        quantity: (json['quantity'] as num).toInt(),
        unitPrice: '${json['unitPrice']}',
        amount: '${json['amount']}',
        legacy: json['legacy'] as bool? ?? false,
      );

  final int id;
  final String code;
  final String name;
  final String unit;
  final int quantity;
  final String unitPrice;
  final String amount;
  final bool legacy;
}

/// Desglose del total que la recepción revisa antes de cobrar: servicios, mano de obra y refacciones con sus subtotales.
class BillingBreakdown {
  const BillingBreakdown({
    required this.services,
    required this.labor,
    required this.parts,
    required this.servicesSubtotal,
    required this.laborSubtotal,
    required this.partsSubtotal,
  });

  factory BillingBreakdown.fromJson(Map<String, dynamic> json) {
    List<T> items<T>(String key, T Function(Map<String, dynamic>) build) =>
        ((json[key] as List?) ?? const []).map((e) => build(Map<String, dynamic>.from(e as Map))).toList();
    final subtotals = Map<String, dynamic>.from((json['subtotals'] as Map?) ?? const {});
    return BillingBreakdown(
      services: items('services', BillingLine.fromJson),
      labor: items('labor', BillingLine.fromJson),
      parts: items('parts', BillingPart.fromJson),
      servicesSubtotal: '${subtotals['services'] ?? '0.00'}',
      laborSubtotal: '${subtotals['labor'] ?? '0.00'}',
      partsSubtotal: '${subtotals['parts'] ?? '0.00'}',
    );
  }

  final List<BillingLine> services;
  final List<BillingLine> labor;
  final List<BillingPart> parts;
  final String servicesSubtotal;
  final String laborSubtotal;
  final String partsSubtotal;
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
    this.amountDifference = '0.00',
    this.breakdown,
    this.ticket,
  });

  factory Billing.fromJson(Map<String, dynamic> json) => Billing(
        total: '${json['total']}',
        paidAmount: '${json['paidAmount']}',
        collectionStatus: CollectionStatus.fromApi(json['collectionStatus'] as String?),
        amountOutdated: json['amountOutdated'] as bool? ?? false,
        canCharge: json['canCharge'] as bool? ?? false,
        amountDifference: '${json['amountDifference'] ?? '0.00'}',
        breakdown: json['breakdown'] == null ? null : BillingBreakdown.fromJson(Map<String, dynamic>.from(json['breakdown'] as Map)),
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

  /// Total vigente menos el pago Pagado cuando difieren (por ejemplo, tras una aprobación tardía de Mercado Pago).
  /// Positiva si falta por cobrar; no se cobra sola.
  final String amountDifference;

  /// Desglose del total (servicios, mano de obra y refacciones).
  final BillingBreakdown? breakdown;

  bool get isPaid => collectionStatus == CollectionStatus.paid;

  bool get hasDifference => (double.tryParse(amountDifference) ?? 0) != 0;
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
