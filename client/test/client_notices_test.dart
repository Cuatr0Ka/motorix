import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

Map<String, dynamic> _fila(
  String reason,
  int factId, {
  String cliente = 'Ana Torres',
  String telefono = '7761234567',
  String? folio,
}) =>
    {
      'reason': reason,
      'factId': factId,
      'factDate': '2026-11-19',
      if (folio != null) 'folio': folio,
      'description': 'Orden terminada, lista para entregar',
      'client': {'id': 9, 'name': cliente, 'phone': telefono},
      'vehicle': {'id': 14, 'brand': 'Chevrolet', 'model': 'Aveo', 'licensePlate': 'XYZ-987'},
    };

/// API simulada de clientes por avisar: la lista, el registro del aviso y los avisos del centro de notificaciones.
class FakeClientNotices {
  FakeClientNotices(List<Map<String, dynamic>> rows) : rows = [...rows];

  final List<Map<String, dynamic>> rows;
  bool failingToList = false;
  String? markFailsWith;
  final List<Map<String, dynamic>> posted = [];
  int listRequests = 0;
  int notificationRequests = 0;

  FakeHandler handler() => (r) {
        if (r.path == '/notifications') {
          notificationRequests += 1;
          return ok({'unread': 0, 'total': 0, 'generatedAt': '2026-11-20T15:04:05.000Z', 'groups': []});
        }
        if (r.method == 'GET' && r.path == '/client-notices') {
          listRequests += 1;
          if (failingToList) return failure(500, 'INTERNAL_ERROR', 'Ocurrió un error inesperado.');
          return ok(rows, meta: {'total': rows.length});
        }
        if (r.method == 'POST' && r.path == '/client-notices') {
          posted.add(r.body);
          if (markFailsWith == 'NOTICE_NOT_APPLICABLE') {
            rows.removeWhere((f) => f['reason'] == r.body['reason'] && f['factId'] == r.body['factId']);
            return failure(409, 'NOTICE_NOT_APPLICABLE', 'La orden ya no está lista para avisar.');
          }
          if (markFailsWith != null) return failure(500, 'INTERNAL_ERROR', markFailsWith!);
          rows.removeWhere((f) => f['reason'] == r.body['reason'] && f['factId'] == r.body['factId']);
          return created({'id': 1, ...r.body, 'clientId': 9, 'notifiedBy': 2, 'notifiedAt': '2026-11-20T15:10:00.000Z'});
        }
        return null;
      };
}

