import '../utils/status_labels.dart';
import 'inventory_movement.dart';

/// Refacción del catálogo. El administrador recibe todos los campos; el mecánico solo código, nombre,
/// unidad y existencia (`minStock`, `description` y `active` llegan con valores por defecto).
class Part {
  const Part({
    required this.id,
    required this.code,
    required this.name,
    required this.unit,
    required this.stock,
    this.description,
    this.minStock = 0,
    this.active = true,
    this.stockStatus = StockStatus.sufficient,
    this.movements = const [],
  });

  factory Part.fromJson(Map<String, dynamic> json) => Part(
        id: (json['id'] as num).toInt(),
        code: '${json['code']}',
        name: '${json['name']}',
        unit: '${json['unit']}',
        stock: (json['stock'] as num).toInt(),
        description: json['description'] as String?,
        minStock: (json['minStock'] as num?)?.toInt() ?? 0,
        active: json['active'] as bool? ?? true,
        stockStatus: StockStatus.fromApi(json['stockStatus'] as String?),
        movements: (json['movements'] as List? ?? const [])
            .map((e) => InventoryMovement.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  final int id;
  final String code;
  final String name;
  final String unit;
  final int stock;
  final String? description;
  final int minStock;
  final bool active;
  final StockStatus stockStatus;

  /// Últimos movimientos (solo en el detalle del administrador).
  final List<InventoryMovement> movements;

  bool get isOutOfStock => stock == 0;

  /// Texto para los selectores: «código · nombre».
  String get label => '$code · $name';
}

/// Datos capturados en el formulario de refacción. `initialStock` solo se envía al crear.
class PartInput {
  const PartInput({
    required this.name,
    required this.unit,
    required this.minStock,
    this.code,
    this.description,
    this.initialStock,
  });

  final String? code;
  final String name;
  final String? description;
  final String unit;
  final int minStock;
  final int? initialStock;

  Map<String, dynamic> toJson() => {
        if (code != null) 'code': code,
        'name': name,
        'description': description,
        'unit': unit,
        'minStock': minStock,
        if (initialStock != null) 'initialStock': initialStock,
      };
}

/// Resumen de las alertas de stock bajo (administrador).
class StockAlerts {
  const StockAlerts({required this.count, required this.outOfStock, required this.items});

  factory StockAlerts.fromJson(Map<String, dynamic> json) => StockAlerts(
        count: (json['count'] as num).toInt(),
        outOfStock: (json['outOfStock'] as num).toInt(),
        items: (json['items'] as List? ?? const [])
            .map((e) => Part.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  static const StockAlerts none = StockAlerts(count: 0, outOfStock: 0, items: []);

  final int count;
  final int outOfStock;
  final List<Part> items;
}
