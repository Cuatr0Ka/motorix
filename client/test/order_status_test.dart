import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

final _mio = {'id': 3, 'name': 'Mario Mecánico'};

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(label == 'Confirmar' ? FilledButton : OutlinedButton, label),
    );

/// Orden simulada con estado: cada cambio de estado se refleja en las lecturas siguientes.
class StatusOrder {
  StatusOrder({this.status = 'RECIBIDO', this.mechanic = const {'id': 3, 'name': 'Mario Mecánico'}, required this.allowed});

  String status;
  Map<String, dynamic>? mechanic;
  List<String> allowed;
  FakeRequest? last;

  Map<String, dynamic> toJson() => orderDetailJson(1, status: status, mechanic: mechanic, allowedTransitions: allowed);

  FakeHandler handler({Map<String, List<String>> next = const {}, http404 = false}) {
    return ordersHandler(
      items: [orderSummaryJson(1, status: status, mechanic: mechanic)],
      extra: (r) {
        if (r.method == 'GET' && r.path == '/orders/1') return ok(toJson());
        if (r.method == 'POST' && r.path == '/orders/1/status') {
          last = r;
          status = '${r.body['status']}';
          allowed = next[status] ?? [];
          return ok(toJson());
        }
        return null;
      },
    );
  }
}

Future<void> openOrder(WidgetTester tester, {String section = 'Mis órdenes'}) async {
  await openSection(tester, section);
  await tester.tap(find.text('OS-000001'));
  await tester.pumpAndSettle();
}

