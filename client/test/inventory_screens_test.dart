import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:motorix_client/models/part.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

Map<String, dynamic> partJson(
  int id, {
  String code = 'BAL-DEL',
  String name = 'Balatas delanteras',
  String unit = 'juego',
  int stock = 10,
  int minStock = 3,
  bool active = true,
  List<Map<String, dynamic>> movements = const [],
  String? category,
  String? brand,
  String? purchasePrice,
  String? salePrice = '100.00',
}) =>
    {
      'id': id,
      'code': code,
      'name': name,
      'description': null,
      'unit': unit,
      'stock': stock,
      'minStock': minStock,
      'active': active,
      'stockStatus': stock == 0 ? 'AGOTADO' : (stock <= minStock ? 'BAJO' : 'SUFICIENTE'),
      'movements': movements,
      'category': category,
      'brand': brand,
      'purchasePrice': purchasePrice,
      'salePrice': salePrice,
      'priceMissing': salePrice == null,
    };

Map<String, dynamic> movementJson(int id, String type, int quantity, {String? reason, String? order}) => {
      'id': id,
      'type': type,
      'quantity': quantity,
      'reason': reason,
      'createdAt': '2030-10-10T14:00:00.000Z',
      'order': order == null ? null : {'id': 12, 'folio': order},
      'createdBy': {'id': 1, 'name': 'Administrador'},
    };

/// Inventario simulado con estado: las entradas, los ajustes y las ediciones cambian las lecturas.
class FakeInventory {
  FakeInventory() {
    parts = [
      partJson(1,
          category: 'Frenos',
          brand: 'Brembo',
          purchasePrice: '300.00',
          salePrice: '450.50',
          movements: [movementJson(1, 'IN', 10, reason: 'Stock inicial')]),
      partJson(2, code: 'BUJ-001', name: 'Bujía', unit: 'pieza', stock: 2, minStock: 5, category: 'Encendido', brand: 'NGK', salePrice: null),
      partJson(3, code: 'COR-003', name: 'Correa', stock: 0, minStock: 2),
      partJson(4, code: 'DIS-004', name: 'Disco viejo', stock: 4, minStock: 1, active: false),
    ];
  }

  late List<Map<String, dynamic>> parts;
  int _nextMovement = 100;

  Map<String, dynamic> byId(int id) => parts.firstWhere((p) => p['id'] == id);

  void apply(int id, int delta, String type, String? reason) {
    final part = byId(id);
    final stock = (part['stock'] as int) + delta;
    final movements = [movementJson(_nextMovement++, type, delta, reason: reason), ...(part['movements'] as List)];
    final index = parts.indexOf(part);
    parts[index] = partJson(
      id,
      code: '${part['code']}',
      name: '${part['name']}',
      unit: '${part['unit']}',
      stock: stock,
      minStock: part['minStock'] as int,
      active: part['active'] as bool,
      movements: movements.cast<Map<String, dynamic>>(),
      category: part['category'] as String?,
      brand: part['brand'] as String?,
      purchasePrice: part['purchasePrice'] as String?,
      salePrice: part['salePrice'] as String?,
    );
  }

  /// Como el servidor: una venta menor a la compra responde 422 PRICE_BELOW_COST salvo con confirmación.
  http.Response? _belowCost(Object? sale, Object? purchase, Object? confirm) {
    if (sale == null || purchase == null || confirm == true) return null;
    if (double.parse('$sale') >= double.parse('$purchase')) return null;
    return failure(422, 'PRICE_BELOW_COST', 'El precio de venta es menor al de compra. Confirma para guardarlo.',
        details: {'salePrice': '$sale', 'purchasePrice': '$purchase'});
  }

