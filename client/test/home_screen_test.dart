import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/utils/formatters.dart';

import 'helpers/fake_api.dart';

void main() {
  group('saludo y fecha', () {
    test('test_el_saludo_cambia_segun_la_hora', () {
      expect(greetingFor(DateTime(2026, 10, 11, 8)), 'Buenos días');
      expect(greetingFor(DateTime(2026, 10, 11, 11, 59)), 'Buenos días');
      expect(greetingFor(DateTime(2026, 10, 11, 12)), 'Buenas tardes');
      expect(greetingFor(DateTime(2026, 10, 11, 19, 59)), 'Buenas tardes');
      expect(greetingFor(DateTime(2026, 10, 11, 20)), 'Buenas noches');
      expect(greetingFor(DateTime(2026, 10, 11, 2)), 'Buenos días');
    });

    test('test_la_fecha_larga_esta_en_espanol', () {
      expect(formatLongDate(DateTime(2026, 10, 11)), 'domingo, 11 de octubre de 2026');
      expect(formatLongDate(DateTime(2026, 1, 5)), 'lunes, 5 de enero de 2026');
    });
  });

  group('pantalla de inicio', () {
    testWidgets('test_muestra_el_saludo_con_el_nombre_el_rol_y_la_fecha', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST'));

      expect(find.textContaining(', Persona de prueba'), findsOneWidget);
      expect(find.textContaining('Recepcionista · '), findsOneWidget);
    });

    testWidgets('test_el_administrador_tiene_acceso_destacado_al_panel_de_control', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN'));

      expect(find.byKey(const ValueKey('acceso-panel-control')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('acceso-panel-control')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('actualizar-panel')), findsOneWidget);
    });

    for (final role in ['RECEPTIONIST', 'MECHANIC']) {
      testWidgets('test_el_rol_${role}_no_ve_el_acceso_al_panel_de_control', (tester) async {
        useDesktopWindow(tester);
        await pumpAppSignedIn(tester, FakeApi(role: role));

        expect(find.byKey(const ValueKey('acceso-panel-control')), findsNothing);
      });
    }

    testWidgets('test_los_accesos_rapidos_dependen_del_rol', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC'));

      expect(find.byKey(const ValueKey('atajo-myOrders')), findsOneWidget);
      expect(find.byKey(const ValueKey('atajo-appointments')), findsNothing);
    });
  });
}
