import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/models/ticket.dart';
import 'package:motorix_client/widgets/ticket_view.dart';

import 'helpers/data.dart';

Widget _ticket(Map<String, dynamic> json) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: TicketView(ticket: Ticket.fromJson(json)))),
    );

void main() {
  group('bloque «Próximo servicio» (US8)', () {
    testWidgets('test_la_version_3_muestra_el_bloque_con_fecha_y_kilometraje', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_ticket(ticketJson(
        1,
        formatVersion: 3,
        partsTotal: '360.00',
        nextService: const {'dueDate': '2031-05-20', 'dueMileage': 90000, 'description': 'Cambio de aceite'},
      )));

      expect(find.byKey(const ValueKey('ticket-proximo-servicio')), findsOneWidget);
      expect(find.text('Próximo servicio'), findsOneWidget);
      expect(find.text('Cambio de aceite'), findsOneWidget);
      expect(find.text('20/05/2031'), findsOneWidget);
      expect(find.textContaining('90,000'), findsWidgets);
    });

    testWidgets('test_solo_con_kilometraje_no_muestra_la_linea_de_fecha', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_ticket(ticketJson(
        2,
        formatVersion: 3,
        partsTotal: '360.00',
        nextService: const {'dueDate': null, 'dueMileage': 90000, 'description': 'Revisión'},
      )));

      expect(find.byKey(const ValueKey('ticket-proximo-servicio')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('ticket-proximo-servicio')), matching: find.text('Fecha')), findsNothing);
    });

    testWidgets('test_los_tickets_version_1_y_2_se_ven_sin_el_bloque', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_ticket(ticketJson(3)));
      expect(find.text('Próximo servicio'), findsNothing);

      await tester.pumpWidget(_ticket(ticketJson(4, formatVersion: 2, partsTotal: '0.00')));
      await tester.pump();
      expect(find.text('Próximo servicio'), findsNothing);
      expect(find.byKey(const ValueKey('ticket-subtotal-refacciones')), findsOneWidget);
    });
  });
}
