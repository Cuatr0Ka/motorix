import '../utils/status_labels.dart';
import 'inventory_movement.dart';

/// Refacción del catálogo. El administrador recibe todos los campos; el mecánico solo código, nombre,
/// unidad y existencia (`minStock`, `description`, `active` y los datos de precios llegan vacíos).
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
    this.category,
    this.brand,
    this.purchasePrice,
    this.salePrice,
    this.priceMissing = false,
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
        category: json['category'] as String?,
        brand: json['brand'] as String?,
        purchasePrice: json['purchasePrice'] == null ? null : '${json['purchasePrice']}',
        salePrice: json['salePrice'] == null ? null : '${json['salePrice']}',
        priceMissing: json['priceMissing'] as bool? ?? false,
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

  /// Categoría, marca y precios (cadenas con dos decimales): solo los recibe el administrador.
  final String? category;
  final String? brand;
  final String? purchasePrice;
  final String? salePrice;

  /// Verdadero si todavía no tiene precio de venta: no se puede agregar a una orden.
  final bool priceMissing;

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
    this.category,
    this.brand,
    this.purchasePrice,
    this.salePrice,
    this.confirmBelowCost = false,
  });

  final String? code;
  final String name;
  final String? description;
  final String unit;
  final int minStock;
  final int? initialStock;
  final String? category;
  final String? brand;

  /// Precios capturados como texto ("120.00"); el de compra es opcional y el de venta se puede omitir al crear.
  final String? purchasePrice;
  final String? salePrice;

  /// Confirmación explícita de una venta por debajo del costo (el servidor responde `PRICE_BELOW_COST` sin ella).
  final bool confirmBelowCost;

  /// Copia con la confirmación de venta bajo el costo.
  PartInput confirmed() => PartInput(
        code: code,
        name: name,
        description: description,
        unit: unit,
        minStock: minStock,
        initialStock: initialStock,
        category: category,
        brand: brand,
        purchasePrice: purchasePrice,
        salePrice: salePrice,
        confirmBelowCost: true,
      );

  /// Cuerpo del alta: los datos de precios se envían solo cuando tienen valor.
  Map<String, dynamic> toJson() => {
        if (code != null) 'code': code,
        'name': name,
        'description': description,
        'unit': unit,
        'minStock': minStock,
        if (initialStock != null) 'initialStock': initialStock,
        if (category != null) 'category': category,
        if (brand != null) 'brand': brand,
        if (purchasePrice != null) 'purchasePrice': purchasePrice,
        if (salePrice != null) 'salePrice': salePrice,
        if (confirmBelowCost) 'confirmBelowCost': true,
      };

  /// Cuerpo de la edición: el precio de compra vacío se envía como `null` (borra el dato); el de venta, una vez
  /// capturado, no se puede borrar y por eso se omite cuando está vacío.
  Map<String, dynamic> toUpdateJson() => {
        'name': name,
        'description': description,
        'unit': unit,
        'minStock': minStock,
        'category': category,
        'brand': brand,
        'purchasePrice': purchasePrice,
        if (salePrice != null) 'salePrice': salePrice,
        if (confirmBelowCost) 'confirmBelowCost': true,
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
