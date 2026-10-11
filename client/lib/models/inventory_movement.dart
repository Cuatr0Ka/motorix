/// Tipo de movimiento de inventario. `quantity` siempre lleva signo: entrada (+), salida (−) o ajuste (±).
enum MovementType {
  entry('IN', 'Entrada'),
  exit('OUT', 'Salida'),
  adjustment('ADJUSTMENT', 'Ajuste');

  const MovementType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MovementType fromApi(String? value) =>
      MovementType.values.firstWhere((t) => t.apiValue == value, orElse: () => MovementType.adjustment);
}

/// Movimiento de inventario (los movimientos no se editan ni se eliminan).
class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.type,
    required this.quantity,
    required this.createdAt,
    this.reason,
    this.orderFolio,
    this.createdBy,
  });

  factory InventoryMovement.fromJson(Map<String, dynamic> json) => InventoryMovement(
        id: (json['id'] as num).toInt(),
        type: MovementType.fromApi(json['type'] as String?),
        quantity: (json['quantity'] as num).toInt(),
        reason: json['reason'] as String?,
        createdAt: DateTime.parse('${json['createdAt']}'),
        orderFolio: json['order'] == null ? null : '${(json['order'] as Map)['folio']}',
        createdBy: json['createdBy'] == null ? null : '${(json['createdBy'] as Map)['name']}',
      );

  final int id;
  final MovementType type;
  final int quantity;
  final String? reason;
  final DateTime createdAt;
  final String? orderFolio;
  final String? createdBy;

  /// «+5», «−3»: la cantidad con su signo para mostrarla.
  String get signedLabel => quantity > 0 ? '+$quantity' : '−${quantity.abs()}';
}
