import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

Map<String, dynamic> dashboardJson({
  int attended = 6,
  int inRepair = 2,
  int pending = 4,
  int finished = 1,
  int appointments = 3,
  int upcoming = 2,
  int overdue = 2,
  int lowStock = 5,
  int outOfStock = 2,
  int awaitingPayment = 1,
  int pendingMp = 1,
  bool withActivity = true,
  bool withCharts = true,
}) =>
    {
      'generatedAt': '2030-10-11T15:20:00.000Z',
      'orders': {'attendedLast30Days': attended, 'inRepair': inRepair, 'pending': pending, 'finishedAwaitingDelivery': finished},
      'appointments': {'upcoming': appointments},
      'maintenance': {'upcoming': upcoming, 'overdue': overdue},
      'inventory': {'lowStock': lowStock, 'outOfStock': outOfStock},
      'payments': {'ordersAwaitingPayment': awaitingPayment, 'pendingMercadoPago': pendingMp},
      'charts': !withCharts
          ? {'ordersByStatus': [], 'incomeByMonth': [], 'incomeByMethod': []}
          : {
        'ordersByStatus': [
          {'status': 'RECIBIDO', 'total': 1},
          {'status': 'DIAGNOSTICO', 'total': 0},
          {'status': 'EN_REPARACION', 'total': 2},
          {'status': 'ESPERANDO_REFACCION', 'total': 1},
          {'status': 'TERMINADO', 'total': 1},
          {'status': 'ENTREGADO', 'total': 4},
        ],
        'incomeByMonth': [
          {'month': '2030-05', 'total': 0},
          {'month': '2030-06', 'total': 1500},
          {'month': '2030-07', 'total': 0},
          {'month': '2030-08', 'total': 3200},
          {'month': '2030-09', 'total': 900},
          {'month': '2030-10', 'total': 2570},
        ],
        'incomeByMethod': [
          {'method': 'EFECTIVO', 'total': 3900},
          {'method': 'TARJETA', 'total': 0},
          {'method': 'TRANSFERENCIA', 'total': 1200},
          {'method': 'MERCADO_PAGO', 'total': 3070},
        ],
      },
      'recentActivity': {
        'orderChanges': withActivity
            ? [
                {'orderId': 12, 'folio': 'OS-000012', 'toStatus': 'TERMINADO', 'changedBy': 'Mario Mecánico', 'changedAt': '2030-10-11T15:00:00.000Z'},
              ]
            : [],
        'payments': withActivity
            ? [
                {'id': 7, 'orderFolio': 'OS-000012', 'amount': '1250.00', 'method': 'EFECTIVO', 'status': 'PAGADO', 'createdAt': '2030-10-11T15:05:00.000Z'},
              ]
            : [],
        'inventoryMovements': withActivity
            ? [
                {'id': 31, 'partCode': 'ACE-5W30', 'type': 'OUT', 'quantity': -4, 'createdAt': '2030-10-11T15:06:00.000Z'},
              ]
            : [],
      },
    };

FakeHandler dashboardHandler(Map<String, dynamic> Function() data) => (r) {
      if (r.method == 'GET' && r.path == '/dashboard') return ok(data());
      return null;
    };

String valueOf(WidgetTester tester, String label) => tester.widget<Text>(find.byKey(ValueKey('valor-$label'))).data!;

