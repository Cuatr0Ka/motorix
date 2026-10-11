import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(label == 'Confirmar' ? FilledButton : OutlinedButton, label),
    );

Future<void> openOrder(WidgetTester tester, String folio) async {
  await openSection(tester, 'Órdenes');
  await tester.tap(find.text(folio));
  await tester.pumpAndSettle();
}

Future<void> chooseMechanicInDialog(WidgetTester tester, String name) async {
  await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(DropdownButtonFormField<int?>)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  group('asignar un mecánico desde el detalle de la orden', () {
    testWidgets('test_asigna_un_mecanico_a_una_orden_sin_asignar_y_avisa', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: ordersHandler(
          items: [orderSummaryJson(1)],
          extra: (r) => r.method == 'PUT' && r.path == '/orders/1/mechanic'
              ? ok(orderDetailJson(1, mechanic: {'id': 3, 'name': 'Mario Mecánico'}))
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openOrder(tester, 'OS-000001');

      expect(find.text('Sin asignar'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('asignar-mecanico')));
      await tester.pumpAndSettle();
      expect(find.text('Asignar mecánico'), findsWidgets);
      // Sin cambios no se puede confirmar.
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirmar')).onPressed, isNull);

      await chooseMechanicInDialog(tester, 'Mario Mecánico');
      await tester.tap(dialogButton('Confirmar'));
      await tester.pumpAndSettle();

      final put = api.requests.firstWhere((r) => r.method == 'PUT' && r.path == '/orders/1/mechanic');
      expect(put.body, {'mechanicId': 3});
      expect(find.text('Mecánico asignado correctamente.'), findsOneWidget);
      expect(find.text('Mario Mecánico'), findsWidgets);
    });

    testWidgets('test_reasigna_una_orden_ya_asignada', (tester) async {
      useDesktopWindow(tester);
      final asignada = {'id': 3, 'name': 'Mario Mecánico'};
      final api = FakeApi(
        handler: ordersHandler(
          items: [orderSummaryJson(2, status: 'DIAGNOSTICO', mechanic: asignada)],
          extra: (r) => r.method == 'PUT' && r.path == '/orders/2/mechanic'
              ? ok(orderDetailJson(2, status: 'DIAGNOSTICO', mechanic: {'id': 4, 'name': 'Marta Mecánica'}))
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openOrder(tester, 'OS-000002');

      expect(find.text('Reasignar mecánico'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('asignar-mecanico')));
      await tester.pumpAndSettle();
      await chooseMechanicInDialog(tester, 'Marta Mecánica');
      await tester.tap(dialogButton('Confirmar'));
      await tester.pumpAndSettle();

      expect(api.requests.firstWhere((r) => r.method == 'PUT').body, {'mechanicId': 4});
      expect(find.text('Marta Mecánica'), findsWidgets);
    });

    testWidgets('test_muestra_el_error_del_servidor_si_la_asignacion_se_rechaza', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: ordersHandler(
          items: [orderSummaryJson(1)],
          extra: (r) => r.method == 'PUT' && r.path == '/orders/1/mechanic'
              ? failure(422, 'MECHANIC_INVALID', 'El mecánico seleccionado no existe, está inactivo o no tiene el rol de mecánico.')
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openOrder(tester, 'OS-000001');

      await tester.tap(find.byKey(const ValueKey('asignar-mecanico')));
      await tester.pumpAndSettle();
      await chooseMechanicInDialog(tester, 'Mario Mecánico');
      await tester.tap(dialogButton('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('está inactivo o no tiene el rol de mecánico'), findsOneWidget);
    });

    testWidgets('test_las_ordenes_terminadas_o_entregadas_no_ofrecen_asignar', (tester) async {
      useDesktopWindow(tester);
      for (final status in ['TERMINADO', 'ENTREGADO']) {
        final api = FakeApi(
          handler: ordersHandler(
            items: [orderSummaryJson(5, status: status, mechanic: {'id': 3, 'name': 'Mario Mecánico'})],
          ),
        );
        await pumpAppSignedIn(tester, api);
        await openOrder(tester, 'OS-000005');

        expect(find.byKey(const ValueKey('asignar-mecanico')), findsNothing, reason: status);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('test_el_administrador_tambien_ve_la_opcion_de_asignar', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: ordersHandler(items: [orderSummaryJson(1)])));
      await openOrder(tester, 'OS-000001');

      expect(find.byKey(const ValueKey('asignar-mecanico')), findsOneWidget);
    });
  });

  group('selector de mecánico en el formulario y filtro del listado', () {
    testWidgets('test_la_nueva_orden_envia_el_mecanico_elegido', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: ordersHandler(
          extra: (r) => r.method == 'POST' && r.path == '/orders' ? created(orderDetailJson(7)) : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Órdenes');
      await tester.tap(find.text('Nueva orden'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vehículo *'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vehiculo-opcion-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Kilometraje de entrada *'), '52000');
      await tester.enterText(find.widgetWithText(TextFormField, 'Problema reportado *'), 'Ruido');
      await tester.tap(find.widgetWithText(DropdownButtonFormField<int?>, 'Mecánico (opcional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marta Mecánica').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/orders');
      expect(post.body['mechanicId'], 4);
    });

    testWidgets('test_el_filtro_por_mecanico_pide_solo_sus_ordenes', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: ordersHandler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Órdenes');

      await tester.tap(find.byKey(const ValueKey('filtro-mecanico-orden')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mario Mecánico').last);
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.path == '/orders').last.query['mechanicId'], '3');
    });
  });
}