void main() {
  group('avance de la orden', () {
    testWidgets('test_los_botones_salen_de_las_transiciones_permitidas_por_el_servidor', (tester) async {
      useDesktopWindow(tester);
      final order = StatusOrder(status: 'DIAGNOSTICO', allowed: ['EN_REPARACION', 'ESPERANDO_REFACCION']);
      await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: order.handler()));
      await openOrder(tester);

      expect(find.text('Avance de la orden'), findsOneWidget);
      expect(find.byKey(const ValueKey('cambiar-estado-EN_REPARACION')), findsOneWidget);
      expect(find.byKey(const ValueKey('cambiar-estado-ESPERANDO_REFACCION')), findsOneWidget);
      expect(find.byKey(const ValueKey('cambiar-estado-TERMINADO')), findsNothing);
      expect(find.text('Iniciar reparación'), findsOneWidget);
      expect(find.text('Esperando refacción'), findsWidgets);
    });

    testWidgets('test_avanza_la_orden_y_actualiza_el_estado_los_botones_y_el_aviso', (tester) async {
      useDesktopWindow(tester);
      final order = StatusOrder(allowed: ['DIAGNOSTICO']);
      final api = FakeApi(
        role: 'MECHANIC',
        handler: order.handler(next: {
          'DIAGNOSTICO': ['EN_REPARACION', 'ESPERANDO_REFACCION'],
        }),
      );
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);

      await tester.tap(find.byKey(const ValueKey('cambiar-estado-DIAGNOSTICO')));
      await tester.pumpAndSettle();

      expect(order.last!.body, {'status': 'DIAGNOSTICO'});
      expect(find.text('Estado actualizado a Diagnóstico.'), findsOneWidget);
      expect(find.byKey(const ValueKey('cambiar-estado-DIAGNOSTICO')), findsNothing);
      expect(find.byKey(const ValueKey('cambiar-estado-EN_REPARACION')), findsOneWidget);
    });

    testWidgets('test_reanudar_desde_esperando_refaccion_usa_su_propio_texto', (tester) async {
      useDesktopWindow(tester);
      final order = StatusOrder(status: 'ESPERANDO_REFACCION', allowed: ['EN_REPARACION']);
      await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: order.handler()));
      await openOrder(tester);

      expect(find.text('Reanudar reparación'), findsOneWidget);
    });

    testWidgets('test_marcar_como_terminada_no_pide_confirmacion', (tester) async {
      useDesktopWindow(tester);
      final order = StatusOrder(status: 'EN_REPARACION', allowed: ['TERMINADO', 'ESPERANDO_REFACCION']);
      final api = FakeApi(role: 'MECHANIC', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);

      await tester.tap(find.byKey(const ValueKey('cambiar-estado-TERMINADO')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(order.last!.body, {'status': 'TERMINADO'});
      expect(find.text('Estado actualizado a Terminado.'), findsOneWidget);
    });
  });

  group('entrega', () {
    testWidgets('test_recepcion_registra_la_entrega_solo_tras_confirmar', (tester) async {
      useDesktopWindow(tester);
      final order = StatusOrder(status: 'TERMINADO', allowed: ['ENTREGADO']);
      final api = FakeApi(role: 'RECEPTIONIST', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester, section: 'Órdenes');

      await tester.tap(find.byKey(const ValueKey('cambiar-estado-ENTREGADO')));
      await tester.pumpAndSettle();
      expect(find.text('Registrar entrega'), findsWidgets);
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();
      expect(order.last, isNull);

      await tester.tap(find.byKey(const ValueKey('cambiar-estado-ENTREGADO')));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Confirmar'));
      await tester.pumpAndSettle();

      expect(order.last!.body, {'status': 'ENTREGADO'});
      expect(find.text('Estado actualizado a Entregado.'), findsOneWidget);
      expect(find.text('Orden entregada: solo lectura.'), findsOneWidget);
      expect(find.byKey(const ValueKey('cambiar-estado-ENTREGADO')), findsNothing);
    });

    testWidgets('test_el_mecanico_no_ve_el_boton_de_entrega_porque_el_servidor_no_lo_ofrece', (tester) async {
      useDesktopWindow(tester);
      final order = StatusOrder(status: 'TERMINADO', allowed: []);
      await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: order.handler()));
      await openOrder(tester);

      expect(find.byKey(const ValueKey('cambiar-estado-ENTREGADO')), findsNothing);
      expect(find.text('Avance de la orden'), findsNothing);
    });

    testWidgets('test_una_orden_entregada_no_ofrece_avance', (tester) async {
      useDesktopWindow(tester);
      final order = StatusOrder(status: 'ENTREGADO', allowed: []);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: order.handler()));
      await openOrder(tester, section: 'Órdenes');

      expect(find.text('Avance de la orden'), findsNothing);
      expect(find.text('Orden entregada: solo lectura.'), findsOneWidget);
    });
  });

  group('sin mecánico y conflictos', () {
    testWidgets('test_una_orden_sin_mecanico_explica_que_hay_que_asignar_uno', (tester) async {
      useDesktopWindow(tester);
      final order = StatusOrder(mechanic: null, allowed: []);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: order.handler()));
      await openOrder(tester, section: 'Órdenes');

      expect(find.text('Asigna un mecánico para iniciar el trabajo.'), findsOneWidget);
      expect(find.byKey(const ValueKey('cambiar-estado-DIAGNOSTICO')), findsNothing);
    });

    testWidgets('test_un_conflicto_recarga_la_orden_y_muestra_el_estado_vigente', (tester) async {
      useDesktopWindow(tester);
      // La orden ya está en Diagnóstico en el servidor, pero la pantalla aún muestra Recibido.
      var enServidor = 'RECIBIDO';
      final base = ordersHandler(
        items: [orderSummaryJson(1, mechanic: _mio)],
        extra: (r) {
          if (r.method == 'GET' && r.path == '/orders/1') {
            return ok(orderDetailJson(
              1,
              status: enServidor,
              mechanic: _mio,
              allowedTransitions: enServidor == 'RECIBIDO' ? ['DIAGNOSTICO'] : ['EN_REPARACION'],
            ));
          }
          if (r.method == 'POST' && r.path == '/orders/1/status') {
            enServidor = 'DIAGNOSTICO';
            return failure(
              409,
              'STATE_CONFLICT',
              'El estado de la orden cambió mientras la revisabas. Ahora está en Diagnóstico. Revisa la orden e inténtalo de nuevo.',
              details: {'currentStatus': 'DIAGNOSTICO'},
            );
          }
          return null;
        },
      );
      await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: base));
      await openOrder(tester);

      await tester.tap(find.byKey(const ValueKey('cambiar-estado-DIAGNOSTICO')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ahora está en Diagnóstico'), findsOneWidget);
      // La orden se recargó: ya muestra el estado vigente y sus nuevas acciones.
      expect(find.byKey(const ValueKey('cambiar-estado-DIAGNOSTICO')), findsNothing);
      expect(find.byKey(const ValueKey('cambiar-estado-EN_REPARACION')), findsOneWidget);
    });

    testWidgets('test_muestra_el_error_de_transicion_invalida_del_servidor', (tester) async {
      useDesktopWindow(tester);
      final base = ordersHandler(
        items: [orderSummaryJson(1, mechanic: _mio)],
        extra: (r) {
          if (r.method == 'GET' && r.path == '/orders/1') {
            return ok(orderDetailJson(1, mechanic: _mio, allowedTransitions: ['DIAGNOSTICO']));
          }
          if (r.method == 'POST' && r.path == '/orders/1/status') {
            return failure(422, 'INVALID_TRANSITION', 'Ese cambio de estado no está permitido. Desde Recibido solo se puede pasar a: Diagnóstico.');
          }
          return null;
        },
      );
      await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: base));
      await openOrder(tester);

      await tester.tap(find.byKey(const ValueKey('cambiar-estado-DIAGNOSTICO')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ese cambio de estado no está permitido'), findsOneWidget);
    });
  });

  group('historial', () {
    testWidgets('test_el_detalle_muestra_el_historial_con_persona_y_fecha', (tester) async {
      useDesktopWindow(tester);
      final order = StatusOrder(allowed: ['DIAGNOSTICO']);
      await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: order.handler()));
      await openOrder(tester);

      await tester.ensureVisible(find.text('Historial de estados'));
      expect(find.text('Historial de estados'), findsOneWidget);
      expect(find.text('Recepción del taller'), findsOneWidget);
    });
  });
}
