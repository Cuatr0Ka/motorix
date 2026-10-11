import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

Map<String, dynamic> maintenanceRow(
  int id, {
  String description = 'Cambio de aceite',
  String indicator = 'NORMAL',
  String status = 'PENDIENTE',
  String client = 'Ana Morales',
  String phone = '5512345678',
  String plate = 'MNO-345-E',
  String? dueDate = '2031-03-20',
  int? dueMileage = 60000,
}) =>
    {
      'id': id,
      'description': description,
      'dueDate': dueDate,
      'dueMileage': dueMileage,
      'status': status,
      'indicator': status == 'PENDIENTE' ? indicator : null,
      'attendedAt': null,
      'orderId': 1,
      'orderFolio': 'OS-000001',
      'vehicle': {'id': 1, 'brand': 'Honda', 'model': 'Civic', 'licensePlate': plate, 'currentMileage': 51200},
      'client': {'id': 1, 'name': client, 'phone': phone},
    };

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(['Confirmar', 'Guardar'].contains(label) ? FilledButton : OutlinedButton, label),
    );

/// Lista simulada que filtra por indicador y búsqueda, y cambia con las ediciones.
class FakeMaintenance {
  FakeMaintenance() {
    rows = [
      maintenanceRow(1, description: 'Servicio vencido', indicator: 'VENCIDO', client: 'Luis Pérez', plate: 'DEF-456-B', dueDate: '2026-01-10'),
      maintenanceRow(2, description: 'Servicio próximo', indicator: 'PROXIMO', dueDate: '2030-10-20'),
      maintenanceRow(3, description: 'Servicio normal', indicator: 'NORMAL'),
    ];
  }

  late List<Map<String, dynamic>> rows;

  FakeHandler handler() => vehiclesHandler(extra: (r) {
        if (r.method == 'GET' && r.path == '/maintenance') {
          final indicator = r.query['indicator'];
          final search = (r.query['search'] ?? '').toLowerCase();
          final list = rows.where((m) {
            if (m['status'] != 'PENDIENTE') return false;
            if (indicator != null && m['indicator'] != indicator) return false;
            if (search.isNotEmpty &&
                !('${(m['client'] as Map)['name']}'.toLowerCase().contains(search) ||
                    '${(m['vehicle'] as Map)['licensePlate']}'.toLowerCase().contains(search))) {
              return false;
            }
            return true;
          }).toList();
          return ok(list, meta: {'page': 1, 'pageSize': 20, 'total': list.length});
        }
        final match = RegExp(r'^/maintenance/(\d+)(/attend)?$').firstMatch(r.path);
        if (match != null) {
          final index = rows.indexWhere((m) => m['id'] == int.parse(match.group(1)!));
          if (match.group(2) != null) {
            rows[index] = {...rows[index], 'status': 'ATENDIDO', 'indicator': null};
            return ok(rows[index]);
          }
          if (r.method == 'PATCH') {
            rows[index] = {...rows[index], 'description': r.body['description']};
            return ok(rows[index]);
          }
        }
        if (r.method == 'GET' && r.path == '/vehicles/1') return ok(vehicleJson(1));
        return null;
      });
}

void main() {
  for (final role in ['ADMIN', 'RECEPTIONIST']) {
    testWidgets('test_el_rol_${role.toLowerCase()}_ve_los_tres_indicadores_con_cliente_y_telefono', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: role, handler: FakeMaintenance().handler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Mantenimientos');

      expect(find.text('Vencido'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Luis Pérez'), findsOneWidget);
      expect(find.text('5512345678'), findsWidgets);
      expect(find.text('DEF-456-B · Honda Civic'), findsOneWidget);
      expect(find.text('Servicio vencido'), findsOneWidget);
    });
  }

  testWidgets('test_filtra_por_indicador_y_limpia_el_filtro', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(role: 'RECEPTIONIST', handler: FakeMaintenance().handler());
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Mantenimientos');

    await tester.tap(find.byKey(const ValueKey('filtro-indicador')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vencido').last);
    await tester.pumpAndSettle();

    expect(api.requests.any((r) => r.path == '/maintenance' && r.query['indicator'] == 'VENCIDO'), isTrue);
    expect(find.text('Servicio vencido'), findsOneWidget);
    expect(find.text('Servicio normal'), findsNothing);

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Servicio normal'), findsOneWidget);
  });

  testWidgets('test_busca_por_cliente_o_placa', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(role: 'RECEPTIONIST', handler: FakeMaintenance().handler());
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Mantenimientos');

    await tester.enterText(find.byType(TextField).first, 'DEF-456');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Servicio vencido'), findsOneWidget);
    expect(find.text('Servicio normal'), findsNothing);
  });

  testWidgets('test_sin_mantenimientos_muestra_el_estado_vacio', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(
      role: 'RECEPTIONIST',
      handler: (r) => r.path == '/maintenance' ? ok([], meta: {'page': 1, 'pageSize': 20, 'total': 0}) : null,
    );
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Mantenimientos');

    expect(find.text('Sin mantenimientos pendientes.'), findsOneWidget);
  });

  testWidgets('test_un_error_del_servidor_muestra_el_mensaje_y_reintentar', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(
      role: 'ADMIN',
      handler: (r) => r.path == '/maintenance' ? failure(500, 'INTERNAL_ERROR', 'No se pudo cargar los mantenimientos.') : null,
    );
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Mantenimientos');

    expect(find.text('No se pudo cargar los mantenimientos.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('test_el_mecanico_no_ve_la_seccion_mantenimientos', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(role: 'MECHANIC', handler: FakeMaintenance().handler());
    await pumpAppSignedIn(tester, api);

    expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Mantenimientos')), findsNothing);
  });

  testWidgets('test_la_recepcion_no_tiene_acciones_de_edicion', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(role: 'RECEPTIONIST', handler: FakeMaintenance().handler());
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Mantenimientos');

    expect(find.byKey(const ValueKey('editar-mantenimiento-1')), findsNothing);
    expect(find.byKey(const ValueKey('atender-mantenimiento-1')), findsNothing);
  });

  testWidgets('test_el_administrador_edita_y_marca_como_atendido_con_confirmacion', (tester) async {
    useDesktopWindow(tester);
    final data = FakeMaintenance();
    final api = FakeApi(role: 'ADMIN', handler: data.handler());
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Mantenimientos');

    await tester.tap(find.byKey(const ValueKey('editar-mantenimiento-3')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mantenimiento-descripcion')), 'Servicio ajustado');
    await tester.tap(dialogButton('Guardar'));
    await tester.pumpAndSettle();

    final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/maintenance/3');
    expect(patch.body['description'], 'Servicio ajustado');
    expect(find.text('Servicio ajustado'), findsOneWidget);
    expect(find.text('Mantenimiento actualizado correctamente.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('atender-mantenimiento-3')));
    await tester.pumpAndSettle();
    await tester.tap(dialogButton('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.requests.where((r) => r.path == '/maintenance/3/attend'), isEmpty);

    await tester.tap(find.byKey(const ValueKey('atender-mantenimiento-3')));
    await tester.pumpAndSettle();
    await tester.tap(dialogButton('Confirmar'));
    await tester.pumpAndSettle();

    expect(api.requests.where((r) => r.method == 'POST' && r.path == '/maintenance/3/attend'), hasLength(1));
    expect(find.text('Servicio ajustado'), findsNothing);
    expect(find.text('Mantenimiento marcado como atendido.'), findsOneWidget);
  });
}
