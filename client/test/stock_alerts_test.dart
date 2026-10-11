import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';
import 'inventory_screens_test.dart' show FakeInventory, partJson;

/// Inventario simulado que además atiende `GET /parts/alerts` calculando las alertas desde las refacciones.
class FakeInventoryWithAlerts extends FakeInventory {
  int alertRequests = 0;

  Map<String, dynamic> alertsJson() {
    final items = parts.where((p) => p['active'] == true && (p['stock'] as int) <= (p['minStock'] as int)).toList()
      ..sort((a, b) => ((a['stock'] == 0) ? 0 : 1).compareTo((b['stock'] == 0) ? 0 : 1));
    return {
      'count': items.length,
      'outOfStock': items.where((p) => p['stock'] == 0).length,
      'items': items,
    };
  }

  @override
  FakeHandler handler() {
    final base = super.handler();
    return (r) {
      if (r.method == 'GET' && r.path == '/parts/alerts') {
        alertRequests += 1;
        return ok(alertsJson());
      }
      return base(r);
    };
  }
}

void main() {
  testWidgets('test_el_administrador_ve_la_insignia_y_el_aviso_en_el_inicio', (tester) async {
    useDesktopWindow(tester);
    final inventory = FakeInventoryWithAlerts();
    final api = FakeApi(role: 'ADMIN', handler: inventory.handler());
    await pumpAppSignedIn(tester, api);

    expect(find.byKey(const ValueKey('insignia-alertas')), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.byKey(const ValueKey('aviso-stock-bajo')), findsOneWidget);
    expect(find.text('2 refacciones con stock bajo, 1 agotada'), findsOneWidget);
    expect(inventory.alertRequests, greaterThanOrEqualTo(1));
  });

  testWidgets('test_el_aviso_del_inicio_lleva_al_inventario', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(role: 'ADMIN', handler: FakeInventoryWithAlerts().handler());
    await pumpAppSignedIn(tester, api);

    await tester.tap(find.byKey(const ValueKey('aviso-stock-bajo')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('resumen-alertas')), findsOneWidget);
  });

  testWidgets('test_el_banner_muestra_el_conteo_y_la_lista_con_stock_y_minimo', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(role: 'ADMIN', handler: FakeInventoryWithAlerts().handler());
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Inventario');

    expect(find.text('2 refacciones con stock bajo, 1 agotada'), findsOneWidget);
    expect(find.byKey(const ValueKey('alerta-3')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ver-alertas')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('alerta-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('alerta-2')), findsOneWidget);
    expect(find.text('Stock 0 · mínimo 2'), findsOneWidget);
    expect(find.text('Stock 2 · mínimo 5'), findsOneWidget);
    // La agotada va primero y se distingue de la de stock bajo.
    final agotada = tester.getTopLeft(find.byKey(const ValueKey('alerta-3'))).dy;
    final baja = tester.getTopLeft(find.byKey(const ValueKey('alerta-2'))).dy;
    expect(agotada, lessThan(baja));

    await tester.tap(find.byKey(const ValueKey('ver-alertas')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('alerta-3')), findsNothing);
  });

  testWidgets('test_sin_alertas_el_banner_indica_que_el_inventario_esta_en_orden', (tester) async {
    useDesktopWindow(tester);
    final inventory = FakeInventoryWithAlerts();
    inventory.parts = [partJson(1, stock: 50, minStock: 3)];
    final api = FakeApi(role: 'ADMIN', handler: inventory.handler());
    await pumpAppSignedIn(tester, api);

    expect(find.byKey(const ValueKey('aviso-stock-bajo')), findsNothing);
    expect(find.byKey(const ValueKey('insignia-alertas')), findsNothing);

    await openSection(tester, 'Inventario');

    expect(find.byKey(const ValueKey('inventario-en-orden')), findsOneWidget);
  });

  testWidgets('test_una_entrada_que_supera_el_minimo_quita_la_alerta', (tester) async {
    useDesktopWindow(tester);
    final inventory = FakeInventoryWithAlerts();
    final api = FakeApi(role: 'ADMIN', handler: inventory.handler());
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Inventario');
    expect(find.text('2 refacciones con stock bajo, 1 agotada'), findsOneWidget);

    // La agotada (Correa, id 3) recibe una entrada de 10 unidades desde su detalle.
    await tester.tap(find.text('COR-003'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('registrar-entrada')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('entrada-cantidad')), '10');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Guardar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('1 refacción con stock bajo'), findsOneWidget);
    expect(find.text('2 refacciones con stock bajo, 1 agotada'), findsNothing);
  });

  for (final role in ['RECEPTIONIST', 'MECHANIC']) {
    testWidgets('test_el_rol_${role.toLowerCase()}_no_consulta_ni_ve_alertas', (tester) async {
      useDesktopWindow(tester);
      final inventory = FakeInventoryWithAlerts();
      final api = FakeApi(role: role, handler: inventory.handler());
      await pumpAppSignedIn(tester, api);

      expect(find.byKey(const ValueKey('insignia-alertas')), findsNothing);
      expect(find.byKey(const ValueKey('aviso-stock-bajo')), findsNothing);
      expect(api.requests.where((r) => r.path == '/parts/alerts'), isEmpty);
    });
  }

  testWidgets('test_un_error_al_consultar_las_alertas_se_muestra_con_reintentar', (tester) async {
    useDesktopWindow(tester);
    final inventory = FakeInventoryWithAlerts();
    final base = inventory.handler();
    final api = FakeApi(
      role: 'ADMIN',
      handler: (r) => r.path == '/parts/alerts' ? failure(500, 'INTERNAL_ERROR', 'No se pudieron consultar las alertas.') : base(r),
    );
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Inventario');

    expect(find.text('No se pudieron consultar las alertas.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
