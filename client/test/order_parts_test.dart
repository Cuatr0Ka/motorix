import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

final _mio = {'id': 3, 'name': 'Mario Mecánico'};

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(['Agregar', 'Guardar', 'Quitar', 'Confirmar'].contains(label) ? FilledButton : OutlinedButton, label),
    );

Map<String, dynamic> mechanicPart(int id, String code, String name, int stock, {String unit = 'pieza'}) =>
    {'id': id, 'code': code, 'name': name, 'unit': unit, 'stock': stock};

/// Orden simulada con inventario: agregar, corregir y quitar refacciones cambia las lecturas.
class FakeOrderWithParts {
  FakeOrderWithParts({this.status = 'EN_REPARACION'});

  String status;
  final Map<int, int> stock = {1: 10, 2: 0, 3: 4};
  final Map<int, String> names = {1: 'Balatas', 2: 'Correa', 3: 'Bujía'};
  final List<Map<String, dynamic>> lines = [];
  int _nextLine = 1;

  Map<String, dynamic> toJson() => orderDetailJson(1, status: status, mechanic: _mio, parts: lines);

  FakeHandler handler() => ordersHandler(
        items: [orderSummaryJson(1, status: status, mechanic: _mio)],
        extra: (r) {
          if (r.method == 'GET' && r.path == '/orders/1') return ok(toJson());
          if (r.method == 'GET' && r.path == '/parts') {
            final search = (r.query['search'] ?? '').toLowerCase();
            final list = [
              for (final id in stock.keys)
                if (search.isEmpty || names[id]!.toLowerCase().contains(search)) mechanicPart(id, 'REF-$id', names[id]!, stock[id]!),
            ];
            return ok(list, meta: {'page': 1, 'pageSize': 50, 'total': list.length});
          }
          if (r.method == 'POST' && r.path == '/orders/1/parts') {
            final partId = r.body['partId'] as int;
            final quantity = r.body['quantity'] as int;
            if (quantity > stock[partId]!) {
              return failure(409, 'INSUFFICIENT_STOCK', 'No hay stock suficiente: solo hay ${stock[partId]} disponibles y se solicitaron $quantity.',
                  details: {'available': stock[partId], 'requested': quantity});
            }
            stock[partId] = stock[partId]! - quantity;
            final existing = lines.indexWhere((l) => l['partId'] == partId);
            if (existing >= 0) {
              lines[existing] = {...lines[existing], 'quantity': (lines[existing]['quantity'] as int) + quantity};
            } else {
              lines.add({
                'id': _nextLine++,
                'partId': partId,
                'code': 'REF-$partId',
                'name': names[partId],
                'unit': 'pieza',
                'quantity': quantity,
              });
            }
            return created({'item': lines.last, 'part': {}});
          }
          final match = RegExp(r'^/orders/1/parts/(\d+)$').firstMatch(r.path);
          if (match != null) {
            final index = lines.indexWhere((l) => l['id'] == int.parse(match.group(1)!));
            final line = lines[index];
            final partId = line['partId'] as int;
            if (r.method == 'PATCH') {
              final delta = (r.body['quantity'] as int) - (line['quantity'] as int);
              if (delta > stock[partId]!) {
                return failure(409, 'INSUFFICIENT_STOCK', 'No hay stock suficiente: solo hay ${stock[partId]} disponibles y se solicitaron $delta.');
              }
              stock[partId] = stock[partId]! - delta;
              lines[index] = {...line, 'quantity': r.body['quantity']};
              return ok({'item': lines[index], 'part': {}});
            }
            if (r.method == 'DELETE') {
              stock[partId] = stock[partId]! + (line['quantity'] as int);
              lines.removeAt(index);
              return ok({'deleted': true, 'part': {}});
            }
          }
          return null;
        },
      );
}

Future<void> openOrder(WidgetTester tester, {String section = 'Mis órdenes'}) async {
  await openSection(tester, section);
  await tester.tap(find.text('OS-000001'));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).last);

