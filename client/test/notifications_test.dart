import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/utils/tokens.dart';
import 'package:motorix_client/widgets/notification_bell.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

Map<String, dynamic> _item(String type, int id, {bool read = false, Map<String, dynamic> extra = const {}}) => {
      'key': '$type:$id',
      'type': type,
      'read': read,
      'title': type == 'MAINT_OVERDUE' ? 'Mantenimiento vencido' : 'Aviso $type',
      'detail': 'Cambio de aceite · Nissan Versa ABC-123 · Juan Pérez',
      'target': {'kind': 'vehicle', 'id': 4},
      ...extra,
    };

Map<String, dynamic> _summary({List<Map<String, dynamic>> groups = const [], int? unread, int? total}) {
  final count = groups.fold<int>(0, (sum, g) => sum + (g['total'] as int));
  final sinLeer = groups.fold<int>(0, (sum, g) => sum + (g['unread'] as int));
  return {
    'unread': unread ?? sinLeer,
    'total': total ?? count,
    'generatedAt': '2026-11-20T15:04:05.000Z',
    'groups': groups,
  };
}

Map<String, dynamic> _group(String type, List<Map<String, dynamic>> items, {int? total}) => {
      'type': type,
      'total': total ?? items.length,
      'unread': items.where((i) => i['read'] != true).length,
      'items': items,
    };

/// API simulada de notificaciones: devuelve el resumen actual y cuenta las consultas.
class FakeNotifications {
  Map<String, dynamic> summary = _summary();
  bool failing = false;
  bool failingToMark = false;
  int requests = 0;
  final List<List<String>> marked = [];

  /// Marca como leídos los avisos con esas claves y recalcula los contadores, como lo haría el servidor.
  Map<String, dynamic> _markRead(List<String> keys) {
    var count = 0;
    final groups = (summary['groups'] as List).cast<Map<String, dynamic>>();
    for (final group in groups) {
      for (final item in (group['items'] as List).cast<Map<String, dynamic>>()) {
        if (keys.contains(item['key']) && item['read'] != true) {
          item['read'] = true;
          count += 1;
        }
      }
      group['unread'] = (group['items'] as List).where((i) => (i as Map)['read'] != true).length;
    }
    summary['unread'] = groups.fold<int>(0, (sum, g) => sum + (g['unread'] as int));
    return {'marked': count, 'unread': summary['unread']};
  }

  FakeHandler handler() => (r) {
        if (r.method == 'POST' && r.path == '/notifications/read') {
          if (failingToMark) return failure(500, 'INTERNAL_ERROR', 'Ocurrió un error inesperado.');
          final keys = (r.body['keys'] as List).cast<String>();
          marked.add(keys);
          return ok(_markRead(keys));
        }
        if (r.method == 'GET' && r.path == '/notifications') {
          requests += 1;
          if (failing) return failure(500, 'INTERNAL_ERROR', 'Ocurrió un error inesperado.');
          return ok(summary);
        }
        return null;
      };
}

