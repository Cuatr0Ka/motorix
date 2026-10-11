import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      partJson(1, movements: [movementJson(1, 'IN', 10, reason: 'Stock inicial')]),
      partJson(2, code: 'BUJ-001', name: 'Bujía', unit: 'pieza', stock: 2, minStock: 5),
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
    );
  }

  FakeHandler handler() => (r) {
        if (r.method == 'GET' && r.path == '/parts') {
          final search = (r.query['search'] ?? '').toLowerCase();
          final status = r.query['stockStatus'];
          final active = r.query['active'];
          final list = parts.where((p) {
            if (search.isNotEmpty && !('${p['code']}'.toLowerCase().contains(search) || '${p['name']}'.toLowerCase().contains(search))) {
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
          final id = parts.length + 1;
          parts.add(partJson(
            id,
            code: '${r.body['code']}'.toUpperCase(),
            name: '${r.body['name']}',
            unit: '${r.body['unit']}',
            stock: r.body['initialStock'] as int,
            minStock: r.body['minStock'] as int,
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
            parts[index] = partJson(
              id,
              code: '${part['code']}',
              name: '${r.body['name'] ?? part['name']}',
              unit: '${r.body['unit'] ?? part['unit']}',
              stock: part['stock'] as int,
              minStock: (r.body['minStock'] ?? part['minStock']) as int,
              active: (r.body['active'] ?? part['active']) as bool,
              movements: (part['movements'] as List).cast<Map<String, dynamic>>(),
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
        ['Confirmar', 'Guardar', 'Continuar', 'Aplicar ajuste', 'Desactivar'].contains(label) ? FilledButton : OutlinedButton,
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
