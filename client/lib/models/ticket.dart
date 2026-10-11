/// Línea de servicio o de mano de obra del ticket.
class TicketLine {
  const TicketLine({required this.description, required this.amount});

  factory TicketLine.fromJson(Map<String, dynamic> json) =>
      TicketLine(description: '${json['description']}', amount: '${json['amount']}');

  final String description;
  final String amount;
}

/// Refacción del ticket: se lista con su cantidad y no suma importe.
class TicketPart {
  const TicketPart({required this.code, required this.name, required this.unit, required this.quantity});

  factory TicketPart.fromJson(Map<String, dynamic> json) => TicketPart(
        code: '${json['code']}',
        name: '${json['name']}',
        unit: '${json['unit']}',
        quantity: (json['quantity'] as num).toInt(),
      );

  final String code;
  final String name;
  final String unit;
  final int quantity;
}

/// Instantánea del contenido de un ticket, tal como se generó.
class TicketContent {
  const TicketContent({
    required this.shopName,
    required this.shopAddress,
    required this.shopPhone,
    required this.customerName,
    required this.plate,
    required this.vehicleLabel,
    required this.mileage,
    required this.orderFolio,
    required this.services,
    required this.parts,
    required this.labor,
    required this.servicesTotal,
    required this.laborTotal,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.generatedAt,
    this.customerPhone,
    this.paidAt,
    this.paymentReference,
  });

  factory TicketContent.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> section(String key) => Map<String, dynamic>.from(json[key] as Map);
    List<T> items<T>(String key, T Function(Map<String, dynamic>) build) =>
        ((json[key] as List?) ?? const []).map((e) => build(Map<String, dynamic>.from(e as Map))).toList();
    final shop = section('shop');
    final customer = section('customer');
    final vehicle = section('vehicle');
    final totals = section('totals');
    final payment = section('payment');
    return TicketContent(
      shopName: '${shop['name']}',
      shopAddress: '${shop['address'] ?? ''}',
      shopPhone: '${shop['phone'] ?? ''}',
      customerName: '${customer['name']}',
      customerPhone: customer['phone'] as String?,
      plate: '${vehicle['plate']}',
      vehicleLabel: '${vehicle['brand']} ${vehicle['model']} ${vehicle['year']}',
      mileage: (vehicle['mileage'] as num?)?.toInt(),
      orderFolio: '${section('order')['folio']}',
      services: items('services', TicketLine.fromJson),
      parts: items('parts', TicketPart.fromJson),
      labor: items('labor', TicketLine.fromJson),
      servicesTotal: '${totals['services']}',
      laborTotal: '${totals['labor']}',
      total: '${totals['total']}',
      paymentMethod: '${payment['method']}',
      paymentStatus: '${payment['status']}',
      paidAt: payment['paidAt'] == null ? null : DateTime.parse('${payment['paidAt']}'),
      paymentReference: payment['reference'] as String?,
      generatedAt: DateTime.parse('${json['generatedAt']}'),
    );
  }

  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final String customerName;
  final String? customerPhone;
  final String plate;
  final String vehicleLabel;
  final int? mileage;
  final String orderFolio;
  final List<TicketLine> services;
  final List<TicketPart> parts;
  final List<TicketLine> labor;
  final String servicesTotal;
  final String laborTotal;
  final String total;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime? paidAt;
  final String? paymentReference;
  final DateTime generatedAt;
}

/// Ticket de una orden cobrada. En los listados no trae [content] sino cliente, placa y total.
class Ticket {
  const Ticket({
    required this.id,
    required this.folio,
    required this.orderId,
    required this.orderFolio,
    required this.generatedAt,
    this.content,
    this.clientName,
    this.plate,
    this.total,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
        id: (json['id'] as num).toInt(),
        folio: '${json['folio']}',
        orderId: (json['orderId'] as num).toInt(),
        orderFolio: '${json['orderFolio']}',
        generatedAt: DateTime.parse('${json['generatedAt']}'),
        content: json['content'] == null ? null : TicketContent.fromJson(Map<String, dynamic>.from(json['content'] as Map)),
        clientName: json['client'] == null ? null : '${(json['client'] as Map)['name']}',
        plate: json['vehicle'] == null ? null : '${(json['vehicle'] as Map)['licensePlate']}',
        total: json['total'] as String?,
      );

  final int id;
  final String folio;
  final int orderId;
  final String orderFolio;
  final DateTime generatedAt;
  final TicketContent? content;
  final String? clientName;
  final String? plate;
  final String? total;
}