  FakeHandler handler() => (r) {
        if (r.method == 'GET' && r.path == '/parts') {
          final search = (r.query['search'] ?? '').toLowerCase();
          final status = r.query['stockStatus'];
          final active = r.query['active'];
          final list = parts.where((p) {
            final searchable = ['code', 'name', 'category', 'brand'].map((k) => '${p[k] ?? ''}'.toLowerCase());
            if (search.isNotEmpty && !searchable.any((value) => value.contains(search))) {
              return false;
            }
            if (status != null && p['stockStatus'] != status) return false;
            if (active != null && '${p['active']}' != active) return false;
            return true;
          }).toList();
          return ok(list, meta: {'page': 1, 'pageSize': 20, 'total': list.length});
        }
        if (r.method == 'POST' && r.path == '/parts') {
          if (r.body['code'] == 'BAL-DEL') return failure(409, 'PART_CODE_TAKEN', 'Ya existe una refacción con ese código.');
          final belowCost = _belowCost(r.body['salePrice'], r.body['purchasePrice'], r.body['confirmBelowCost']);
          if (belowCost != null) return belowCost;
          final id = parts.length + 1;
          parts.add(partJson(
            id,
            code: '${r.body['code']}'.toUpperCase(),
            name: '${r.body['name']}',
            unit: '${r.body['unit']}',
            stock: r.body['initialStock'] as int,
            minStock: r.body['minStock'] as int,
            category: r.body['category'] as String?,
            brand: r.body['brand'] as String?,
            purchasePrice: r.body['purchasePrice'] as String?,
            salePrice: r.body['salePrice'] as String?,
          ));
          return created(parts.last);
        }
        final detail = RegExp(r'^/parts/(\d+)$').firstMatch(r.path);
        if (detail != null) {
          final id = int.parse(detail.group(1)!);
          if (r.method == 'GET') return ok(byId(id));
          if (r.method == 'PATCH') {
            final part = byId(id);
            final index = parts.indexOf(part);
            final belowCost = _belowCost(
              r.body['salePrice'] ?? part['salePrice'],
              r.body.containsKey('purchasePrice') ? r.body['purchasePrice'] : part['purchasePrice'],
              r.body['confirmBelowCost'],
            );
            if (belowCost != null) return belowCost;
            parts[index] = partJson(
              id,
              code: '${part['code']}',
              name: '${r.body['name'] ?? part['name']}',
              unit: '${r.body['unit'] ?? part['unit']}',
              stock: part['stock'] as int,
              minStock: (r.body['minStock'] ?? part['minStock']) as int,
              active: (r.body['active'] ?? part['active']) as bool,
              movements: (part['movements'] as List).cast<Map<String, dynamic>>(),
              category: r.body.containsKey('category') ? r.body['category'] as String? : part['category'] as String?,
              brand: r.body.containsKey('brand') ? r.body['brand'] as String? : part['brand'] as String?,
              purchasePrice: r.body.containsKey('purchasePrice') ? r.body['purchasePrice'] as String? : part['purchasePrice'] as String?,
              salePrice: (r.body['salePrice'] ?? part['salePrice']) as String?,
            );
            return ok(parts[index]);
          }
        }
        final movement = RegExp(r'^/parts/(\d+)/movements$').firstMatch(r.path);
        if (movement != null && r.method == 'POST') {
          final id = int.parse(movement.group(1)!);
          if (r.body['type'] == 'IN') {
            apply(id, r.body['quantity'] as int, 'IN', r.body['reason'] as String?);
          } else {
            final counted = r.body['countedQuantity'] as int;
            apply(id, counted - (byId(id)['stock'] as int), 'ADJUSTMENT', r.body['reason'] as String?);
          }
          return created({'movement': (byId(id)['movements'] as List).first, 'part': byId(id)});
        }
        return null;
      };
}

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(
        ['Confirmar', 'Guardar', 'Guardar de todos modos', 'Continuar', 'Aplicar ajuste', 'Desactivar'].contains(label) ? FilledButton : OutlinedButton,
        label,
      ),
    );

Future<void> openPart(WidgetTester tester, String code) async {
  await openSection(tester, 'Inventario');
  await tester.tap(find.text(code));
  await tester.pumpAndSettle();
}