void main() {
  testWidgets('test_el_administrador_ve_las_tarjetas_con_los_valores_del_servidor', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(role: 'ADMIN', handler: dashboardHandler(() => dashboardJson()));
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Panel de control');

    final esperados = {
      'Vehículos atendidos': '6',
      'Vehículos en reparación': '2',
      'Órdenes pendientes': '4',
      'Terminadas por entregar': '1',
      'Citas próximas': '3',
      'Mantenimientos próximos': '2',
      'Mantenimientos vencidos': '2',
      'Refacciones con stock bajo': '5',
      'Refacciones agotadas': '2',
      'Órdenes terminadas por cobrar': '1',
      'Cobros de Mercado Pago pendientes': '1',
    };
    for (final entrada in esperados.entries) {
      expect(valueOf(tester, entrada.key), entrada.value, reason: entrada.key);
    }
    expect(find.text('Últimos 30 días'), findsOneWidget);
    expect(find.text('Próximos 7 días'), findsOneWidget);
    expect(find.textContaining('Actualizado'), findsOneWidget);
  });

  testWidgets('test_muestra_la_actividad_reciente', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(role: 'ADMIN', handler: dashboardHandler(() => dashboardJson()));
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Panel de control');
    await tester.scrollUntilVisible(find.text('Cambios de orden'), 200, scrollable: find.byType(Scrollable).last);

    expect(find.text('OS-000012 → Terminado'), findsOneWidget);
    expect(find.textContaining('Mario Mecánico ·'), findsOneWidget);
    expect(find.text('OS-000012 · Pagado'), findsOneWidget);
    expect(find.textContaining('Efectivo ·'), findsOneWidget);
    expect(find.text('ACE-5W30'), findsOneWidget);
    expect(find.textContaining('Salida ·'), findsOneWidget);
    expect(find.text('−4'), findsOneWidget);
  });

  testWidgets('test_actualizar_vuelve_a_consultar_y_refleja_los_cambios', (tester) async {
    useDesktopWindow(tester);
    var enReparacion = 2;
    final api = FakeApi(role: 'ADMIN', handler: dashboardHandler(() => dashboardJson(inRepair: enReparacion)));
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Panel de control');
    expect(valueOf(tester, 'Vehículos en reparación'), '2');

    enReparacion = 5;
    await tester.tap(find.byKey(const ValueKey('actualizar-panel')));
    await tester.pumpAndSettle();

    expect(valueOf(tester, 'Vehículos en reparación'), '5');
    expect(api.requests.where((r) => r.path == '/dashboard'), hasLength(2));
  });

  testWidgets('test_cada_tarjeta_lleva_al_listado_correspondiente', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(role: 'ADMIN', handler: ordersHandler(extra: dashboardHandler(() => dashboardJson())));
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Panel de control');

    await tester.scrollUntilVisible(find.text('Órdenes pendientes'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Órdenes pendientes'));
    await tester.pumpAndSettle();
    expect(find.text('Órdenes de servicio'), findsWidgets);

    await openSection(tester, 'Panel de control');
    await tester.scrollUntilVisible(find.text('Mantenimientos vencidos'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Mantenimientos vencidos'));
    await tester.pumpAndSettle();
    expect(find.text('Próximos y vencidos, para avisar al cliente'), findsOneWidget);

    await openSection(tester, 'Panel de control');
    await tester.scrollUntilVisible(find.text('Refacciones agotadas'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Refacciones agotadas'));
    await tester.pumpAndSettle();
    expect(find.text('Refacciones del taller y su existencia'), findsOneWidget);

    await openSection(tester, 'Panel de control');
    await tester.scrollUntilVisible(find.text('Órdenes terminadas por cobrar'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Órdenes terminadas por cobrar'));
    await tester.pumpAndSettle();
    expect(find.text('Cobros de las órdenes de servicio'), findsOneWidget);
  });

  testWidgets('test_un_taller_sin_datos_muestra_ceros_con_estado_vacio_y_sin_errores', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(
      role: 'ADMIN',
      handler: dashboardHandler(
        () => dashboardJson(
          attended: 0, inRepair: 0, pending: 0, finished: 0, appointments: 0, upcoming: 0, overdue: 0,
          lowStock: 0, outOfStock: 0, awaitingPayment: 0, pendingMp: 0, withActivity: false, withCharts: false,
        ),
      ),
    );
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Panel de control');

    expect(valueOf(tester, 'Vehículos atendidos'), '0');
    expect(find.text('Todavía no hay órdenes registradas.'), findsOneWidget);
    expect(find.text('Sin cobros en los últimos 6 meses.'), findsNWidgets(2));
    await tester.scrollUntilVisible(find.text('Sin cambios recientes.'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Sin cambios recientes.'), findsOneWidget);
    expect(find.text('Sin pagos recientes.'), findsOneWidget);
    expect(find.text('Sin movimientos recientes.'), findsOneWidget);
  });

  testWidgets('test_un_error_muestra_el_mensaje_y_permite_reintentar', (tester) async {
    useDesktopWindow(tester);
    var intentos = 0;
    final api = FakeApi(
      role: 'ADMIN',
      handler: (r) {
        if (r.method == 'GET' && r.path == '/dashboard') {
          intentos += 1;
          return intentos == 1 ? failure(500, 'INTERNAL_ERROR', 'No se pudo cargar el panel.') : ok(dashboardJson());
        }
        return null;
      },
    );
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Panel de control');

    expect(find.text('No se pudo cargar el panel.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(valueOf(tester, 'Vehículos atendidos'), '6');
  });

  testWidgets('test_si_falla_una_actualizacion_conserva_los_datos_y_avisa', (tester) async {
    useDesktopWindow(tester);
    var falla = false;
    final api = FakeApi(
      role: 'ADMIN',
      handler: (r) {
        if (r.method == 'GET' && r.path == '/dashboard') return falla ? failure(500, 'INTERNAL_ERROR', 'No se pudo actualizar el panel.') : ok(dashboardJson());
        return null;
      },
    );
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Panel de control');
    falla = true;

    await tester.tap(find.byKey(const ValueKey('actualizar-panel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('error-actualizar-panel')), findsOneWidget);
    expect(valueOf(tester, 'Vehículos atendidos'), '6');
  });

  for (final role in ['RECEPTIONIST', 'MECHANIC']) {
    testWidgets('test_el_rol_${role.toLowerCase()}_no_ve_la_seccion_panel_de_control', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: role, handler: dashboardHandler(() => dashboardJson()));
      await pumpAppSignedIn(tester, api);

      expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Panel de control')), findsNothing);
      expect(api.requests.where((r) => r.path == '/dashboard'), isEmpty);
    });
  }

  testWidgets('test_las_graficas_muestran_ordenes_por_estado_e_ingresos', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(role: 'ADMIN', handler: dashboardHandler(() => dashboardJson()));
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Panel de control');

    expect(find.text('Órdenes por estado'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('total-ordenes'))).data, '9');
    // La leyenda de la dona trae estado, cantidad y porcentaje (4 de 9 entregadas = 44 %).
    expect(find.text('Entregado'), findsOneWidget);
    expect(find.text('44%'), findsOneWidget);
    expect(find.text('Ingresos por mes'), findsOneWidget);
    expect(find.text('Oct'), findsOneWidget);
    expect(find.text('Ingresos por método de pago'), findsOneWidget);
    expect(find.text('Mercado Pago'), findsOneWidget);
    expect(find.text(r'$3,070.00'), findsOneWidget);
  });

  for (final width in [760.0, 1000.0, 1400.0, 1900.0]) {
    testWidgets('test_el_panel_se_ve_sin_desbordes_con_una_ventana_de_${width.toInt()}_px', (tester) async {
      useDesktopWindow(tester, width: width, height: 800);
      final api = FakeApi(role: 'ADMIN', handler: dashboardHandler(() => dashboardJson()));
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Panel de control');
      await tester.scrollUntilVisible(find.text('Movimientos de inventario'), 200, scrollable: find.byType(Scrollable).last);

      expect(tester.takeException(), isNull, reason: 'sin desbordes a $width px');
    });
  }

}
