import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/main.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';
import 'users_screens_test.dart' show usersHandler;

/// Pruebas de ventana angosta y de reducción de movimiento (docs/design-system.md §10 y §11).
FakeHandler allHandler() {
  final users = usersHandler();
  final orders = ordersHandler();
  return (r) => users(r) ?? orders(r);
}

void main() {
  for (final width in [760.0, 1000.0, 1400.0]) {
    testWidgets('test_las_secciones_se_muestran_sin_desbordes_con_una_ventana_de_${width.toInt()}_px', (tester) async {
      useDesktopWindow(tester, width: width, height: 700);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: allHandler()));

      for (final section in ['Clientes', 'Vehículos', 'Citas', 'Órdenes', 'Usuarios', 'Inicio']) {
        await openSection(tester, section);
        expect(tester.takeException(), isNull, reason: 'sin desbordes en "$section" a $width px');
      }
    });
  }

  testWidgets('test_los_formularios_caben_en_una_ventana_angosta_y_con_poca_altura', (tester) async {
    useDesktopWindow(tester, width: 760, height: 560);
    await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: allHandler()));

    for (final (section, button) in [
      ('Clientes', 'Nuevo cliente'),
      ('Vehículos', 'Nuevo vehículo'),
      ('Citas', 'Nueva cita'),
      ('Órdenes', 'Nueva orden'),
      ('Usuarios', 'Nuevo usuario'),
    ]) {
      await openSection(tester, section);
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'formulario de "$section"');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('test_los_detalles_de_cita_y_orden_caben_en_una_ventana_angosta', (tester) async {
    useDesktopWindow(tester, width: 760, height: 560);
    await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: allHandler()));

    await openSection(tester, 'Citas');
    await tester.tap(find.text('Servicio de 50 000 km'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'detalle de cita');
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    await openSection(tester, 'Órdenes');
    await tester.tap(find.text('OS-000002'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'detalle de orden');
  });

  testWidgets('test_mis_ordenes_cabe_en_una_ventana_angosta', (tester) async {
    useDesktopWindow(tester, width: 760, height: 560);
    await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: allHandler()));

    await openSection(tester, 'Mis órdenes');
    expect(tester.takeException(), isNull, reason: 'Mis órdenes');
  });

  testWidgets('test_con_reducir_movimiento_activado_la_navegacion_no_anima', (tester) async {
    useDesktopWindow(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final api = FakeApi(handler: allHandler());
    await tester.pumpWidget(MotorixApp(apiClient: api.client, useGoogleFonts: false));
    await tester.enterText(find.widgetWithText(TextFormField, 'Usuario o correo'), 'usuario');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'Correcta2026');
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pump(); // procesa el toque
    await tester.pump(); // respuesta simulada
    await tester.pump(const Duration(milliseconds: 1));

    // Sin animación, la pantalla de inicio ya está visible tras un solo fotograma (no tras 250 ms).
    expect(find.byKey(const ValueKey('saludo')), findsOneWidget);
  });
}
