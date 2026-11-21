import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/models/ticket.dart';
import 'package:motorix_client/utils/ticket_printer.dart';

import 'helpers/data.dart';

void main() {
  formatoDelDocumento();
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

void formatoDelDocumento() {
  test('test_el_documento_de_impresion_de_un_ticket_version_2_se_arma_con_precios_e_importes', () async {
    final json = ticketJson(
      10,
      formatVersion: 2,
      partsTotal: '360.00',
      total: '1610.00',
      parts: const [
        {'code': 'BAL-DEL', 'name': 'Balatas delanteras', 'unit': 'juego', 'quantity': 2, 'unitPrice': '180.00', 'amount': '360.00'},
      ],
    );

    final ticket = Ticket.fromJson(json);
    final bytes = await buildTicketDocument(ticket).save();

    expect(ticket.content!.isV2, isTrue);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('test_el_documento_de_un_ticket_version_3_incluye_el_proximo_servicio_y_se_arma', () async {
    final ticket = Ticket.fromJson(ticketJson(
      12,
      formatVersion: 3,
      partsTotal: '360.00',
      nextService: const {'dueDate': '2031-05-20', 'dueMileage': 90000, 'description': 'Cambio de aceite'},
    ));

    final bytes = await buildTicketDocument(ticket).save();

    expect(ticket.content!.isV3, isTrue);
    expect(ticket.content!.nextService!.dueMileage, 90000);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('test_los_tickets_version_1_y_2_no_tienen_proximo_servicio', () {
    expect(Ticket.fromJson(ticketJson(13)).content!.nextService, isNull);
    expect(Ticket.fromJson(ticketJson(14, formatVersion: 2, partsTotal: '0.00')).content!.isV3, isFalse);
  });

  test('test_el_documento_de_un_ticket_anterior_se_arma_sin_precios_ni_subtotal_de_refacciones', () async {
    final ticket = Ticket.fromJson(ticketJson(11));

    final bytes = await buildTicketDocument(ticket).save();

    expect(ticket.content!.isV2, isFalse);
    expect(ticket.content!.partsTotal, isNull);
    expect(ticket.content!.parts.single.amount, isNull);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