void main() {
  group('texto de la insignia de la campana', () {
    test('test_sin_avisos_no_muestra_numero', () {
      expect(bellBadgeText(0), isNull);
      expect(bellBadgeText(-1), isNull);
    });

    test('test_muestra_el_total_hasta_noventa_y_nueve', () {
      expect(bellBadgeText(1), '1');
      expect(bellBadgeText(5), '5');
      expect(bellBadgeText(99), '99');
    });

    test('test_con_mas_de_noventa_y_nueve_muestra_99_mas', () {
      expect(bellBadgeText(100), '99+');
      expect(bellBadgeText(250), '99+');
    });
  });

  group('campana y panel de notificaciones', () {
    testWidgets('test_la_campana_muestra_el_total_de_avisos_sin_leer', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications()
        ..summary = _summary(groups: [
          _group('MAINT_OVERDUE', [_item('MAINT_OVERDUE', 7), _item('MAINT_OVERDUE', 8, read: true)]),
        ]);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));

      expect(find.byKey(const ValueKey('campana')), findsOneWidget);
      expect(find.byKey(const ValueKey('contador-campana')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('campana')), matching: find.text('1')), findsOneWidget);
    });

    testWidgets('test_sin_avisos_la_campana_no_muestra_numero_y_el_panel_dice_que_no_hay_avisos', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications();
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));

      expect(find.byKey(const ValueKey('contador-campana')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('panel-notificaciones')), findsOneWidget);
      expect(find.text('No hay avisos pendientes'), findsOneWidget);
      expect(find.text('0 sin leer'), findsOneWidget);
    });

    testWidgets('test_el_panel_muestra_los_avisos_agrupados_por_tipo', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications()
        ..summary = _summary(groups: [
          _group('MAINT_OVERDUE', [_item('MAINT_OVERDUE', 7)]),
        ]);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();

      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('1 sin leer'), findsOneWidget);
      expect(find.byKey(const ValueKey('grupo-MAINT_OVERDUE')), findsOneWidget);
      expect(find.text('Mantenimientos vencidos'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-MAINT_OVERDUE:7')), findsOneWidget);
      expect(find.text('Cambio de aceite · Nissan Versa ABC-123 · Juan Pérez'), findsOneWidget);
      expect(find.byKey(const ValueKey('no-leido-MAINT_OVERDUE:7')), findsOneWidget);
    });

    testWidgets('test_un_aviso_leido_no_lleva_el_punto_de_no_leido', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications()
        ..summary = _summary(groups: [
          _group('MAINT_OVERDUE', [_item('MAINT_OVERDUE', 7, read: true)]),
        ]);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('aviso-MAINT_OVERDUE:7')), findsOneWidget);
      expect(find.byKey(const ValueKey('no-leido-MAINT_OVERDUE:7')), findsNothing);
      expect(find.text('0 sin leer'), findsOneWidget);
    });

    testWidgets('test_con_mas_avisos_de_los_listados_muestra_el_limite', (tester) async {
      useDesktopWindow(tester);
      final items = [for (var i = 1; i <= 3; i++) _item('MAINT_OVERDUE', i)];
      final fake = FakeNotifications()
        ..summary = _summary(groups: [_group('MAINT_OVERDUE', items, total: 60)]);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('limite-MAINT_OVERDUE')), findsOneWidget);
      expect(find.text('Mostrando 3 de 60'), findsOneWidget);
    });

    testWidgets('test_con_mas_de_cien_avisos_la_campana_muestra_99_mas', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications()
        ..summary = _summary(
          groups: [
            {'type': 'MAINT_OVERDUE', 'total': 120, 'unread': 120, 'items': [_item('MAINT_OVERDUE', 1)]},
          ],
          unread: 120,
          total: 120,
        );
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('test_si_falla_la_consulta_muestra_el_error_con_reintentar_y_se_recupera', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications()..failing = true;
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();

      expect(find.text('No se pudieron consultar los avisos.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      fake
        ..failing = false
        ..summary = _summary(groups: [
          _group('MAINT_OVERDUE', [_item('MAINT_OVERDUE', 7)]),
        ]);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('aviso-MAINT_OVERDUE:7')), findsOneWidget);
      expect(find.text('No se pudieron consultar los avisos.'), findsNothing);
    });

    testWidgets('test_un_error_posterior_conserva_los_avisos_y_lo_indica_arriba', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications()
        ..summary = _summary(groups: [
          _group('MAINT_OVERDUE', [_item('MAINT_OVERDUE', 7)]),
        ]);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));

      fake.failing = true;
      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('error-avisos')), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-MAINT_OVERDUE:7')), findsOneWidget);
    });

    testWidgets('test_el_boton_cerrar_oculta_el_panel', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications();
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cerrar-panel')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('panel-notificaciones')), findsNothing);
    });
  });

  group('avisos de mantenimientos y citas de la recepción (US2)', () {
    testWidgets('test_el_panel_muestra_vencidos_citas_del_dia_y_proximos_en_ese_orden', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications()
        ..summary = _summary(groups: [
          _group('MAINT_OVERDUE', [_item('MAINT_OVERDUE', 1)]),
          _group('APPT_TODAY', [
            _item('APPT_TODAY', 3, extra: {
              'title': 'Cita de hoy',
              'detail': '09:00 · Revisión general · Nissan Versa ABC-123 · Ana Torres',
              'scheduledAt': '2026-11-20T15:00:00.000Z',
              'target': {'kind': 'appointment', 'id': 3},
            }),
          ]),
          _group('MAINT_UPCOMING', [
            _item('MAINT_UPCOMING', 2, extra: {'title': 'Mantenimiento próximo'}),
          ]),
        ]);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();

      expect(find.text('Mantenimientos vencidos'), findsOneWidget);
      expect(find.text('Citas de hoy'), findsOneWidget);
      expect(find.text('Mantenimientos próximos'), findsOneWidget);
      expect(find.text('09:00 · Revisión general · Nissan Versa ABC-123 · Ana Torres'), findsOneWidget);

      double arriba(String texto) => tester.getTopLeft(find.text(texto)).dy;
      expect(arriba('Mantenimientos vencidos'), lessThan(arriba('Citas de hoy')));
      expect(arriba('Citas de hoy'), lessThan(arriba('Mantenimientos próximos')));
    });

    testWidgets('test_cada_tipo_usa_el_color_de_la_convencion', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications()
        ..summary = _summary(groups: [
          _group('MAINT_OVERDUE', [_item('MAINT_OVERDUE', 1)]),
          _group('MAINT_UPCOMING', [_item('MAINT_UPCOMING', 2)]),
        ]);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();

      Color puntoDe(String clave) => tester.widget<Icon>(find.byKey(ValueKey('no-leido-$clave'))).color!;
      expect(puntoDe('MAINT_OVERDUE:1'), AppColors.danger);
      expect(puntoDe('MAINT_UPCOMING:2'), AppColors.warning);
    });

    testWidgets('test_con_avisos_vencidos_sin_leer_la_campana_usa_el_color_de_error', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications()
        ..summary = _summary(groups: [
          _group('MAINT_OVERDUE', [_item('MAINT_OVERDUE', 1)]),
        ]);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));

      final insignia = tester.widget<Badge>(find.byKey(const ValueKey('insignia-campana')));
      expect(insignia.backgroundColor, AppColors.danger);
    });

    testWidgets('test_con_solo_avisos_proximos_la_campana_usa_el_color_ambar', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications()
        ..summary = _summary(groups: [
          _group('MAINT_UPCOMING', [_item('MAINT_UPCOMING', 2)]),
        ]);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));

      final insignia = tester.widget<Badge>(find.byKey(const ValueKey('insignia-campana')));
      expect(insignia.backgroundColor, AppColors.warning);
    });
  });

  group('marcar como leído y abrir el módulo relacionado (US6)', () {
    FakeNotifications conUnAviso({String type = 'MAINT_OVERDUE', Map<String, dynamic>? target}) => FakeNotifications()
      ..summary = _summary(groups: [
        _group(type, [_item(type, 7, extra: target == null ? const {} : {'target': target})]),
      ]);

    testWidgets('test_el_boton_marcar_como_leido_baja_el_contador_y_deja_el_panel_abierto', (tester) async {
      useDesktopWindow(tester);
      final fake = conUnAviso();
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));
      expect(find.byKey(const ValueKey('contador-campana')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('marcar-leido-MAINT_OVERDUE:7')));
      await tester.pumpAndSettle();

      expect(fake.marked, [
        ['MAINT_OVERDUE:7'],
      ]);
      expect(find.byKey(const ValueKey('panel-notificaciones')), findsOneWidget);
      expect(find.byKey(const ValueKey('no-leido-MAINT_OVERDUE:7')), findsNothing);
      expect(find.byKey(const ValueKey('marcar-leido-MAINT_OVERDUE:7')), findsNothing);
      expect(find.text('0 sin leer'), findsOneWidget);
      expect(find.byKey(const ValueKey('contador-campana')), findsNothing);
    });

    testWidgets('test_un_aviso_ya_leido_no_ofrece_marcar_como_leido', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications()
        ..summary = _summary(groups: [
          _group('MAINT_OVERDUE', [_item('MAINT_OVERDUE', 7, read: true)]),
        ]);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('marcar-leido-MAINT_OVERDUE:7')), findsNothing);
    });

    testWidgets('test_un_error_al_marcar_muestra_el_mensaje_y_no_cambia_el_contador', (tester) async {
      useDesktopWindow(tester);
      final fake = conUnAviso()..failingToMark = true;
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('marcar-leido-MAINT_OVERDUE:7')));
      await tester.pumpAndSettle();

      expect(find.text('Ocurrió un error inesperado.'), findsOneWidget);
      expect(find.byKey(const ValueKey('no-leido-MAINT_OVERDUE:7')), findsOneWidget);
      expect(find.text('1 sin leer'), findsOneWidget);
    });

    testWidgets('test_pulsar_un_aviso_lo_marca_como_leido_cierra_el_panel_y_abre_su_pantalla', (tester) async {
      useDesktopWindow(tester);
      final fake = conUnAviso(target: {'kind': 'vehicle', 'id': 4});
      final api = FakeApi(role: 'ADMIN', handler: fake.handler());
      await pumpAppSignedIn(tester, api);

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('aviso-MAINT_OVERDUE:7')));
      await tester.pumpAndSettle();

      expect(fake.marked, [
        ['MAINT_OVERDUE:7'],
      ]);
      expect(find.byKey(const ValueKey('panel-notificaciones')), findsNothing);
      expect(find.byKey(const ValueKey('contador-campana')), findsNothing);
      // Llegó a Vehículos y abrió el detalle del vehículo del aviso.
      expect(api.requests.any((r) => r.method == 'GET' && r.path == '/vehicles/4'), isTrue);
    });

    testWidgets('test_un_aviso_de_stock_lleva_al_detalle_de_la_refaccion', (tester) async {
      useDesktopWindow(tester);
      final fake = conUnAviso(type: 'STOCK_LOW', target: {'kind': 'part', 'id': 9});
      final api = FakeApi(role: 'ADMIN', handler: fake.handler());
      await pumpAppSignedIn(tester, api);

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('aviso-STOCK_LOW:7')));
      await tester.pumpAndSettle();

      expect(api.requests.any((r) => r.method == 'GET' && r.path == '/parts/9'), isTrue);
    });

    testWidgets('test_un_aviso_de_cita_lleva_al_detalle_de_la_cita', (tester) async {
      useDesktopWindow(tester);
      final fake = conUnAviso(type: 'APPT_TODAY', target: {'kind': 'appointment', 'id': 3});
      final api = FakeApi(role: 'RECEPTIONIST', handler: fake.handler());
      await pumpAppSignedIn(tester, api);

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('aviso-APPT_TODAY:7')));
      await tester.pumpAndSettle();

      expect(api.requests.any((r) => r.method == 'GET' && r.path == '/appointments/3'), isTrue);
    });

    testWidgets('test_para_el_mecanico_el_aviso_de_orden_abre_su_orden_desde_mis_ordenes', (tester) async {
      useDesktopWindow(tester);
      final fake = conUnAviso(type: 'STALLED', target: {'kind': 'order', 'id': 5});
      final api = FakeApi(role: 'MECHANIC', handler: fake.handler());
      await pumpAppSignedIn(tester, api);

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('aviso-STALLED:7')));
      await tester.pumpAndSettle();

      expect(api.requests.any((r) => r.method == 'GET' && r.path == '/orders/5'), isTrue);
    });
  });

  group('avisos de stock para el administrador (US3)', () {
    testWidgets('test_el_panel_muestra_stock_agotado_en_rojo_y_stock_bajo_en_ambar_con_existencia_y_minimo', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications()
        ..summary = _summary(groups: [
          _group('STOCK_OUT', [
            _item('STOCK_OUT', 3, extra: {
              'title': 'Stock agotado',
              'detail': 'Correa · COR-003',
              'stock': 0,
              'minStock': 4,
              'target': {'kind': 'part', 'id': 3},
            }),
          ]),
          _group('STOCK_LOW', [
            _item('STOCK_LOW', 1, extra: {
              'title': 'Stock bajo',
              'detail': 'Filtro de aceite · FIL-001',
              'stock': 2,
              'minStock': 3,
              'target': {'kind': 'part', 'id': 1},
            }),
          ]),
        ]);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();

      expect(find.text('Stock agotado'), findsWidgets);
      expect(find.text('Stock bajo'), findsWidgets);
      expect(find.text('Correa · COR-003'), findsOneWidget);
      expect(find.text('Filtro de aceite · FIL-001'), findsOneWidget);
      Color puntoDe(String clave) => tester.widget<Icon>(find.byKey(ValueKey('no-leido-$clave'))).color!;
      expect(puntoDe('STOCK_OUT:3'), AppColors.danger);
      expect(puntoDe('STOCK_LOW:1'), AppColors.warning);
      expect(find.byKey(const ValueKey('contador-campana')), findsOneWidget);
      final insignia = tester.widget<Badge>(find.byKey(const ValueKey('insignia-campana')));
      expect(insignia.backgroundColor, AppColors.danger);
    });

    testWidgets('test_la_recepcion_no_pide_ni_muestra_avisos_de_stock', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications();
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));

      await tester.tap(find.byKey(const ValueKey('campana')));
      await tester.pumpAndSettle();

      expect(find.text('Stock agotado'), findsNothing);
      expect(find.text('Stock bajo'), findsNothing);
    });
  });

  group('actualización del contador', () {
    testWidgets('test_consulta_al_iniciar_sesion_y_cada_sesenta_segundos', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications();
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));
      final alIniciar = fake.requests;
      expect(alIniciar, greaterThanOrEqualTo(1));

      await tester.pump(const Duration(seconds: 59));
      expect(fake.requests, alIniciar);

      await tester.pump(const Duration(seconds: 2));
      expect(fake.requests, alIniciar + 1);

      await tester.pump(const Duration(seconds: 60));
      expect(fake.requests, alIniciar + 2);
    });

    testWidgets('test_un_aviso_nuevo_aparece_en_la_campana_en_a_lo_mas_sesenta_segundos', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications();
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));
      expect(find.byKey(const ValueKey('contador-campana')), findsNothing);

      fake.summary = _summary(groups: [
        _group('MAINT_OVERDUE', [_item('MAINT_OVERDUE', 7)]),
      ]);
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();

      expect(find.byKey(const ValueKey('contador-campana')), findsOneWidget);
    });

    testWidgets('test_al_cambiar_de_seccion_se_actualiza_el_contador', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications();
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));
      final antes = fake.requests;

      await openSection(tester, 'Clientes');

      expect(fake.requests, greaterThan(antes));
    });

    testWidgets('test_al_cerrar_sesion_se_detiene_la_actualizacion_periodica', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeNotifications();
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();
      final alCerrar = fake.requests;

      await tester.pump(const Duration(seconds: 130));

      expect(fake.requests, alCerrar);
    });
  });
}
