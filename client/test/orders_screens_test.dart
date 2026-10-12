import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(label == 'Confirmar' ? FilledButton : OutlinedButton, label),
    );

Future<void> chooseVehicle(WidgetTester tester) async {
  await tester.tap(find.text('Vehículo *'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('vehiculo-opcion-1')));
  await tester.pumpAndSettle();
}

Future<void> openNewOrderForm(WidgetTester tester) async {
  await openSection(tester, 'Órdenes');
  await tester.tap(find.text('Nueva orden'));
  await tester.pumpAndSettle();
}

void main() {
  group('listado de órdenes', () {
    testWidgets('test_muestra_las_ordenes_con_folio_cliente_mecanico_y_estado', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(handler: ordersHandler()));
      await openSection(tester, 'Órdenes');

      expect(find.text('OS-000001'), findsOneWidget);
      expect(find.text('OS-000002'), findsOneWidget);
      expect(find.text('Sin asignar'), findsOneWidget);
      expect(find.text('Mario Mecánico'), findsOneWidget);
      expect(find.text('Recibido'), findsWidgets);
      expect(find.text('Diagnóstico'), findsWidgets);
      expect(find.text('1–2 de 2'), findsNothing);
    });

    testWidgets('test_muestra_el_estado_vacio_con_accion_para_crear', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(handler: ordersHandler(items: [])));
      await openSection(tester, 'Órdenes');

      expect(find.text('Todavía no hay órdenes de servicio.'), findsOneWidget);
      expect(find.text('Crear la primera orden'), findsOneWidget);
    });

    testWidgets('test_el_filtro_de_estado_pide_solo_las_ordenes_de_ese_estado', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: ordersHandler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Órdenes');

      await tester.tap(find.byKey(const ValueKey('filtro-estado-orden')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Diagnóstico').last);
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.path == '/orders').last.query['status'], 'DIAGNOSTICO');
      expect(find.text('OS-000002'), findsOneWidget);
      expect(find.text('OS-000001'), findsNothing);
    });
  });

  group('crear una orden', () {
    testWidgets('test_exige_vehiculo_kilometraje_y_problema_sin_llamar_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: ordersHandler());
      await pumpAppSignedIn(tester, api);
      await openNewOrderForm(tester);

      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(find.text('Selecciona un vehículo.'), findsOneWidget);
      expect(find.text('El kilometraje de entrada es obligatorio.'), findsOneWidget);
      expect(find.text('El problema reportado es obligatorio.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/orders'), isEmpty);
    });

    testWidgets('test_crea_la_orden_directa_con_el_vehiculo_y_el_kilometraje', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: ordersHandler(
          extra: (r) => r.method == 'POST' && r.path == '/orders' ? created(orderDetailJson(7)) : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openNewOrderForm(tester);

      await chooseVehicle(tester);
      expect(find.textContaining('Cliente: Ana Morales'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Kilometraje de entrada *'), '52000');
      await tester.enterText(find.widgetWithText(TextFormField, 'Problema reportado *'), 'Ruido al frenar');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/orders');
      expect(post.body, {'vehicleId': 1, 'entryMileage': 52000, 'reportedProblem': 'Ruido al frenar'});
      expect(find.text('Orden OS-000007 creada correctamente.'), findsOneWidget);
    });

    testWidgets('test_un_kilometraje_menor_ofrece_la_correccion_con_motivo_y_reenvia', (tester) async {
      useDesktopWindow(tester);
      var intentos = 0;
      final api = FakeApi(
        handler: ordersHandler(
          extra: (r) {
            if (r.method == 'POST' && r.path == '/orders') {
              intentos++;
              if (r.body['mileageCorrection'] != true) {
                return failure(422, 'MILEAGE_DECREASE', 'El kilometraje de entrada (100 km) es menor al registrado (51200 km).');
              }
              return created(orderDetailJson(8));
            }
            return null;
          },
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openNewOrderForm(tester);

      await chooseVehicle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Kilometraje de entrada *'), '100');
      await tester.enterText(find.widgetWithText(TextFormField, 'Problema reportado *'), 'Revisión');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Corregir kilometraje'), findsOneWidget);
      expect(find.textContaining('es menor al registrado'), findsOneWidget);

      // Sin motivo suficiente no se confirma.
      await tester.enterText(find.byKey(const ValueKey('motivo-correccion')), 'abc');
      await tester.tap(dialogButton('Confirmar'));
      await tester.pump();
      expect(find.text('El motivo debe tener al menos 5 caracteres.'), findsOneWidget);
      expect(intentos, 1);

      await tester.enterText(find.byKey(const ValueKey('motivo-correccion')), 'Tablero reemplazado');
      await tester.tap(dialogButton('Confirmar'));
      await tester.pumpAndSettle();

      final ultimo = api.requests.where((r) => r.method == 'POST' && r.path == '/orders').last;
      expect(ultimo.body['mileageCorrection'], true);
      expect(ultimo.body['mileageCorrectionReason'], 'Tablero reemplazado');
      expect(intentos, 2);
      expect(find.text('Orden OS-000008 creada correctamente.'), findsOneWidget);
    });

    testWidgets('test_cancelar_el_dialogo_de_correccion_no_crea_la_orden', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: ordersHandler(
          extra: (r) => r.method == 'POST' && r.path == '/orders'
              ? failure(422, 'MILEAGE_DECREASE', 'El kilometraje de entrada (100 km) es menor al registrado (51200 km).')
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openNewOrderForm(tester);

      await chooseVehicle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Kilometraje de entrada *'), '100');
      await tester.enterText(find.widgetWithText(TextFormField, 'Problema reportado *'), 'Revisión');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/orders').length, 1);
      expect(find.text('Nueva orden'), findsWidgets);
    });

    testWidgets('test_muestra_el_error_de_orden_abierta_en_el_campo_del_vehiculo', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: ordersHandler(
          extra: (r) => r.method == 'POST' && r.path == '/orders'
              ? failure(409, 'OPEN_ORDER_EXISTS', 'El vehículo ya tiene una orden abierta (OS-000003). Debe entregarse antes de crear otra.')
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openNewOrderForm(tester);

      await chooseVehicle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Kilometraje de entrada *'), '60000');
      await tester.enterText(find.widgetWithText(TextFormField, 'Problema reportado *'), 'Ruido');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ya tiene una orden abierta (OS-000003)'), findsOneWidget);
    });

    testWidgets('test_desde_una_cita_el_vehiculo_y_el_motivo_llegan_de_la_cita', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: ordersHandler(
          extra: (r) {
            if (r.method == 'GET' && r.path == '/appointments/1') return ok(appointmentJson(1));
            if (r.method == 'POST' && r.path == '/orders') return created(orderDetailJson(9));
            return null;
          },
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Citas');
      await tester.tap(find.text('Servicio de 50 000 km'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recibir-vehiculo')));
      await tester.pumpAndSettle();
      expect(find.text('Recibir vehículo'), findsWidgets);
      expect(find.text('MNO-345-E · Honda Civic'), findsOneWidget);
      expect(find.text('Servicio de 50 000 km'), findsOneWidget); // problema reportado prellenado

      await tester.enterText(find.widgetWithText(TextFormField, 'Kilometraje de entrada *'), '51500');
      await tester.tap(find.text('Crear orden'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/orders');
      expect(post.body['appointmentId'], 1);
      expect(post.body.containsKey('vehicleId'), isFalse);
      expect(post.body['entryMileage'], 51500);
      expect(find.text('Orden OS-000009 creada correctamente.'), findsOneWidget);
    });
  });

  group('detalle de la orden (solo lectura)', () {
    testWidgets('test_muestra_los_datos_el_trabajo_los_totales_y_el_historial', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: ordersHandler(
          items: [orderSummaryJson(1, status: 'EN_REPARACION', mechanic: {'id': 3, 'name': 'Mario Mecánico'})],
          details: {
            1: orderDetailJson(
              1,
              status: 'EN_REPARACION',
              mechanic: {'id': 3, 'name': 'Mario Mecánico'},
              diagnosis: 'Balatas gastadas',
              observations: 'Disco rayado',
              recommendations: 'Cambiar discos en 10 000 km',
              services: [lineJson(1, 'Cambio de balatas', '850.00')],
              labor: [lineJson(1, 'Mano de obra frenos', '400.50')],
            ),
          },
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Órdenes');
      await tester.tap(find.text('OS-000001'));
      await tester.pumpAndSettle();

      expect(find.text('Orden de servicio'), findsOneWidget);
      expect(find.text('Balatas gastadas'), findsOneWidget);
      expect(find.text('Cambio de balatas'), findsOneWidget);
      expect(find.text('\$850.00'), findsWidgets);
      expect(find.text('\$1,250.50'), findsOneWidget);
      expect(find.text('Disco rayado'), findsOneWidget);
      expect(find.text('Cambiar discos en 10 000 km'), findsOneWidget);
      expect(find.text('Historial de estados'), findsOneWidget);
    });

    testWidgets('test_una_orden_inexistente_muestra_el_error_con_reintento', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: ordersHandler(
          extra: (r) => r.method == 'GET' && r.path == '/orders/1' ? failure(404, 'NOT_FOUND', 'La orden no existe.') : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Órdenes');
      await tester.tap(find.text('OS-000001'));
      await tester.pumpAndSettle();

      expect(find.text('La orden no existe.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
