import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

Map<String, dynamic> historyEntryJson(
  int orderId, {
  String problem = 'Ruido al frenar',
  String date = '2026-09-20T18:00:00.000Z',
  int mileage = 51000,
  Map<String, dynamic>? maintenance,
}) =>
    {
      'orderId': orderId,
      'folio': 'OS-${orderId.toString().padLeft(6, '0')}',
      'status': 'ENTREGADO',
      'serviceDate': date,
      'mileage': mileage,
      'reportedProblem': problem,
      'diagnosis': 'Balatas desgastadas',
      'services': [
        {'description': 'Cambio de balatas', 'amount': '850.00'},
      ],
      'labor': [
        {'description': 'Mano de obra frenos', 'amount': '400.00'},
      ],
      'parts': [
        {'partId': 4, 'code': 'BAL-DEL', 'name': 'Balatas delanteras', 'unit': 'juego', 'quantity': 1},
      ],
      'mechanic': {'id': 3, 'name': 'Mario Mecánico'},
      'maintenance': maintenance,
    };

Map<String, dynamic> maintenanceJson({String indicator = 'PROXIMO', String status = 'PENDIENTE'}) => {
      'id': 5,
      'description': 'Cambio de aceite y filtro',
      'dueDate': '2027-03-20',
      'dueMileage': 60000,
      'status': status,
      'indicator': status == 'PENDIENTE' ? indicator : null,
    };

FakeHandler historyHandler({FakeHandler? history}) {
  final base = vehiclesHandler(extra: (r) {
    if (r.method == 'GET' && r.path == '/vehicles/1') return ok(vehicleJson(1));
    if (r.method == 'GET' && r.path == '/vehicles/1/history') return history?.call(r);
    return null;
  });
  return base;
}

Future<void> openHistory(WidgetTester tester) async {
  await openSection(tester, 'Vehículos');
  await tester.tap(find.text('MNO-345-E'));
  await tester.pumpAndSettle();
}

void main() {
  for (final role in ['ADMIN', 'RECEPTIONIST', 'MECHANIC']) {
    testWidgets('test_el_rol_${role.toLowerCase()}_ve_el_historial_con_sus_servicios', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        role: role,
        handler: historyHandler(
          history: (_) => ok(
            {
              'vehicle': {'id': 1},
              'entries': [
                historyEntryJson(12, maintenance: maintenanceJson(indicator: 'NORMAL')),
                historyEntryJson(9, problem: 'Revisión general', date: '2026-03-01T10:00:00.000Z', mileage: 42000),
              ],
              'pendingMaintenance': maintenanceJson(),
            },
            meta: {'page': 1, 'pageSize': 20, 'total': 2},
          ),
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openHistory(tester);
      await tester.scrollUntilVisible(find.text('Historial de servicios'), 200, scrollable: find.byType(Scrollable).last);

      expect(find.text('Historial de servicios'), findsOneWidget);
      expect(find.text('OS-000012'), findsOneWidget);
      expect(find.text('OS-000009'), findsOneWidget);
      expect(find.textContaining('Cambio de balatas'), findsWidgets);
      expect(find.textContaining('Balatas delanteras'), findsWidgets);
      expect(find.textContaining('Mario Mecánico'), findsWidgets);
      expect(find.text('51,000 km'), findsOneWidget);
      expect(find.text('Próximo mantenimiento'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
    });
  }

  testWidgets('test_un_vehiculo_sin_servicios_terminados_muestra_el_estado_vacio', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(
      handler: historyHandler(
        history: (_) => ok({'vehicle': {'id': 1}, 'entries': [], 'pendingMaintenance': null},
            meta: {'page': 1, 'pageSize': 20, 'total': 0}),
      ),
    );
    await pumpAppSignedIn(tester, api);
    await openHistory(tester);
    await tester.scrollUntilVisible(find.text('Historial de servicios'), 200, scrollable: find.byType(Scrollable).last);

    expect(find.text('Este vehículo aún no tiene servicios terminados.'), findsOneWidget);
    expect(find.byKey(const ValueKey('mantenimiento-vigente')), findsNothing);
  });

  testWidgets('test_un_error_del_historial_se_muestra_y_permite_reintentar', (tester) async {
    useDesktopWindow(tester);
    var intentos = 0;
    final api = FakeApi(
      handler: historyHandler(
        history: (_) {
          intentos += 1;
          if (intentos == 1) return failure(500, 'INTERNAL_ERROR', 'No se pudo cargar el historial.');
          return ok({'vehicle': {'id': 1}, 'entries': [historyEntryJson(12)], 'pendingMaintenance': null},
              meta: {'page': 1, 'pageSize': 20, 'total': 1});
        },
      ),
    );
    await pumpAppSignedIn(tester, api);
    await openHistory(tester);
    await tester.scrollUntilVisible(find.text('Historial de servicios'), 200, scrollable: find.byType(Scrollable).last);

    expect(find.text('No se pudo cargar el historial.'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Reintentar'), 100, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('OS-000012'), findsOneWidget);
    expect(find.text('No se pudo cargar el historial.'), findsNothing);
  });

  testWidgets('test_cargar_mas_agrega_la_siguiente_pagina', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(
      handler: historyHandler(
        history: (r) {
          final page = int.parse(r.query['page'] ?? '1');
          return ok(
            {
              'vehicle': {'id': 1},
              'entries': [historyEntryJson(page == 1 ? 12 : 9, problem: page == 1 ? 'Primero' : 'Segundo')],
              'pendingMaintenance': null,
            },
            meta: {'page': page, 'pageSize': 1, 'total': 2},
          );
        },
      ),
    );
    await pumpAppSignedIn(tester, api);
    await openHistory(tester);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('historial-cargar-mas')), 200,
        scrollable: find.byType(Scrollable).last);

    await tester.tap(find.byKey(const ValueKey('historial-cargar-mas')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('OS-000009'), 200, scrollable: find.byType(Scrollable).last);

    expect(find.text('OS-000012'), findsOneWidget);
    expect(find.text('OS-000009'), findsOneWidget);
    expect(find.byKey(const ValueKey('historial-cargar-mas')), findsNothing);
  });
}
