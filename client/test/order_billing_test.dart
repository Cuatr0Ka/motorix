import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/billing_fake.dart';
import 'helpers/data.dart';
import 'helpers/fake_api.dart';

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(
        ['Continuar', 'Registrar pago', 'Entregar de todos modos', 'Confirmar', 'Cancelar cobro'].contains(label) ? FilledButton : OutlinedButton,
        label,
      ),
    );

Future<void> openOrder(WidgetTester tester, {String section = 'Órdenes'}) async {
  await openSection(tester, section);
  await tester.tap(find.text('OS-000001'));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).last);

Future<void> chargeWith(WidgetTester tester, String method, {String? reference}) async {
  await scrollTo(tester, find.byKey(const ValueKey('cobrar')));
  await tester.tap(find.byKey(const ValueKey('cobrar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('metodo-$method')));
  await tester.pumpAndSettle();
  if (reference != null) await tester.enterText(find.byKey(const ValueKey('referencia-pago')), reference);
  await tester.tap(find.byKey(const ValueKey('continuar-cobro')));
  await tester.pumpAndSettle();
}

void main() {
  group('sección de cobro', () {
    for (final role in ['RECEPTIONIST', 'ADMIN']) {
      testWidgets('test_el_rol_${role.toLowerCase()}_ve_el_total_el_estado_y_el_boton_cobrar', (tester) async {
        useDesktopWindow(tester);
        final api = FakeApi(role: role, handler: FakeBilledOrder().handler());
        await pumpAppSignedIn(tester, api);
        await openOrder(tester);
        await scrollTo(tester, find.byKey(const ValueKey('cobrar')));

        expect(find.text('Cobro'), findsOneWidget);
        expect(find.textContaining('\$1,250.00'), findsWidgets);
        expect(find.text('Sin cobrar'), findsOneWidget);
        expect(find.byKey(const ValueKey('cobrar')), findsOneWidget);
      });
    }

    testWidgets('test_el_mecanico_no_ve_la_seccion_de_cobro', (tester) async {
      useDesktopWindow(tester);
      final order = orderDetailJson(1, status: 'TERMINADO', mechanic: {'id': 3, 'name': 'Mario Mecánico'});
      final api = FakeApi(
        role: 'MECHANIC',
        handler: ordersHandler(
          items: [orderSummaryJson(1, status: 'TERMINADO', mechanic: {'id': 3, 'name': 'Mario Mecánico'})],
          extra: (r) => r.method == 'GET' && r.path == '/orders/1' ? ok(order) : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openOrder(tester, section: 'Mis órdenes');

      expect(find.text('Cobro'), findsNothing);
      expect(find.byKey(const ValueKey('cobrar')), findsNothing);
    });

    testWidgets('test_una_orden_en_reparacion_explica_por_que_no_se_puede_cobrar', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: FakeBilledOrder(status: 'EN_REPARACION').handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('motivo-sin-cobro')));

      expect(find.text('La orden debe estar Terminada para poder cobrarse.'), findsOneWidget);
      expect(find.byKey(const ValueKey('cobrar')), findsNothing);
    });

    testWidgets('test_una_orden_sin_importes_explica_que_no_hay_nada_que_cobrar', (tester) async {
      useDesktopWindow(tester);
      final order = FakeBilledOrder(total: '0.00');
      final api = FakeApi(
        handler: order.handler(
          extra: (r) => r.method == 'GET' && r.path == '/orders/1'
              ? ok(orderDetailJson(1, status: 'TERMINADO', mechanic: {'id': 3, 'name': 'Mario'}, billing: billingJson(total: '0.00', canCharge: false)))
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('motivo-sin-cobro')));

      expect(find.textContaining('no hay nada que cobrar'), findsOneWidget);
    });
  });

  group('cobrar en efectivo, tarjeta o transferencia', () {
    testWidgets('test_cobra_en_efectivo_con_confirmacion_y_queda_pagado', (tester) async {
      useDesktopWindow(tester);
      final order = FakeBilledOrder();
      final api = FakeApi(handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await chargeWith(tester, 'EFECTIVO');

      expect(find.text('Registrar pago'), findsWidgets);
      expect(find.textContaining('¿Confirmas el cobro de \$1,250.00 con Efectivo'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/orders/1/payments'), isEmpty);

      await tester.tap(dialogButton('Registrar pago'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/orders/1/payments');
      expect(post.body, {'method': 'EFECTIVO', 'amount': '1250.00'});
      expect(find.text('Pago registrado correctamente.'), findsOneWidget);
      await scrollTo(tester, find.byKey(const ValueKey('pago-1')));
      expect(find.textContaining('Efectivo · \$1,250.00'), findsOneWidget);
      expect(find.text('Pagado'), findsWidgets);
      expect(find.byKey(const ValueKey('cobrar')), findsNothing);
    });

    testWidgets('test_cancelar_la_confirmacion_no_llama_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: FakeBilledOrder().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await chargeWith(tester, 'TRANSFERENCIA');

      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/orders/1/payments'), isEmpty);
    });

    testWidgets('test_el_dialogo_nunca_pide_datos_de_tarjeta', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: FakeBilledOrder().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('cobrar')));
      await tester.tap(find.byKey(const ValueKey('cobrar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('metodo-TARJETA')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nunca captures el número de la tarjeta'), findsOneWidget);
      for (final prohibido in ['Número de tarjeta', 'Vencimiento', 'CVV', 'Código de seguridad', 'Titular']) {
        expect(find.textContaining(prohibido), findsNothing);
      }
      expect(find.byType(TextFormField), findsOneWidget);
    });

    for (final texto in ['4111111111111111', '4111 1111 1111 1111', '5555-5555-5555-4444']) {
      testWidgets('test_rechaza_la_referencia_con_numero_de_tarjeta_${texto.replaceAll(RegExp(r'\D'), '')}_sin_llamar_a_la_api', (tester) async {
        useDesktopWindow(tester);
        final api = FakeApi(handler: FakeBilledOrder().handler());
        await pumpAppSignedIn(tester, api);
        await openOrder(tester);
        await chargeWith(tester, 'TARJETA', reference: texto);

        expect(find.textContaining('Parece un número de tarjeta'), findsOneWidget);
        expect(find.text('Registrar pago'), findsNothing);
        expect(api.requests.where((r) => r.method == 'POST' && r.path == '/orders/1/payments'), isEmpty);
      });
    }

    testWidgets('test_acepta_un_folio_de_terminal_y_lo_envia_como_referencia', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: FakeBilledOrder().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await chargeWith(tester, 'TARJETA', reference: 'Folio 48213');
      await tester.tap(dialogButton('Registrar pago'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/orders/1/payments');
      expect(post.body['reference'], 'Folio 48213');
      expect(post.body['method'], 'TARJETA');
    });

    testWidgets('test_mercado_pago_aparece_deshabilitado_con_su_leyenda_si_no_esta_configurado', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: FakeBilledOrder(mercadoPagoAvailable: false).handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('cobrar')));
      await tester.tap(find.byKey(const ValueKey('cobrar')));
      await tester.pumpAndSettle();

      expect(find.text('Mercado Pago no está configurado en este entorno.'), findsOneWidget);
      final mp = tester.widget<RadioListTile<Object?>>(find.byKey(const ValueKey('metodo-MERCADO_PAGO')));
      expect(mp.enabled, isFalse);
      final efectivo = tester.widget<RadioListTile<Object?>>(find.byKey(const ValueKey('metodo-EFECTIVO')));
      expect(efectivo.enabled, isTrue);
    });

    testWidgets('test_un_pago_existente_se_muestra_como_error_del_servidor', (tester) async {
      useDesktopWindow(tester);
      final order = FakeBilledOrder();
      final api = FakeApi(handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      // Otra persona cobró la orden mientras esta pantalla seguía abierta.
      order.payments.add(paymentJson(9));
      await chargeWith(tester, 'EFECTIVO');
      await tester.tap(dialogButton('Registrar pago'));
      await tester.pumpAndSettle();

      expect(find.text('La orden ya tiene un pago registrado.'), findsOneWidget);
    });

    testWidgets('test_muestra_el_aviso_si_el_total_cambio_despues_del_cobro', (tester) async {
      useDesktopWindow(tester);
      final order = FakeBilledOrder();
      order.payments.add(paymentJson(1));
      final api = FakeApi(
        handler: order.handler(
          extra: (r) => r.method == 'GET' && r.path == '/orders/1'
              ? ok(orderDetailJson(1, status: 'TERMINADO', mechanic: {'id': 3, 'name': 'Mario'}, billing: billingJson(total: '1350.00', payments: [paymentJson(1)], amountOutdated: true)))
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('importe-desactualizado')));

      expect(find.textContaining('El total cambió después del cobro'), findsOneWidget);
      expect(find.textContaining('\$1,350.00'), findsWidgets);
    });
  });

  group('entregar una orden sin cobrar', () {
    Future<void> pressDeliver(WidgetTester tester) async {
      await scrollTo(tester, find.byKey(const ValueKey('cambiar-estado-ENTREGADO')));
      await tester.tap(find.byKey(const ValueKey('cambiar-estado-ENTREGADO')));
      await tester.pumpAndSettle();
    }

    testWidgets('test_advierte_y_cancelar_no_cambia_el_estado', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: FakeBilledOrder().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await pressDeliver(tester);

      expect(find.text('La orden no está cobrada'), findsOneWidget);
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/orders/1/status'), isEmpty);
    });

    testWidgets('test_con_la_advertencia_y_la_confirmacion_de_entrega_la_orden_se_entrega', (tester) async {
      useDesktopWindow(tester);
      final order = FakeBilledOrder();
      final api = FakeApi(handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await pressDeliver(tester);

      await tester.tap(dialogButton('Entregar de todos modos'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar entrega'), findsWidgets);
      await tester.tap(dialogButton('Confirmar'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/orders/1/status'), hasLength(1));
      expect(order.status, 'ENTREGADO');
    });

    testWidgets('test_una_orden_cobrada_se_entrega_sin_la_advertencia', (tester) async {
      useDesktopWindow(tester);
      final order = FakeBilledOrder();
      order.payments.add(paymentJson(1));
      final api = FakeApi(handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await pressDeliver(tester);

      expect(find.text('La orden no está cobrada'), findsNothing);
      expect(find.text('Registrar entrega'), findsWidgets);
    });
  });
}