void main() {
  group('agregar refacciones', () {
    testWidgets('test_el_mecanico_agrega_una_refaccion_y_aparece_en_la_orden', (tester) async {
      useDesktopWindow(tester);
      final order = FakeOrderWithParts();
      final api = FakeApi(role: 'MECHANIC', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('agregar-refaccion')));

      expect(find.text('Sin refacciones registradas.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('agregar-refaccion')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('opcion-refaccion-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('cantidad-refaccion')), '3');
      await tester.tap(find.byKey(const ValueKey('confirmar-agregar-refaccion')));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/orders/1/parts');
      expect(post.body, {'partId': 1, 'quantity': 3});
      await scrollTo(tester, find.text('REF-1 · Balatas'));
      expect(find.text('3 pieza'), findsOneWidget);
      expect(find.text('Refacción agregada correctamente.'), findsOneWidget);
    });

    testWidgets('test_las_refacciones_agotadas_aparecen_deshabilitadas', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: FakeOrderWithParts().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('agregar-refaccion')));

      await tester.tap(find.byKey(const ValueKey('agregar-refaccion')));
      await tester.pumpAndSettle();

      expect(find.text('Agotada'), findsOneWidget);
      final agotada = tester.widget<ListTile>(find.byKey(const ValueKey('opcion-refaccion-2')));
      expect(agotada.enabled, isFalse);
      expect(find.text('Existencia: 10 pieza'), findsOneWidget);
    });

    testWidgets('test_stock_insuficiente_conserva_lo_capturado_y_muestra_cuantas_hay', (tester) async {
      useDesktopWindow(tester);
      final order = FakeOrderWithParts();
      final api = FakeApi(role: 'MECHANIC', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('agregar-refaccion')));

      await tester.tap(find.byKey(const ValueKey('agregar-refaccion')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('opcion-refaccion-3')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('cantidad-refaccion')), '9');
      await tester.tap(find.byKey(const ValueKey('confirmar-agregar-refaccion')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('solo hay 4 disponibles'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '9'), findsOneWidget);
      expect(order.lines, isEmpty);
    });

    testWidgets('test_valida_la_cantidad_y_exige_elegir_una_refaccion_sin_llamar_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: FakeOrderWithParts().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('agregar-refaccion')));

      await tester.tap(find.byKey(const ValueKey('agregar-refaccion')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirmar-agregar-refaccion')));
      await tester.pumpAndSettle();
      expect(find.text('Elige una refacción de la lista.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('opcion-refaccion-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('cantidad-refaccion')), '0');
      await tester.tap(find.byKey(const ValueKey('confirmar-agregar-refaccion')));
      await tester.pumpAndSettle();
      expect(find.text('La cantidad debe ser al menos 1.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('cantidad-refaccion')), '2.5');
      await tester.tap(find.byKey(const ValueKey('confirmar-agregar-refaccion')));
      await tester.pumpAndSettle();
      expect(find.text('La cantidad debe ser un número entero.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/orders/1/parts'), isEmpty);
    });
  });

  group('corregir y quitar', () {
    FakeOrderWithParts conLinea() {
      final order = FakeOrderWithParts();
      order.stock[1] = 7;
      order.lines.add({'id': 1, 'partId': 1, 'code': 'REF-1', 'name': 'Balatas', 'unit': 'pieza', 'quantity': 3});
      order._nextLine = 2;
      return order;
    }

    testWidgets('test_corrige_la_cantidad_de_una_linea', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: conLinea().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('editar-refaccion-orden-1')));

      await tester.tap(find.byKey(const ValueKey('editar-refaccion-orden-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('cantidad-corregida')), '5');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/orders/1/parts/1');
      expect(patch.body, {'quantity': 5});
      await scrollTo(tester, find.byKey(const ValueKey('cantidad-orden-1')));
      expect(find.text('5 pieza'), findsOneWidget);
      expect(find.text('Cantidad actualizada correctamente.'), findsOneWidget);
    });

    testWidgets('test_corregir_por_encima_del_stock_muestra_el_error_en_el_dialogo', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: conLinea().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('editar-refaccion-orden-1')));

      await tester.tap(find.byKey(const ValueKey('editar-refaccion-orden-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('cantidad-corregida')), '30');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('error-corregir-refaccion')), findsOneWidget);
      expect(find.textContaining('solo hay 7 disponibles'), findsOneWidget);
    });

    testWidgets('test_quitar_pide_confirmacion_e_informa_que_regresa_al_inventario', (tester) async {
      useDesktopWindow(tester);
      final order = conLinea();
      final api = FakeApi(role: 'MECHANIC', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('quitar-refaccion-orden-1')));

      await tester.tap(find.byKey(const ValueKey('quitar-refaccion-orden-1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('La cantidad regresa al inventario.'), findsOneWidget);
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);

      await tester.tap(find.byKey(const ValueKey('quitar-refaccion-orden-1')));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Quitar'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'DELETE' && r.path == '/orders/1/parts/1'), hasLength(1));
      expect(order.stock[1], 10);
      await scrollTo(tester, find.text('Sin refacciones registradas.'));
      expect(find.text('Sin refacciones registradas.'), findsOneWidget);
    });
  });

  group('solo lectura y permisos', () {
    testWidgets('test_la_orden_entregada_se_muestra_en_solo_lectura', (tester) async {
      useDesktopWindow(tester);
      final order = FakeOrderWithParts(status: 'ENTREGADO');
      order.lines.add({'id': 1, 'partId': 1, 'code': 'REF-1', 'name': 'Balatas', 'unit': 'pieza', 'quantity': 3});
      final api = FakeApi(role: 'ADMIN', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester, section: 'Órdenes');
      await scrollTo(tester, find.text('REF-1 · Balatas'));

      expect(find.text('REF-1 · Balatas'), findsOneWidget);
      expect(find.byKey(const ValueKey('agregar-refaccion')), findsNothing);
      expect(find.byKey(const ValueKey('editar-refaccion-orden-1')), findsNothing);
      expect(find.byKey(const ValueKey('quitar-refaccion-orden-1')), findsNothing);
    });

    testWidgets('test_recepcion_ve_las_refacciones_pero_no_puede_modificarlas', (tester) async {
      useDesktopWindow(tester);
      final order = FakeOrderWithParts();
      order.lines.add({'id': 1, 'partId': 1, 'code': 'REF-1', 'name': 'Balatas', 'unit': 'pieza', 'quantity': 3});
      final api = FakeApi(role: 'RECEPTIONIST', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester, section: 'Órdenes');
      await scrollTo(tester, find.text('REF-1 · Balatas'));

      expect(find.text('3 pieza'), findsOneWidget);
      expect(find.byKey(const ValueKey('agregar-refaccion')), findsNothing);
      expect(find.byKey(const ValueKey('quitar-refaccion-orden-1')), findsNothing);
    });
  });
}
