import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

void main() {
  group('cierre de sesión por inactividad (US10)', () {
    testWidgets('test_a_los_28_minutos_aparece_el_aviso_con_cuenta_regresiva', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST'));

      await tester.pump(const Duration(minutes: 28));
      await tester.pump();

      expect(find.text('Tu sesión está por cerrarse'), findsOneWidget);
      expect(find.text('Se cerrará en 02:00'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Se cerrará en 01:30'), findsOneWidget);
    });

    testWidgets('test_seguir_conectado_reinicia_el_temporizador_y_avisa_al_servidor', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'RECEPTIONIST');
      await pumpAppSignedIn(tester, api);

      await tester.pump(const Duration(minutes: 28));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('seguir-conectado')));
      await tester.pumpAndSettle();

      expect(find.text('Tu sesión está por cerrarse'), findsNothing);
      expect(api.requests.where((r) => r.method == 'GET' && r.path == '/auth/me'), isNotEmpty);

      // El conteo empezó de nuevo: 27 minutos después todavía no hay aviso ni cierre.
      await tester.pump(const Duration(minutes: 27));
      await tester.pump();
      expect(find.text('Tu sesión está por cerrarse'), findsNothing);
      expect(find.text('Iniciar sesión'), findsNothing);
    });

    testWidgets('test_a_los_30_minutos_sin_actividad_se_cierra_la_sesion_con_el_aviso', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST'));

      await tester.pump(const Duration(minutes: 28));
      await tester.pump(const Duration(minutes: 2));
      await tester.pumpAndSettle();

      expect(find.text('Tu sesión se cerró por inactividad. Inicia sesión de nuevo.'), findsOneWidget);
      expect(find.text('Tu sesión está por cerrarse'), findsNothing);
    });

    testWidgets('test_la_actividad_antes_de_los_28_minutos_retrasa_el_aviso', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST'));

      await tester.pump(const Duration(minutes: 20));
      await tester.tapAt(const Offset(700, 400));
      await tester.pump(const Duration(minutes: 20));
      await tester.pump();

      expect(find.text('Tu sesión está por cerrarse'), findsNothing);
    });

    testWidgets('test_con_actividad_consulta_auth_me_como_maximo_cada_5_minutos', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'RECEPTIONIST');
      await pumpAppSignedIn(tester, api);
      int pings() => api.requests.where((r) => r.method == 'GET' && r.path == '/auth/me').length;

      await tester.pump(const Duration(minutes: 6));
      await tester.tapAt(const Offset(700, 400));
      await tester.pump();
      final primero = pings();
      await tester.tapAt(const Offset(700, 410));
      await tester.pump();

      expect(primero, 1);
      expect(pings(), 1); // otra actividad inmediata no repite la consulta
    });

    testWidgets('test_un_session_inactive_del_servidor_cierra_la_sesion_igual', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        role: 'RECEPTIONIST',
        handler: (r) => r.method == 'GET' && r.path == '/clients'
            ? failure(401, 'SESSION_INACTIVE', 'Tu sesión se cerró por inactividad. Inicia sesión de nuevo.')
            : null,
      );
      await pumpAppSignedIn(tester, api);

      await openSection(tester, 'Clientes');
      await tester.pumpAndSettle();

      expect(find.text('Tu sesión se cerró por inactividad. Inicia sesión de nuevo.'), findsOneWidget);
    });
  });
}
