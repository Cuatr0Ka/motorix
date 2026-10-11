import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';

Finder menuItem(String label) => find.descendant(of: find.byType(NavigationRail), matching: find.text(label));

void main() {
  group('menú lateral según el rol', () {
    for (final entry in {
      'ADMIN': ['Inicio', 'Clientes', 'Vehículos', 'Citas', 'Órdenes', 'Usuarios'],
      'RECEPTIONIST': ['Inicio', 'Clientes', 'Vehículos', 'Citas', 'Órdenes'],
      'MECHANIC': ['Inicio', 'Clientes', 'Vehículos', 'Mis órdenes'],
    }.entries) {
      testWidgets('test_el_rol_${entry.key}_ve_solo_sus_opciones', (tester) async {
        useDesktopWindow(tester);
        await pumpAppSignedIn(tester, FakeApi(role: entry.key));

        for (final label in entry.value) {
          expect(menuItem(label), findsOneWidget, reason: '$label debe aparecer para ${entry.key}');
        }
        if (entry.key != 'ADMIN') {
          expect(menuItem('Usuarios'), findsNothing);
        }
        if (entry.key == 'MECHANIC') {
          expect(menuItem('Citas'), findsNothing);
          expect(menuItem('Órdenes'), findsNothing);
        } else {
          expect(menuItem('Mis órdenes'), findsNothing);
        }
      });
    }
  });

  testWidgets('test_cerrar_sesion_pide_confirmacion_y_cancelar_conserva_la_sesion', (tester) async {
    useDesktopWindow(tester);
    await pumpAppSignedIn(tester, FakeApi());

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¿Seguro que quieres cerrar sesión?'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Persona de prueba'), findsOneWidget);
  });

  testWidgets('test_confirmar_cierra_la_sesion_y_vuelve_al_acceso', (tester) async {
    useDesktopWindow(tester);
    await pumpAppSignedIn(tester, FakeApi());

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Usuario o correo'), findsOneWidget);
    expect(find.text('Hola, Persona de prueba'), findsNothing);
  });

  testWidgets('test_el_sidebar_arranca_colapsado_en_ventanas_angostas_y_se_puede_expandir', (tester) async {
    useDesktopWindow(tester, width: 900);
    await pumpAppSignedIn(tester, FakeApi());

    expect(tester.getSize(find.byType(NavigationRail)).width, closeTo(72, 1));

    await tester.tap(find.byTooltip('Expandir menú'));
    await tester.pumpAndSettle();

    // El ancho mínimo del sidebar expandido es 260; con la fuente de pruebas (Ahem, más ancha que la real)
    // la etiqueta «Mantenimientos» puede ensancharlo un poco.
    expect(tester.getSize(find.byType(NavigationRail)).width, greaterThanOrEqualTo(259));
  });

  testWidgets('test_los_accesos_directos_de_inicio_llevan_a_la_seccion', (tester) async {
    useDesktopWindow(tester);
    await pumpAppSignedIn(tester, FakeApi());

    await tester.tap(find.byKey(const ValueKey('atajo-clients')));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Persona de prueba'), findsNothing);
  });
}