void main() {
  group('sección Clientes por avisar en el menú', () {
    for (final role in ['ADMIN', 'RECEPTIONIST']) {
      testWidgets('test_el_menu_de_${role.toLowerCase()}_incluye_clientes_por_avisar', (tester) async {
        useDesktopWindow(tester);
        final fake = FakeClientNotices([]);
        await pumpAppSignedIn(tester, FakeApi(role: role, handler: fake.handler()));

        expect(find.text('Clientes por avisar'), findsWidgets);
      });
    }

    testWidgets('test_el_menu_del_mecanico_no_incluye_clientes_por_avisar', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeClientNotices([]);
      await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: fake.handler()));

      expect(find.text('Clientes por avisar'), findsNothing);
    });
  });

  group('lista de clientes por avisar (US7)', () {
    testWidgets('test_muestra_cliente_telefono_vehiculo_motivo_y_fecha', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeClientNotices([
        _fila('ORDER_READY', 31, folio: 'OS-000031'),
        _fila('APPT_TOMORROW', 5, cliente: 'Luis Gómez', telefono: ''),
        _fila('MAINT_OVERDUE', 7, cliente: 'Rosa Díaz'),
        _fila('MAINT_UPCOMING', 8, cliente: 'Pedro Ruiz'),
      ]);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));
      await openSection(tester, 'Clientes por avisar');

      expect(find.text('Llama o avisa en persona y marca al cliente como avisado. El sistema no envía mensajes.'), findsOneWidget);
      expect(find.text('Ana Torres'), findsOneWidget);
      expect(find.text('7761234567'), findsWidgets);
      expect(find.text('Chevrolet Aveo · XYZ-987'), findsWidgets);
      expect(find.text('Vehículo listo'), findsOneWidget);
      expect(find.text('Cita de mañana'), findsOneWidget);
      expect(find.text('Mantenimiento vencido'), findsOneWidget);
      expect(find.text('Mantenimiento próximo'), findsOneWidget);
      expect(find.text('19/11/2026'), findsWidgets);
    });

    testWidgets('test_un_cliente_sin_telefono_muestra_sin_telefono_registrado', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeClientNotices([_fila('APPT_TOMORROW', 5, cliente: 'Luis Gómez', telefono: '')]);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));
      await openSection(tester, 'Clientes por avisar');

      expect(find.byKey(const ValueKey('sin-telefono-APPT_TOMORROW:5')), findsOneWidget);
      expect(find.text('Sin teléfono registrado'), findsOneWidget);
    });

    testWidgets('test_sin_clientes_por_avisar_muestra_el_estado_vacio', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeClientNotices([]);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));
      await openSection(tester, 'Clientes por avisar');

      expect(find.text('No hay clientes por avisar'), findsOneWidget);
    });

    testWidgets('test_si_falla_la_consulta_muestra_el_error_y_reintentar_la_recupera', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeClientNotices([_fila('ORDER_READY', 31, folio: 'OS-000031')])..failingToList = true;
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));
      await openSection(tester, 'Clientes por avisar');

      expect(find.text('Ocurrió un error inesperado.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      fake.failingToList = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Ana Torres'), findsOneWidget);
    });
  });

  group('marcar como avisado (US7)', () {
    testWidgets('test_avisado_pide_confirmacion_y_cancelar_no_registra_nada', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeClientNotices([_fila('ORDER_READY', 31, folio: 'OS-000031')]);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));
      await openSection(tester, 'Clientes por avisar');

      await tester.tap(find.byKey(const ValueKey('avisado-ORDER_READY:31')));
      await tester.pumpAndSettle();

      expect(find.text('Marcar como avisado'), findsOneWidget);
      expect(find.text('¿Ya avisaste a Ana Torres por vehículo listo?'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(fake.posted, isEmpty);
      expect(find.text('Ana Torres'), findsOneWidget);
    });

    testWidgets('test_confirmar_registra_el_aviso_saca_la_fila_y_actualiza_la_campana', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeClientNotices([_fila('ORDER_READY', 31, folio: 'OS-000031')]);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));
      await openSection(tester, 'Clientes por avisar');
      final antes = fake.notificationRequests;

      await tester.tap(find.byKey(const ValueKey('avisado-ORDER_READY:31')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sí, avisado'));
      await tester.pumpAndSettle();

      expect(fake.posted, [
        {'reason': 'ORDER_READY', 'factId': 31},
      ]);
      expect(find.text('Cliente marcado como avisado'), findsOneWidget);
      expect(find.text('Ana Torres'), findsNothing);
      expect(find.text('No hay clientes por avisar'), findsOneWidget);
      expect(fake.notificationRequests, greaterThan(antes));
    });

    testWidgets('test_si_el_hecho_ya_no_aplica_muestra_el_mensaje_y_actualiza_la_lista', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeClientNotices([_fila('ORDER_READY', 31, folio: 'OS-000031')])
        ..markFailsWith = 'NOTICE_NOT_APPLICABLE';
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));
      await openSection(tester, 'Clientes por avisar');
      final consultas = fake.listRequests;

      await tester.tap(find.byKey(const ValueKey('avisado-ORDER_READY:31')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sí, avisado'));
      await tester.pumpAndSettle();

      expect(find.text('Este aviso ya no aplica'), findsOneWidget);
      expect(fake.listRequests, greaterThan(consultas));
      expect(find.text('Ana Torres'), findsNothing);
    });

    testWidgets('test_si_falla_el_registro_conserva_la_fila_y_muestra_el_error', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeClientNotices([_fila('ORDER_READY', 31, folio: 'OS-000031')])..markFailsWith = 'No se pudo registrar el aviso.';
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));
      await openSection(tester, 'Clientes por avisar');

      await tester.tap(find.byKey(const ValueKey('avisado-ORDER_READY:31')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sí, avisado'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo registrar el aviso.'), findsOneWidget);
      expect(find.text('Ana Torres'), findsOneWidget);
    });
  });
}
