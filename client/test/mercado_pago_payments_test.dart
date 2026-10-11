import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/billing_fake.dart';
import 'helpers/data.dart';
import 'helpers/fake_api.dart';

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(
        ['Continuar', 'Registrar pago', 'Cancelar cobro', 'Confirmar'].contains(label) ? FilledButton : OutlinedButton,
        label,
      ),
    );

Future<void> openOrder(WidgetTester tester) async {
  await openSection(tester, 'Órdenes');
  await tester.tap(find.text('OS-000001'));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).last);

/// Cobra con Mercado Pago hasta que el pago pendiente aparece en la orden.
Future<void> chargeMercadoPago(WidgetTester tester) async {
  await scrollTo(tester, find.byKey(const ValueKey('cobrar')));
  await tester.tap(find.byKey(const ValueKey('cobrar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('metodo-MERCADO_PAGO')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('referencia-pago')), findsNothing);
  await tester.tap(find.byKey(const ValueKey('continuar-cobro')));
  await tester.pumpAndSettle();
  expect(find.textContaining('Se creará un enlace de cobro de Mercado Pago'), findsOneWidget);
  await tester.tap(dialogButton('Registrar pago'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('test_cobrar_con_mercado_pago_muestra_el_cobro_pendiente_con_su_enlace', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(handler: FakeBilledOrder().handler());
    await pumpAppSignedIn(tester, api);
    await openOrder(tester);
    await chargeMercadoPago(tester);

    final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/orders/1/payments');
    expect(post.body['method'], 'MERCADO_PAGO');
    expect(post.body.containsKey('reference'), isFalse);
    expect(find.text('Cobro creado: comparte el enlace con el cliente.'), findsOneWidget);
    await scrollTo(tester, find.byKey(const ValueKey('enlace-1')));
    expect(find.text('https://sandbox.mercadopago.simulado/pay/1'), findsOneWidget);
    expect(find.text('Cobro pendiente'), findsOneWidget);
    expect(find.byKey(const ValueKey('copiar-enlace-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('abrir-enlace-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('actualizar-pago-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('cancelar-pago-1')), findsOneWidget);
  });

  testWidgets('test_copia_el_enlace_al_portapapeles_y_lo_abre_en_el_navegador', (tester) async {
    useDesktopWindow(tester);
    String? copiado;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copiado = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final opener = FakeLinkOpener();
    final api = FakeApi(handler: FakeBilledOrder().handler());
    await pumpAppSignedIn(tester, api, linkOpener: opener);
    await openOrder(tester);
    await chargeMercadoPago(tester);
    await scrollTo(tester, find.byKey(const ValueKey('copiar-enlace-1')));

    await tester.tap(find.byKey(const ValueKey('copiar-enlace-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('abrir-enlace-1')));
    await tester.pumpAndSettle();

    expect(copiado, 'https://sandbox.mercadopago.simulado/pay/1');
    expect(find.text('Enlace de cobro copiado.'), findsOneWidget);
    expect(opener.opened, ['https://sandbox.mercadopago.simulado/pay/1']);
  });

  testWidgets('test_si_no_se_puede_abrir_el_enlace_avisa_y_sugiere_copiarlo', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(handler: FakeBilledOrder().handler());
    await pumpAppSignedIn(tester, api, linkOpener: FakeLinkOpener(succeeds: false));
    await openOrder(tester);
    await chargeMercadoPago(tester);
    await scrollTo(tester, find.byKey(const ValueKey('abrir-enlace-1')));

    await tester.tap(find.byKey(const ValueKey('abrir-enlace-1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo abrir el enlace de cobro'), findsOneWidget);
  });

  testWidgets('test_actualizar_el_estado_pasa_de_pendiente_a_pagado_y_aparece_la_operacion', (tester) async {
    useDesktopWindow(tester);
    final order = FakeBilledOrder();
    final api = FakeApi(handler: order.handler());
    await pumpAppSignedIn(tester, api);
    await openOrder(tester);
    await chargeMercadoPago(tester);
    order.providerState = 'approved';
    await scrollTo(tester, find.byKey(const ValueKey('actualizar-pago-1')));

    await tester.tap(find.byKey(const ValueKey('actualizar-pago-1')));
    await tester.pumpAndSettle();

    expect(api.requests.where((r) => r.method == 'POST' && r.path == '/payments/1/refresh'), hasLength(1));
    expect(find.text('Estado del cobro actualizado.'), findsOneWidget);
    await scrollTo(tester, find.textContaining('Operación de Mercado Pago: 987654'));
    expect(find.textContaining('Operación de Mercado Pago: 987654'), findsOneWidget);
    expect(find.byKey(const ValueKey('actualizar-pago-1')), findsNothing);
  });

  testWidgets('test_si_el_proveedor_aun_no_confirma_sigue_pendiente_y_muestra_la_ultima_consulta', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(handler: FakeBilledOrder().handler());
    await pumpAppSignedIn(tester, api);
    await openOrder(tester);
    await chargeMercadoPago(tester);
    await scrollTo(tester, find.byKey(const ValueKey('actualizar-pago-1')));

    await tester.tap(find.byKey(const ValueKey('actualizar-pago-1')));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.textContaining('Última consulta:'));
    expect(find.textContaining('Última consulta:'), findsOneWidget);
    expect(find.text('Cobro pendiente'), findsOneWidget);
  });

  testWidgets('test_un_cobro_rechazado_se_conserva_y_permite_cobrar_de_nuevo', (tester) async {
    useDesktopWindow(tester);
    final order = FakeBilledOrder();
    final api = FakeApi(handler: order.handler());
    await pumpAppSignedIn(tester, api);
    await openOrder(tester);
    await chargeMercadoPago(tester);
    order.providerState = 'rejected';
    await scrollTo(tester, find.byKey(const ValueKey('actualizar-pago-1')));
    await tester.tap(find.byKey(const ValueKey('actualizar-pago-1')));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byKey(const ValueKey('pago-1')));
    expect(find.text('Rechazado'), findsOneWidget);
    expect(find.byKey(const ValueKey('cobrar')), findsOneWidget);
  });

  testWidgets('test_cancelar_el_cobro_pide_confirmacion_y_lo_deja_cancelado', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(handler: FakeBilledOrder().handler());
    await pumpAppSignedIn(tester, api);
    await openOrder(tester);
    await chargeMercadoPago(tester);
    await scrollTo(tester, find.byKey(const ValueKey('cancelar-pago-1')));

    await tester.tap(find.byKey(const ValueKey('cancelar-pago-1')));
    await tester.pumpAndSettle();
    await tester.tap(dialogButton('Volver'));
    await tester.pumpAndSettle();
    expect(api.requests.where((r) => r.path == '/payments/1/cancel'), isEmpty);

    await tester.tap(find.byKey(const ValueKey('cancelar-pago-1')));
    await tester.pumpAndSettle();
    await tester.tap(dialogButton('Cancelar cobro'));
    await tester.pumpAndSettle();

    expect(api.requests.where((r) => r.method == 'POST' && r.path == '/payments/1/cancel'), hasLength(1));
    expect(find.text('Cobro cancelado.'), findsOneWidget);
    await scrollTo(tester, find.text('Cancelado'));
    expect(find.text('Cancelado'), findsOneWidget);
    expect(find.byKey(const ValueKey('cobrar')), findsOneWidget);
  });

  testWidgets('test_un_error_del_proveedor_se_muestra_en_espanol_y_no_expone_credenciales', (tester) async {
    useDesktopWindow(tester);
    final order = FakeBilledOrder();
    final api = FakeApi(
      handler: order.handler(
        extra: (r) => r.method == 'POST' && r.path == '/orders/1/payments'
            ? failure(502, 'PROVIDER_ERROR', 'No se pudo comunicar con Mercado Pago. Inténtalo de nuevo.')
            : null,
      ),
    );
    await pumpAppSignedIn(tester, api);
    await openOrder(tester);
    await chargeMercadoPago(tester);

    expect(find.text('No se pudo comunicar con Mercado Pago. Inténtalo de nuevo.'), findsOneWidget);
    expect(find.textContaining('TEST-'), findsNothing);
    expect(find.textContaining('Bearer'), findsNothing);
    expect(order.payments, isEmpty);
    await scrollTo(tester, find.byKey(const ValueKey('cobrar')));
    expect(find.byKey(const ValueKey('cobrar')), findsOneWidget);
  });
}
