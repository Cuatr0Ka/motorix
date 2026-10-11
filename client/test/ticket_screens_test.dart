import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/billing_fake.dart';
import 'helpers/data.dart';
import 'helpers/fake_api.dart';

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(['Generar ticket', 'Confirmar'].contains(label) ? FilledButton : OutlinedButton, label),
    );

Future<void> openOrder(WidgetTester tester) async {
  await openSection(tester, 'Órdenes');
  await tester.tap(find.text('OS-000001'));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).last);

FakeBilledOrder paidOrder() => FakeBilledOrder()..payments.add(paymentJson(1));

void main() {
  group('generar el ticket desde la orden', () {
    testWidgets('test_con_pago_pagado_ofrece_generar_pide_confirmacion_y_abre_el_ticket_despues', (tester) async {
      useDesktopWindow(tester);
      final order = paidOrder();
      final api = FakeApi(handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('generar-ticket')));

      await tester.tap(find.byKey(const ValueKey('generar-ticket')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Conservará los datos y los importes tal como están ahora'), findsOneWidget);
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/orders/1/ticket'), isEmpty);

      await tester.tap(find.byKey(const ValueKey('generar-ticket')));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Generar ticket'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/orders/1/ticket'), hasLength(1));
      expect(find.text('Ticket generado correctamente.'), findsOneWidget);
      await scrollTo(tester, find.byKey(const ValueKey('ver-ticket')));
      expect(find.byKey(const ValueKey('generar-ticket')), findsNothing);
      expect(find.text('Ver ticket TK-000001'), findsOneWidget);
    });

    testWidgets('test_sin_pago_pagado_no_ofrece_generar_el_ticket', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: FakeBilledOrder().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('cobrar')));

      expect(find.byKey(const ValueKey('generar-ticket')), findsNothing);
      expect(find.byKey(const ValueKey('ver-ticket')), findsNothing);
    });

    testWidgets('test_con_un_cobro_de_mercado_pago_pendiente_no_ofrece_el_ticket', (tester) async {
      useDesktopWindow(tester);
      final order = FakeBilledOrder();
      order.payments.add(paymentJson(1, method: 'MERCADO_PAGO', status: 'PENDIENTE', checkoutUrl: 'https://sandbox.simulado/pay/1'));
      final api = FakeApi(handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('enlace-1')));

      expect(find.byKey(const ValueKey('generar-ticket')), findsNothing);
    });

    testWidgets('test_un_error_del_servidor_al_generar_se_muestra_en_espanol', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: paidOrder().handler(
          extra: (r) => r.method == 'POST' && r.path == '/orders/1/ticket'
              ? failure(409, 'TICKET_REQUIRES_PAYMENT', 'La orden debe estar cobrada (pago Pagado) para generar su ticket.')
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('generar-ticket')));
      await tester.tap(find.byKey(const ValueKey('generar-ticket')));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Generar ticket'));
      await tester.pumpAndSettle();

      expect(find.text('La orden debe estar cobrada (pago Pagado) para generar su ticket.'), findsOneWidget);
    });
  });

  group('ver e imprimir el ticket', () {
    Future<void> openTicketFromOrder(WidgetTester tester) async {
      await scrollTo(tester, find.byKey(const ValueKey('ver-ticket')));
      await tester.tap(find.byKey(const ValueKey('ver-ticket')));
      await tester.pumpAndSettle();
    }

    FakeBilledOrder withTicket() => paidOrder()..ticket = {'id': 1, 'folio': 'TK-000001'};

    testWidgets('test_muestra_todos_los_campos_del_ticket_y_las_refacciones_sin_importe', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: withTicket().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await openTicketFromOrder(tester);

      expect(find.text('Ticket TK-000001'), findsWidgets);
      for (final texto in [
        'Taller de Prueba',
        'Calle 1 #23',
        'Tel. 5555555555',
        'OS-000001',
        'Ana Morales',
        'Honda Civic 2020',
        'MNO-345-E',
        '51,400 km',
        'Cambio de balatas',
        'Mano de obra frenos',
        'Balatas delanteras (BAL-DEL)',
        '2 juego',
        'Subtotal de servicios',
        'Subtotal de mano de obra',
        'Método de pago',
        'Efectivo',
        'Estado del pago',
        'Pagado',
        'Referencia',
        'TERM-48213',
      ]) {
        expect(find.textContaining(texto), findsWidgets, reason: 'Falta «$texto» en el ticket');
      }
      expect(find.byKey(const ValueKey('ticket-total')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('ticket-total'))).data, '\$1,250.00');
      // La fila de la refacción no muestra ningún importe en pesos.
      expect(find.textContaining('juego'), findsOneWidget);
    });

    testWidgets('test_imprimir_envia_el_ticket_a_la_impresora_y_avisa', (tester) async {
      useDesktopWindow(tester);
      final impresora = FakeTicketPrinter();
      final api = FakeApi(handler: withTicket().handler());
      await pumpAppSignedIn(tester, api, ticketPrinter: impresora);
      await openOrder(tester);
      await openTicketFromOrder(tester);

      await tester.tap(find.byKey(const ValueKey('imprimir-ticket')));
      await tester.pumpAndSettle();

      expect(impresora.printed, hasLength(1));
      expect(impresora.printed.first.folio, 'TK-000001');
      expect(impresora.printed.first.content!.total, '1250.00');
      expect(find.text('Ticket enviado a imprimir.'), findsOneWidget);
    });

    testWidgets('test_si_no_se_pudo_imprimir_avisa_en_espanol', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: withTicket().handler());
      await pumpAppSignedIn(tester, api, ticketPrinter: FakeTicketPrinter(succeeds: false));
      await openOrder(tester);
      await openTicketFromOrder(tester);

      await tester.tap(find.byKey(const ValueKey('imprimir-ticket')));
      await tester.pumpAndSettle();

      expect(find.text('No se imprimió el ticket. Inténtalo de nuevo.'), findsOneWidget);
    });

    testWidgets('test_un_error_al_cargar_el_ticket_permite_reintentar', (tester) async {
      useDesktopWindow(tester);
      var intentos = 0;
      final api = FakeApi(
        handler: withTicket().handler(
          extra: (r) {
            if (r.method == 'GET' && r.path == '/tickets/1') {
              intentos += 1;
              return intentos == 1 ? failure(500, 'INTERNAL_ERROR', 'No se pudo cargar el ticket.') : ok(ticketJson(1));
            }
            return null;
          },
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await openTicketFromOrder(tester);

      expect(find.text('No se pudo cargar el ticket.'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ticket')), findsOneWidget);
    });
  });

  group('listado de tickets', () {
    for (final role in ['ADMIN', 'RECEPTIONIST']) {
      testWidgets('test_el_rol_${role.toLowerCase()}_ve_el_listado_y_abre_un_ticket', (tester) async {
        useDesktopWindow(tester);
        final api = FakeApi(role: role, handler: (paidOrder()..ticket = {'id': 1, 'folio': 'TK-000001'}).handler());
        await pumpAppSignedIn(tester, api);
        await openSection(tester, 'Tickets');

        expect(find.text('TK-000001'), findsOneWidget);
        expect(find.text('Ana Morales'), findsOneWidget);
        expect(find.text('\$1,250.00'), findsOneWidget);

        await tester.tap(find.text('TK-000001'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('ticket')), findsOneWidget);
      });
    }

    testWidgets('test_busca_y_muestra_el_estado_vacio', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: FakeBilledOrder().handler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Tickets');

      expect(find.text('Todavía no hay tickets generados.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'TK-12');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(api.requests.any((r) => r.path == '/tickets' && r.query['search'] == 'TK-12'), isTrue);
      expect(find.text('No se encontraron tickets con esa búsqueda.'), findsOneWidget);
    });

    testWidgets('test_un_error_del_servidor_muestra_el_mensaje_y_reintentar', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: (r) => r.path == '/tickets' ? failure(500, 'INTERNAL_ERROR', 'No se pudieron cargar los tickets.') : null);
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Tickets');

      expect(find.text('No se pudieron cargar los tickets.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('test_el_mecanico_no_ve_la_seccion_tickets', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: FakeBilledOrder().handler());
      await pumpAppSignedIn(tester, api);

      expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Tickets')), findsNothing);
    });
  });
}
