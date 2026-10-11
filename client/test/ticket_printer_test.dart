import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/models/ticket.dart';
import 'package:motorix_client/utils/ticket_printer.dart';

import 'helpers/data.dart';

void main() {
  test('test_el_documento_de_impresion_se_arma_en_memoria_con_el_contenido_del_ticket', () async {
    final ticket = Ticket.fromJson(ticketJson(7));

    final bytes = await buildTicketDocument(ticket).save();

    expect(bytes.length, greaterThan(500));
    // Un PDF válido empieza con la firma %PDF; solo vive en memoria, no se guarda ningún archivo.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('test_el_documento_admite_tickets_sin_refacciones_ni_mano_de_obra_y_textos_con_acentos', () async {
    final json = ticketJson(8, parts: const [], clientName: 'Ángela Muñoz Peña');
    (json['content'] as Map<String, dynamic>)['labor'] = <Map<String, dynamic>>[];

    final bytes = await buildTicketDocument(Ticket.fromJson(json)).save();

    expect(bytes, isNotEmpty);
  });

  test('test_un_ticket_de_listado_sin_contenido_no_se_imprime', () async {
    final ticket = Ticket.fromJson(ticketJson(9, full: false));

    expect(ticket.content, isNull);
    expect(await const SystemTicketPrinter().printTicket(ticket), isFalse);
  });
}