void main() {
  group('listado de inventario', () {
    testWidgets('test_el_administrador_ve_el_inventario_con_el_estado_de_stock', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Inventario');

      expect(find.text('BAL-DEL'), findsOneWidget);
      expect(find.text('Suficiente'), findsOneWidget);
      expect(find.text('Bajo'), findsOneWidget);
      expect(find.text('Agotado'), findsOneWidget);
      expect(find.text('Inactiva'), findsOneWidget);
    });

    testWidgets('test_filtra_por_estado_de_stock_y_busca_por_nombre', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Inventario');

      await tester.tap(find.byKey(const ValueKey('filtro-estado-stock')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agotado').last);
      await tester.pumpAndSettle();

      expect(find.text('COR-003'), findsOneWidget);
      expect(find.text('BAL-DEL'), findsNothing);
      expect(api.requests.any((r) => r.path == '/parts' && r.query['stockStatus'] == 'AGOTADO'), isTrue);

      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'buj');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('BUJ-001'), findsOneWidget);
      expect(find.text('BAL-DEL'), findsNothing);
    });

    testWidgets('test_un_resultado_vacio_muestra_el_mensaje', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: (r) => r.path == '/parts' ? ok([], meta: {'page': 1, 'pageSize': 20, 'total': 0}) : null);
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Inventario');

      expect(find.text('Todavía no hay refacciones registradas.'), findsOneWidget);
    });

    testWidgets('test_un_error_del_servidor_permite_reintentar', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        role: 'ADMIN',
        handler: (r) {
          if (r.path == '/parts') return failure(500, 'INTERNAL_ERROR', 'No se pudo cargar el inventario.');
          if (r.path == '/parts/alerts') return ok({'count': 0, 'outOfStock': 0, 'items': []});
          return null;
        },
      );
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Inventario');

      expect(find.text('No se pudo cargar el inventario.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    for (final role in ['RECEPTIONIST', 'MECHANIC']) {
      testWidgets('test_el_rol_${role.toLowerCase()}_no_ve_la_seccion_inventario', (tester) async {
        useDesktopWindow(tester);
        final api = FakeApi(role: role, handler: FakeInventory().handler());
        await pumpAppSignedIn(tester, api);

        expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Inventario')), findsNothing);
      });
    }
  });

  group('alta y edición', () {
    testWidgets('test_registra_una_refaccion_con_stock_inicial', (tester) async {
      useDesktopWindow(tester);
      final inventory = FakeInventory();
      final api = FakeApi(role: 'ADMIN', handler: inventory.handler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Inventario');

      await tester.tap(find.byKey(const ValueKey('nueva-refaccion')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('refaccion-codigo')), 'fil-001');
      await tester.enterText(find.byKey(const ValueKey('refaccion-nombre')), 'Filtro de aceite');
      await tester.enterText(find.byKey(const ValueKey('refaccion-unidad')), 'pieza');
      await tester.enterText(find.byKey(const ValueKey('refaccion-minimo')), '2');
      await tester.enterText(find.byKey(const ValueKey('refaccion-stock-inicial')), '8');
      await tester.tap(find.byKey(const ValueKey('guardar-refaccion')));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/parts');
      expect(post.body, {'code': 'fil-001', 'name': 'Filtro de aceite', 'description': null, 'unit': 'pieza', 'minStock': 2, 'initialStock': 8});
      expect(find.text('FIL-001'), findsOneWidget);
      expect(find.text('Refacción registrada correctamente.'), findsOneWidget);
    });

    testWidgets('test_valida_los_campos_obligatorios_sin_llamar_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Inventario');

      await tester.tap(find.byKey(const ValueKey('nueva-refaccion')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('refaccion-minimo')), '-1');
      await tester.tap(find.byKey(const ValueKey('guardar-refaccion')));
      await tester.pumpAndSettle();

      expect(find.text('El código es obligatorio.'), findsOneWidget);
      expect(find.text('El nombre debe tener al menos 2 caracteres.'), findsOneWidget);
      expect(find.text('La unidad de medida es obligatoria.'), findsOneWidget);
      expect(find.text('El stock mínimo no puede ser negativo.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/parts'), isEmpty);
    });

    testWidgets('test_un_codigo_duplicado_se_muestra_en_el_campo', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Inventario');

      await tester.tap(find.byKey(const ValueKey('nueva-refaccion')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('refaccion-codigo')), 'BAL-DEL');
      await tester.enterText(find.byKey(const ValueKey('refaccion-nombre')), 'Repetida');
      await tester.enterText(find.byKey(const ValueKey('refaccion-unidad')), 'pieza');
      await tester.tap(find.byKey(const ValueKey('guardar-refaccion')));
      await tester.pumpAndSettle();

      expect(find.text('Ya existe una refacción con ese código.'), findsOneWidget);
    });

    testWidgets('test_al_editar_el_codigo_esta_bloqueado_y_no_hay_stock_inicial', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openPart(tester, 'BAL-DEL');

      await tester.tap(find.byKey(const ValueKey('editar-refaccion')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('refaccion-stock-inicial')), findsNothing);
      final codigo = tester.widget<TextFormField>(find.byKey(const ValueKey('refaccion-codigo')));
      expect(codigo.enabled, isFalse);

      await tester.enterText(find.byKey(const ValueKey('refaccion-nombre')), 'Balatas premium');
      await tester.tap(find.byKey(const ValueKey('guardar-refaccion')));
      await tester.pumpAndSettle();

      final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/parts/1');
      expect(patch.body.containsKey('code'), isFalse);
      expect(patch.body['name'], 'Balatas premium');
      expect(find.text('Refacción actualizada correctamente.'), findsOneWidget);
      expect(find.text('BAL-DEL · Balatas premium'), findsOneWidget);
    });
  });

  group('precios de las refacciones (Sprint 5)', () {
    testWidgets('test_el_listado_muestra_categoria_marca_precio_y_la_etiqueta_sin_precio_de_venta', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Inventario');

      expect(find.text('Categoría'), findsOneWidget);
      expect(find.text('Marca'), findsOneWidget);
      expect(find.text('Precio de venta'), findsOneWidget);
      expect(find.text('Frenos'), findsOneWidget);
      expect(find.text('Brembo'), findsOneWidget);
      expect(find.text('\$450.50'), findsOneWidget);
      // La bujía no tiene precio de venta: se señala con el chip ámbar y no se muestra ningún importe.
      expect(find.text('Sin precio de venta'), findsOneWidget);
      // El precio de compra no aparece en el listado.
      expect(find.text('\$300.00'), findsNothing);
    });

    testWidgets('test_busca_por_categoria_y_por_marca', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Inventario');

      await tester.enterText(find.byType(TextField).first, 'brembo');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('BAL-DEL'), findsOneWidget);
      expect(find.text('BUJ-001'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'encendido');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('BUJ-001'), findsOneWidget);
      expect(find.text('BAL-DEL'), findsNothing);
    });

    testWidgets('test_el_detalle_muestra_categoria_marca_y_ambos_precios', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openPart(tester, 'BAL-DEL');

      expect(find.text('Frenos'), findsOneWidget);
      expect(find.text('Brembo'), findsOneWidget);
      expect(find.text('\$300.00'), findsOneWidget);
      expect(find.text('\$450.50'), findsOneWidget);
    });

    testWidgets('test_el_detalle_de_una_refaccion_sin_precio_muestra_la_etiqueta', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openPart(tester, 'BUJ-001');

      expect(find.text('Sin precio de venta'), findsOneWidget);
    });

    testWidgets('test_registra_una_refaccion_con_categoria_marca_y_precios', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Inventario');

      await tester.tap(find.byKey(const ValueKey('nueva-refaccion')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('refaccion-codigo')), 'fil-001');
      await tester.enterText(find.byKey(const ValueKey('refaccion-nombre')), 'Filtro de aceite');
      await tester.enterText(find.byKey(const ValueKey('refaccion-unidad')), 'pieza');
      await tester.enterText(find.byKey(const ValueKey('refaccion-categoria')), 'Filtros');
      await tester.enterText(find.byKey(const ValueKey('refaccion-marca')), 'Mann');
      await tester.enterText(find.byKey(const ValueKey('refaccion-precio-compra')), '120');
      await tester.enterText(find.byKey(const ValueKey('refaccion-precio-venta')), '180.5');
      await tester.tap(find.byKey(const ValueKey('guardar-refaccion')));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/parts');
      expect(post.body['category'], 'Filtros');
      expect(post.body['brand'], 'Mann');
      expect(post.body['purchasePrice'], '120.00');
      expect(post.body['salePrice'], '180.50');
      expect(post.body.containsKey('confirmBelowCost'), isFalse);
      expect(find.text('Refacción registrada correctamente.'), findsOneWidget);
    });

    testWidgets('test_valida_los_precios_en_pantalla_sin_llamar_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Inventario');

      await tester.tap(find.byKey(const ValueKey('nueva-refaccion')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('refaccion-codigo')), 'fil-001');
      await tester.enterText(find.byKey(const ValueKey('refaccion-nombre')), 'Filtro de aceite');
      await tester.enterText(find.byKey(const ValueKey('refaccion-unidad')), 'pieza');
      await tester.enterText(find.byKey(const ValueKey('refaccion-precio-compra')), '-5');
      await tester.enterText(find.byKey(const ValueKey('refaccion-precio-venta')), '0');
      await tester.tap(find.byKey(const ValueKey('guardar-refaccion')));
      await tester.pumpAndSettle();

      expect(find.text('El precio de compra no puede ser negativo.'), findsOneWidget);
      expect(find.text('El precio de venta debe ser mayor a cero.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/parts'), isEmpty);

      await tester.enterText(find.byKey(const ValueKey('refaccion-precio-compra')), '10.999');
      await tester.enterText(find.byKey(const ValueKey('refaccion-precio-venta')), '10000000');
      await tester.tap(find.byKey(const ValueKey('guardar-refaccion')));
      await tester.pumpAndSettle();

      expect(find.text('El precio de compra puede tener a lo sumo dos decimales.'), findsOneWidget);
      expect(find.text('El precio de venta no puede pasar de 9,999,999.99.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/parts'), isEmpty);
    });

    testWidgets('test_cancelar_el_aviso_de_venta_bajo_el_costo_no_guarda_nada', (tester) async {
      useDesktopWindow(tester);
      final inventory = FakeInventory();
      final api = FakeApi(role: 'ADMIN', handler: inventory.handler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Inventario');

      await tester.tap(find.byKey(const ValueKey('nueva-refaccion')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('refaccion-codigo')), 'liq-001');
      await tester.enterText(find.byKey(const ValueKey('refaccion-nombre')), 'Liquidación');
      await tester.enterText(find.byKey(const ValueKey('refaccion-unidad')), 'pieza');
      await tester.enterText(find.byKey(const ValueKey('refaccion-precio-compra')), '120');
      await tester.enterText(find.byKey(const ValueKey('refaccion-precio-venta')), '90');
      await tester.tap(find.byKey(const ValueKey('guardar-refaccion')));
      await tester.pumpAndSettle();

      expect(find.text('Venta por debajo del costo'), findsOneWidget);
      expect(find.textContaining('menor al de compra'), findsOneWidget);
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();

      final intentos = api.requests.where((r) => r.method == 'POST' && r.path == '/parts').toList();
      expect(intentos, hasLength(1));
      expect(intentos.single.body.containsKey('confirmBelowCost'), isFalse);
      expect(inventory.parts.where((p) => p['code'] == 'LIQ-001'), isEmpty);
    });

    testWidgets('test_confirmar_el_aviso_de_venta_bajo_el_costo_reenvia_con_la_confirmacion', (tester) async {
      useDesktopWindow(tester);
      final inventory = FakeInventory();
      final api = FakeApi(role: 'ADMIN', handler: inventory.handler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Inventario');

      await tester.tap(find.byKey(const ValueKey('nueva-refaccion')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('refaccion-codigo')), 'liq-001');
      await tester.enterText(find.byKey(const ValueKey('refaccion-nombre')), 'Liquidación');
      await tester.enterText(find.byKey(const ValueKey('refaccion-unidad')), 'pieza');
      await tester.enterText(find.byKey(const ValueKey('refaccion-precio-compra')), '120');
      await tester.enterText(find.byKey(const ValueKey('refaccion-precio-venta')), '90');
      await tester.tap(find.byKey(const ValueKey('guardar-refaccion')));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Guardar de todos modos'));
      await tester.pumpAndSettle();

      final intentos = api.requests.where((r) => r.method == 'POST' && r.path == '/parts').toList();
      expect(intentos, hasLength(2));
      expect(intentos.last.body['confirmBelowCost'], isTrue);
      expect(inventory.parts.where((p) => p['code'] == 'LIQ-001'), hasLength(1));
      expect(find.text('Refacción registrada correctamente.'), findsOneWidget);
    });

    testWidgets('test_al_editar_una_refaccion_con_precio_de_venta_el_campo_es_obligatorio', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openPart(tester, 'BAL-DEL');

      await tester.tap(find.byKey(const ValueKey('editar-refaccion')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('refaccion-precio-venta')), '');
      await tester.tap(find.byKey(const ValueKey('guardar-refaccion')));
      await tester.pumpAndSettle();

      expect(find.text('El precio de venta es obligatorio.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'PATCH' && r.path == '/parts/1'), isEmpty);
    });

    testWidgets('test_al_editar_se_puede_borrar_el_precio_de_compra_y_se_envia_null', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openPart(tester, 'BAL-DEL');

      await tester.tap(find.byKey(const ValueKey('editar-refaccion')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('refaccion-precio-compra')), '');
      await tester.tap(find.byKey(const ValueKey('guardar-refaccion')));
      await tester.pumpAndSettle();

      final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/parts/1');
      expect(patch.body.containsKey('purchasePrice'), isTrue);
      expect(patch.body['purchasePrice'], isNull);
      expect(patch.body['salePrice'], '450.50');
    });

    test('test_la_vista_reducida_del_mecanico_no_trae_precios_ni_marca_de_falta_de_precio', () {
      final parte = Part.fromJson({'id': 1, 'code': 'BAL-DEL', 'name': 'Balatas', 'unit': 'juego', 'stock': 10});

      expect(parte.salePrice, isNull);
      expect(parte.purchasePrice, isNull);
      expect(parte.category, isNull);
      expect(parte.priceMissing, isFalse);
    });

    test('test_el_modelo_lee_los_precios_como_cadenas_con_dos_decimales', () {
      final parte = Part.fromJson(partJson(7, category: 'Frenos', brand: 'Brembo', purchasePrice: '300.00', salePrice: '450.50'));

      expect(parte.purchasePrice, '300.00');
      expect(parte.salePrice, '450.50');
      expect(parte.priceMissing, isFalse);
      expect(Part.fromJson(partJson(8, salePrice: null)).priceMissing, isTrue);
    });
  });

  group('detalle, entradas y ajustes', () {
    testWidgets('test_muestra_el_stock_y_los_movimientos', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openPart(tester, 'BAL-DEL');

      expect(find.text('BAL-DEL · Balatas delanteras'), findsOneWidget);
      expect(find.text('Stock inicial'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);
      expect(find.text('Entrada'), findsOneWidget);
    });

    testWidgets('test_registra_una_entrada_y_el_stock_sube', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openPart(tester, 'BAL-DEL');

      await tester.tap(find.byKey(const ValueKey('registrar-entrada')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('entrada-cantidad')), '0');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('La cantidad debe ser al menos 1.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('entrada-cantidad')), '5');
      await tester.enterText(find.byKey(const ValueKey('entrada-motivo')), 'Compra a proveedor');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/parts/1/movements');
      expect(post.body, {'type': 'IN', 'quantity': 5, 'reason': 'Compra a proveedor'});
      expect(find.text('Entrada registrada correctamente.'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Compra a proveedor'), findsOneWidget);
    });

    testWidgets('test_el_ajuste_pide_confirmacion_con_stock_contado_y_diferencia', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openPart(tester, 'BAL-DEL');

      await tester.tap(find.byKey(const ValueKey('ajustar-inventario')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('ajuste-contada')), '10');
      await tester.enterText(find.byKey(const ValueKey('ajuste-motivo')), 'Conteo físico');
      await tester.tap(dialogButton('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('La cantidad contada es igual al stock actual: no hay nada que ajustar.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('ajuste-contada')), '7');
      await tester.pump();
      expect(find.byKey(const ValueKey('ajuste-diferencia')), findsOneWidget);
      expect(find.text('Diferencia: -3'), findsOneWidget);
      await tester.tap(dialogButton('Continuar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Stock actual: 10. Cantidad contada: 7. Diferencia: -3.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/parts/1/movements'), isEmpty);

      await tester.tap(dialogButton('Aplicar ajuste'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/parts/1/movements');
      expect(post.body, {'type': 'ADJUSTMENT', 'countedQuantity': 7, 'reason': 'Conteo físico'});
      expect(find.text('Ajuste aplicado correctamente.'), findsOneWidget);
      expect(find.text('−3'), findsOneWidget);
    });

    testWidgets('test_cancelar_la_confirmacion_del_ajuste_no_llama_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openPart(tester, 'BAL-DEL');

      await tester.tap(find.byKey(const ValueKey('ajustar-inventario')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('ajuste-contada')), '6');
      await tester.enterText(find.byKey(const ValueKey('ajuste-motivo')), 'Conteo físico');
      await tester.tap(dialogButton('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/parts/1/movements'), isEmpty);
    });

    testWidgets('test_desactivar_pide_confirmacion_y_la_inactiva_no_admite_entradas', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeInventory().handler());
      await pumpAppSignedIn(tester, api);
      await openPart(tester, 'BAL-DEL');

      await tester.tap(find.byKey(const ValueKey('activar-refaccion')));
      await tester.pumpAndSettle();
      expect(find.text('Desactivar refacción'), findsOneWidget);
      await tester.tap(dialogButton('Desactivar'));
      await tester.pumpAndSettle();

      final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/parts/1');
      expect(patch.body, {'active': false});
      expect(find.text('Refacción desactivada.'), findsOneWidget);
      expect(find.textContaining('Refacción inactiva'), findsOneWidget);
      final entrada = tester.widget<FilledButton>(find.byKey(const ValueKey('registrar-entrada')));
      expect(entrada.onPressed, isNull);
      expect(find.text('Reactivar'), findsOneWidget);
    });
  });
}
