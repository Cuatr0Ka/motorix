import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

Map<String, dynamic> entry(int id, String action, String summary, {String user = 'Administrador'}) => {
      'id': id,
      'createdAt': '2026-11-21T15:10:00.000Z',
      'action': action,
      'actor': {'id': 1, 'username': 'admin', 'name': user},
      'entityType': 'user',
      'entityId': 3,
      'summary': summary,
    };

class FakeAudit {
  FakeAudit({this.total = 2});

  final int total;
  bool failing = false;
  bool empty = false;

  FakeHandler handler() => (r) {
        if (r.method == 'GET' && r.path == '/users') {
          return ok([
            userJson('ADMIN', id: 1, name: 'Administrador'),
            userJson('RECEPTIONIST', id: 2, name: 'Recepción'),
          ]);
        }
        if (r.method == 'GET' && r.path == '/audit-log') {
          if (failing) return failure(500, 'INTERNAL_ERROR', 'Ocurrió un error inesperado.');
          final page = int.tryParse(r.query['page'] ?? '1') ?? 1;
          final items = empty
              ? <Map<String, dynamic>>[]
              : [
                  entry(page * 10 + 1, 'USER_CREATED', 'Alta del usuario ana con el rol MECHANIC'),
                  entry(page * 10 + 2, 'LOGIN_FAILED', 'Intento de inicio de sesión fallido', user: 'Recepción'),
                ];
          return ok(items, meta: {'page': page, 'pageSize': 20, 'total': empty ? 0 : total});
        }
        return null;
      };
}

Future<FakeApi> openAudit(WidgetTester tester, FakeAudit fake, {String role = 'ADMIN'}) async {
  useDesktopWindow(tester);
  final api = FakeApi(role: role, handler: fake.handler());
  await pumpAppSignedIn(tester, api);
  if (role == 'ADMIN') await openSection(tester, 'Bitácora');
  return api;
}

void main() {
  group('sección Bitácora (US10)', () {
    testWidgets('test_lista_fecha_usuario_accion_entidad_y_resumen', (tester) async {
      await openAudit(tester, FakeAudit());

      expect(find.text('Alta del usuario ana con el rol MECHANIC'), findsOneWidget);
      expect(find.text('Usuario creado'), findsWidgets); // chip de la acción (también está en el filtro)
      expect(find.text('Inicio de sesión fallido'), findsWidgets);
      expect(find.textContaining('Recepción'), findsWidgets);
      expect(find.textContaining('user #3'), findsWidgets);
    });

    for (final role in ['RECEPTIONIST', 'MECHANIC']) {
      testWidgets('test_la_seccion_no_existe_para_${role.toLowerCase()}', (tester) async {
        await openAudit(tester, FakeAudit(), role: role);

        expect(find.text('Bitácora'), findsNothing);
      });
    }

    testWidgets('test_filtrar_por_accion_envia_el_filtro_y_limpiar_lo_quita', (tester) async {
      final api = await openAudit(tester, FakeAudit());

      await tester.tap(find.byKey(const ValueKey('bitacora-accion')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuenta bloqueada').last);
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.path == '/audit-log').last.query['action'], 'ACCOUNT_LOCKED');

      await tester.tap(find.byKey(const ValueKey('bitacora-limpiar')));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.path == '/audit-log').last.query.containsKey('action'), isFalse);
    });

    testWidgets('test_filtrar_por_fecha_envia_desde_y_hasta_y_una_fecha_invalida_se_marca', (tester) async {
      final api = await openAudit(tester, FakeAudit());

      await tester.enterText(find.byKey(const ValueKey('bitacora-desde')), 'ayer');
      await tester.tap(find.byKey(const ValueKey('bitacora-filtrar')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bitacora-error-fecha')), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('bitacora-desde')), '2026-11-01');
      await tester.enterText(find.byKey(const ValueKey('bitacora-hasta')), '2026-11-21');
      await tester.tap(find.byKey(const ValueKey('bitacora-filtrar')));
      await tester.pumpAndSettle();

      final ultima = api.requests.where((r) => r.path == '/audit-log').last;
      expect(ultima.query['from'], '2026-11-01');
      expect(ultima.query['to'], '2026-11-21');
      expect(find.byKey(const ValueKey('bitacora-error-fecha')), findsNothing);
    });

    testWidgets('test_la_paginacion_pide_la_pagina_siguiente', (tester) async {
      final api = await openAudit(tester, FakeAudit(total: 45));

      expect(find.text('Página 1 de 3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bitacora-siguiente')));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.path == '/audit-log').last.query['page'], '2');
      expect(find.text('Página 2 de 3'), findsOneWidget);
    });

    testWidgets('test_sin_resultados_muestra_el_estado_vacio', (tester) async {
      await openAudit(tester, FakeAudit()..empty = true);

      expect(find.text('No hay registros con esos filtros'), findsOneWidget);
    });

    testWidgets('test_si_falla_la_carga_muestra_el_error_con_reintentar', (tester) async {
      await openAudit(tester, FakeAudit()..failing = true);

      expect(find.text('Ocurrió un error inesperado.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
