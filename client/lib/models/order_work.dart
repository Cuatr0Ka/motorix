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

/// Totales calculados por el servidor (servicios, mano de obra y total).
class OrderTotals {
  const OrderTotals({required this.services, required this.labor, required this.total});

  factory OrderTotals.fromJson(Map<String, dynamic> json) => OrderTotals(
        services: '${json['services']}',
        labor: '${json['labor']}',
        total: '${json['total']}',
      );

  static const OrderTotals zero = OrderTotals(services: '0.00', labor: '0.00', total: '0.00');

  final String services;
  final String labor;
  final String total;
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
