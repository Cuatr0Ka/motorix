/// Línea de servicio realizado o de mano de obra de una orden. El importe viaja como cadena decimal.
class OrderLine {
  const OrderLine({required this.id, required this.description, required this.amount});

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        id: (json['id'] as num).toInt(),
        description: '${json['description']}',
        amount: '${json['amount']}',
      );

  final int id;
  final String description;
  final String amount;
}

/// Totales calculados por el servidor (servicios, mano de obra, refacciones y total). [parts] solo llega a
/// administración y recepción: el mecánico recibe un total que suma únicamente servicios y mano de obra.
class OrderTotals {
  const OrderTotals({required this.services, required this.labor, required this.total, this.parts});

  factory OrderTotals.fromJson(Map<String, dynamic> json) => OrderTotals(
        services: '${json['services']}',
        labor: '${json['labor']}',
        total: '${json['total']}',
        parts: json['parts'] == null ? null : '${json['parts']}',
      );

  static const OrderTotals zero = OrderTotals(services: '0.00', labor: '0.00', total: '0.00');

  final String services;
  final String labor;
  final String total;
  final String? parts;
}

/// Datos de una línea (servicio o mano de obra) capturados en el formulario.
class OrderLineInput {
  const OrderLineInput({required this.description, required this.amount});

  final String description;
  final String amount;

  Map<String, dynamic> toJson() => {'description': description, 'amount': amount};
}

/// Resultado de agregar o corregir una línea: la línea y los totales recalculados.
class OrderLineResult {
  const OrderLineResult({required this.line, required this.totals});

  final OrderLine line;
  final OrderTotals totals;
}

/// Tipo de línea de una orden: servicios realizados o mano de obra (segmento de la ruta de la API).
enum OrderLineKind {
  services('services'),
  labor('labor');

  const OrderLineKind(this.path);

  final String path;
}

/// Refacción utilizada en una orden (una línea por refacción). `available` es la existencia actual,
/// para mostrar cuánto más se puede agregar.
class OrderPart {
  const OrderPart({
    required this.id,
    required this.partId,
    required this.code,
    required this.name,
    required this.unit,
    required this.quantity,
    this.unitPrice,
    this.amount,
    this.legacy = false,
  });

  factory OrderPart.fromJson(Map<String, dynamic> json) => OrderPart(
        id: (json['id'] as num).toInt(),
        partId: (json['partId'] as num).toInt(),
        code: '${json['code']}',
        name: '${json['name']}',
        unit: '${json['unit']}',
        quantity: (json['quantity'] as num).toInt(),
        unitPrice: json['unitPrice'] == null ? null : '${json['unitPrice']}',
        amount: json['amount'] == null ? null : '${json['amount']}',
        legacy: json['legacy'] as bool? ?? false,
      );

  final int id;
  final int partId;
  final String code;
  final String name;
  final String unit;
  final int quantity;

  /// Precio de venta guardado al agregar la refacción y su importe (cantidad por precio). Solo los reciben
  /// administración y recepción; el mecánico no ve ningún precio.
  final String? unitPrice;
  final String? amount;

  /// Verdadero en las líneas anteriores a los precios (precio 0): no suman al total.
  final bool legacy;

  bool get hasPrice => unitPrice != null;
}
