import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

final _mia = {'id': 3, 'name': 'Mario Mecánico'};

void main() {
  testWidgets('test_el_mecanico_ve_mis_ordenes_y_no_citas_ni_ordenes', (tester) async {
    useDesktopWindow(tester);
    await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: ordersHandler()));

    final menu = find.byType(NavigationRail);
    expect(find.descendant(of: menu, matching: find.text('Mis órdenes')), findsOneWidget);
    expect(find.descendant(of: menu, matching: find.text('Citas')), findsNothing);
    expect(find.descendant(of: menu, matching: find.text('Órdenes')), findsNothing);
    expect(find.byKey(const ValueKey('atajo-myOrders')), findsOneWidget);
  });

  testWidgets('test_la_lista_muestra_las_ordenes_asignadas_sin_boton_de_alta_ni_filtro_de_mecanico', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(
      role: 'MECHANIC',
      handler: ordersHandler(items: [orderSummaryJson(2, status: 'DIAGNOSTICO', mechanic: _mia)]),
    );
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Mis órdenes');

    expect(find.text('Órdenes que tienes asignadas'), findsOneWidget);
    expect(find.text('OS-000002'), findsOneWidget);
    expect(find.text('Mario Mecánico'), findsOneWidget);
    expect(find.text('Nueva orden'), findsNothing);
    expect(find.byKey(const ValueKey('filtro-mecanico-orden')), findsNothing);
    // El servidor limita el resultado; el cliente no manda ningún filtro de mecánico.
    expect(api.requests.where((r) => r.path == '/orders').every((r) => !r.query.containsKey('mechanicId')), isTrue);
  });

  testWidgets('test_sin_ordenes_asignadas_muestra_el_estado_vacio', (tester) async {
    useDesktopWindow(tester);
    await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: ordersHandler(items: [])));
    await openSection(tester, 'Mis órdenes');

    expect(find.text('No tienes órdenes asignadas.'), findsOneWidget);
  });

  testWidgets('test_el_filtro_entregado_pide_esas_ordenes_al_servidor', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(
      role: 'MECHANIC',
      handler: ordersHandler(
        items: [
          orderSummaryJson(2, status: 'DIAGNOSTICO', mechanic: _mia),
          orderSummaryJson(6, status: 'ENTREGADO', mechanic: _mia, plate: 'OLD-111-A'),
        ],
      ),
    );
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Mis órdenes');
    expect(find.text('En curso'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('filtro-estado-orden')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entregado').last);
    await tester.pumpAndSettle();

    expect(api.requests.where((r) => r.path == '/orders').last.query['status'], 'ENTREGADO');
    expect(find.text('OS-000006'), findsOneWidget);
    expect(find.text('OS-000002'), findsNothing);
  });

  testWidgets('test_abre_el_detalle_de_una_orden_propia_y_no_ofrece_asignar', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(
      role: 'MECHANIC',
      handler: ordersHandler(
        items: [orderSummaryJson(2, status: 'DIAGNOSTICO', mechanic: _mia)],
        details: {
          2: orderDetailJson(2, status: 'DIAGNOSTICO', mechanic: _mia, diagnosis: 'Falla de bobina', allowedTransitions: ['EN_REPARACION']),
        },
      ),
    );
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Mis órdenes');
    await tester.tap(find.text('OS-000002'));
    await tester.pumpAndSettle();

    expect(find.text('Orden de servicio'), findsOneWidget);
    expect(find.text('Falla de bobina'), findsOneWidget);
    expect(find.byKey(const ValueKey('asignar-mecanico')), findsNothing);
  });

  testWidgets('test_un_error_del_servidor_se_muestra_con_reintento', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(
      role: 'MECHANIC',
      handler: ordersHandler(
        extra: (r) => r.method == 'GET' && r.path == '/orders' ? failure(500, 'INTERNAL_ERROR', 'Ocurrió un error inesperado. Inténtalo de nuevo.') : null,
      ),
    );
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Mis órdenes');

    expect(find.text('Ocurrió un error inesperado. Inténtalo de nuevo.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
