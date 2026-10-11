import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

/// Listado de pagos simulado: filtra por estado, método y búsqueda, y actualiza los cobros pendientes.
class FakePayments {
  FakePayments() {
    rows = [
      paymentJson(1, orderId: 11, method: 'EFECTIVO', status: 'PAGADO', clientName: 'Ana Morales', plate: 'AAA-111-A'),
      paymentJson(2, orderId: 12, method: 'TARJETA', status: 'PAGADO', amount: '800.00', clientName: 'Luis Pérez', plate: 'BBB-222-B'),
      paymentJson(3, orderId: 13, method: 'TRANSFERENCIA', status: 'PAGADO', amount: '950.50', clientName: 'Rosa Gómez', plate: 'CCC-333-C'),
      paymentJson(4, orderId: 14, method: 'MERCADO_PAGO', status: 'PENDIENTE', amount: '600.00', clientName: 'Omar Díaz', plate: 'DDD-444-D', checkoutUrl: 'https://sandbox.simulado/pay/4'),
      paymentJson(5, orderId: 15, method: 'MERCADO_PAGO', status: 'RECHAZADO', amount: '450.00', clientName: 'Eva Ruiz', plate: 'EEE-555-E'),
      paymentJson(6, orderId: 16, method: 'MERCADO_PAGO', status: 'CANCELADO', amount: '300.00', clientName: 'Hugo Soto', plate: 'FFF-666-F'),
    ];
  }

  late List<Map<String, dynamic>> rows;
  String providerState = 'approved';

  FakeHandler handler() => vehiclesHandler(extra: (r) {
        if (r.method == 'GET' && r.path == '/payments') {
          final search = (r.query['search'] ?? '').toLowerCase();
          final list = rows.where((p) {
            if (r.query['status'] != null && p['status'] != r.query['status']) return false;
            if (r.query['method'] != null && p['method'] != r.query['method']) return false;
            if (search.isNotEmpty &&
                !('${(p['client'] as Map)['name']}'.toLowerCase().contains(search) ||
                    '${(p['vehicle'] as Map)['licensePlate']}'.toLowerCase().contains(search) ||
                    '${p['orderFolio']}'.toLowerCase().contains(search))) {
              return false;
            }
            return true;
          }).toList();
          return ok(list, meta: {'page': 1, 'pageSize': 20, 'total': list.length});
        }
        final refresh = RegExp(r'^/payments/(\d+)/refresh$').firstMatch(r.path);
        if (r.method == 'POST' && refresh != null) {
          final index = rows.indexWhere((p) => p['id'] == int.parse(refresh.group(1)!));
          rows[index] = {...rows[index], 'status': providerState == 'approved' ? 'PAGADO' : 'PENDIENTE', 'paidAt': '2030-10-11T16:00:00.000Z'};
          return ok(rows[index]);
        }
        return null;
      });
}

void main() {
  for (final role in ['ADMIN', 'RECEPTIONIST']) {
    testWidgets('test_el_rol_${role.toLowerCase()}_ve_los_pagos_con_los_cuatro_estados_y_metodos', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: role, handler: FakePayments().handler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Pagos');

      expect(find.text('Pagado'), findsNWidgets(3));
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Rechazado'), findsOneWidget);
      expect(find.text('Cancelado'), findsOneWidget);
      for (final metodo in ['Efectivo', 'Tarjeta', 'Transferencia', 'Mercado Pago']) {
        expect(find.text(metodo), findsWidgets);
      }
      expect(find.text('OS-000011'), findsOneWidget);
      expect(find.text('\$950.50'), findsOneWidget);
    });
  }

  testWidgets('test_busca_por_cliente_placa_o_folio', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(handler: FakePayments().handler());
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Pagos');

    await tester.enterText(find.byType(TextField).first, 'BBB-222');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Luis Pérez'), findsOneWidget);
    expect(find.text('Ana Morales'), findsNothing);
  });

  testWidgets('test_filtra_por_estado_y_por_metodo_y_limpia_los_filtros', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(handler: FakePayments().handler());
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Pagos');

    await tester.tap(find.byKey(const ValueKey('filtro-estado-pago')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rechazado').last);
    await tester.pumpAndSettle();
    expect(api.requests.any((r) => r.path == '/payments' && r.query['status'] == 'RECHAZADO'), isTrue);
    expect(find.text('Eva Ruiz'), findsOneWidget);
    expect(find.text('Ana Morales'), findsNothing);

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filtro-metodo-pago')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transferencia').last);
    await tester.pumpAndSettle();
    expect(api.requests.any((r) => r.path == '/payments' && r.query['method'] == 'TRANSFERENCIA'), isTrue);
    expect(find.text('Rosa Gómez'), findsOneWidget);
    expect(find.text('Luis Pérez'), findsNothing);
  });

  testWidgets('test_actualiza_el_estado_de_un_cobro_pendiente_de_mercado_pago_desde_el_listado', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(handler: FakePayments().handler());
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Pagos');

    expect(find.byKey(const ValueKey('actualizar-pago-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('actualizar-pago-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('actualizar-pago-4')));
    await tester.pumpAndSettle();

    expect(api.requests.where((r) => r.method == 'POST' && r.path == '/payments/4/refresh'), hasLength(1));
    expect(find.text('Estado del cobro actualizado.'), findsOneWidget);
    expect(find.byKey(const ValueKey('actualizar-pago-4')), findsNothing);
  });

  testWidgets('test_sin_pagos_muestra_el_estado_vacio', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(handler: (r) => r.path == '/payments' ? ok([], meta: {'page': 1, 'pageSize': 20, 'total': 0}) : null);
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Pagos');

    expect(find.text('Todavía no hay pagos registrados.'), findsOneWidget);
  });

  testWidgets('test_un_error_del_servidor_muestra_el_mensaje_y_reintentar', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(handler: (r) => r.path == '/payments' ? failure(500, 'INTERNAL_ERROR', 'No se pudieron cargar los pagos.') : null);
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Pagos');

    expect(find.text('No se pudieron cargar los pagos.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('test_el_mecanico_no_ve_la_seccion_pagos', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(role: 'MECHANIC', handler: FakePayments().handler());
    await pumpAppSignedIn(tester, api);

    expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Pagos')), findsNothing);
  });
}
