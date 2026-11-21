import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  int requests = 0;

  FakeHandler handler() => (r) {
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
