import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/models/client_notice.dart';
import 'package:motorix_client/models/notice.dart';

Map<String, dynamic> _item(String type, {Map<String, dynamic> extra = const {}}) => {
      'key': '$type:7',
      'type': type,
      'read': false,
      'title': 'Título',
      'detail': 'Detalle',
      'target': {'kind': 'vehicle', 'id': 4},
      ...extra,
    };

void main() {
  group('avisos del centro de notificaciones', () {
    test('test_lee_el_resumen_con_sus_grupos_y_sus_avisos', () {
      final summary = NoticesSummary.fromJson({
        'unread': 2,
        'total': 3,
        'generatedAt': '2026-11-20T15:04:05.000Z',
        'groups': [
          {
            'type': 'MAINT_OVERDUE',
            'total': 1,
            'unread': 1,
            'items': [
              _item('MAINT_OVERDUE', extra: {'dueDate': '2026-11-10', 'dueMileage': 52000}),
            ],
          },
          {
            'type': 'STALLED',
            'total': 2,
            'unread': 1,
            'items': [
              _item('STALLED', extra: {'folio': 'OS-000005', 'status': 'ESPERANDO_REFACCION', 'daysStalled': 4}),
            ],
          },
        ],
      });

      expect(summary.unread, 2);
      expect(summary.total, 3);
      expect(summary.groups.map((g) => g.type), [NoticeType.maintenanceOverdue, NoticeType.stalledOrder]);
      final vencido = summary.groups.first.items.first;
      expect(vencido.key, 'MAINT_OVERDUE:7');
      expect(vencido.dueDate, DateTime(2026, 11, 10));
      expect(vencido.dueMileage, 52000);
      expect(vencido.target.kind, 'vehicle');
      expect(vencido.target.id, 4);
      final detenida = summary.groups.last.items.first;
      expect(detenida.folio, 'OS-000005');
      expect(detenida.daysStalled, 4);
      expect(summary.groups.last.isTruncated, isTrue);
    });

    test('test_lee_una_respuesta_sin_avisos', () {
      final summary = NoticesSummary.fromJson({'unread': 0, 'total': 0, 'groups': []});
      expect(summary.unread, 0);
      expect(summary.groups, isEmpty);
      expect(summary.hasCriticalUnread, isFalse);
    });

    test('test_reconoce_los_seis_tipos_y_su_tono', () {
      for (final tipo in NoticeType.values) {
        expect(NoticeType.fromApi(tipo.apiValue), tipo);
      }
      expect(NoticeType.fromApi('OTRO'), isNull);
      expect(NoticeType.maintenanceOverdue.isCritical, isTrue);
      expect(NoticeType.stockOut.isCritical, isTrue);
      expect(NoticeType.stockLow.isCritical, isFalse);
      expect(NoticeType.stalledOrder.isCritical, isFalse);
    });

    test('test_detecta_avisos_criticos_sin_leer_y_deja_de_hacerlo_al_leerlos', () {
      final summary = NoticesSummary.fromJson({
        'unread': 1,
        'total': 1,
        'groups': [
          {
            'type': 'STOCK_OUT',
            'total': 1,
            'unread': 1,
            'items': [_item('STOCK_OUT', extra: {'stock': 0, 'minStock': 5})],
          },
        ],
      });
      expect(summary.hasCriticalUnread, isTrue);

      final leido = summary.copyWith(
        unread: 0,
        groups: [
          summary.groups.first.copyWith(
            unread: 0,
            items: [summary.groups.first.items.first.copyWith(read: true)],
          ),
        ],
      );
      expect(leido.unread, 0);
      expect(leido.groups.first.items.first.read, isTrue);
      expect(leido.hasCriticalUnread, isFalse);
    });
  });

  group('clientes por avisar', () {
    Map<String, dynamic> fila(String reason, {String phone = '7761234567'}) => {
          'reason': reason,
          'factId': 31,
          'factDate': '2026-11-19',
          'folio': reason == 'ORDER_READY' ? 'OS-000031' : null,
          'description': 'Orden terminada, lista para entregar',
          'client': {'id': 9, 'name': 'Ana Torres', 'phone': phone},
          'vehicle': {'id': 14, 'brand': 'Chevrolet', 'model': 'Aveo', 'licensePlate': 'XYZ-987'},
        };

    test('test_lee_cada_motivo_con_su_etiqueta', () {
      final etiquetas = {
        'ORDER_READY': 'Vehículo listo',
        'APPT_TOMORROW': 'Cita de mañana',
        'MAINT_UPCOMING': 'Mantenimiento próximo',
        'MAINT_OVERDUE': 'Mantenimiento vencido',
      };
      etiquetas.forEach((api, etiqueta) {
        final aviso = PendingClientNotice.fromJson(fila(api));
        expect(aviso.reason.label, etiqueta);
        expect(aviso.rowKey, '$api:31');
      });
    });

    test('test_lee_el_cliente_el_vehiculo_y_el_folio', () {
      final aviso = PendingClientNotice.fromJson(fila('ORDER_READY'));
      expect(aviso.client.name, 'Ana Torres');
      expect(aviso.client.phone, '7761234567');
      expect(aviso.client.hasPhone, isTrue);
      expect(aviso.vehicle.label, 'Chevrolet Aveo · XYZ-987');
      expect(aviso.folio, 'OS-000031');
      expect(aviso.factDate, DateTime(2026, 11, 19));
    });

    test('test_un_telefono_vacio_se_reconoce_como_sin_telefono', () {
      expect(PendingClientNotice.fromJson(fila('ORDER_READY', phone: '')).client.hasPhone, isFalse);
      expect(PendingClientNotice.fromJson(fila('ORDER_READY', phone: '   ')).client.hasPhone, isFalse);
    });
  });
}
