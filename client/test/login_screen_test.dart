import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/main.dart';

import 'helpers/fake_api.dart';

void main() {
  testWidgets('test_muestra_un_unico_campo_para_usuario_o_correo', (tester) async {
    useDesktopWindow(tester);
    await tester.pumpWidget(MotorixApp(apiClient: FakeApi().client, useGoogleFonts: false));

    expect(find.widgetWithText(TextFormField, 'Usuario o correo'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Contraseña'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsWidgets);
  });

  testWidgets('test_valida_campos_vacios_sin_llamar_a_la_api', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi();
    await tester.pumpWidget(MotorixApp(apiClient: api.client, useGoogleFonts: false));

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pump();

    expect(find.text('Escribe tu usuario o correo.'), findsOneWidget);
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  testWidgets('test_inicia_sesion_y_muestra_la_pantalla_de_inicio_con_nombre_y_rol', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(role: 'RECEPTIONIST');

    await pumpAppSignedIn(tester, api);

    expect(find.byKey(const ValueKey('saludo')), findsOneWidget);
    expect(find.textContaining('Recepcionista ·'), findsOneWidget);
    expect(find.textContaining(', Persona de prueba'), findsOneWidget);
    final login = api.requests.firstWhere((r) => r.path == '/auth/login');
    expect(login.body['identifier'], 'usuario');
  });

  testWidgets('test_muestra_un_mensaje_generico_con_credenciales_invalidas', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi();
    await tester.pumpWidget(MotorixApp(apiClient: api.client, useGoogleFonts: false));

    await tester.enterText(find.widgetWithText(TextFormField, 'Usuario o correo'), 'usuario');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'Incorrecta1');
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Usuario o contraseña incorrectos.'), findsOneWidget);
    expect(find.byKey(const ValueKey('saludo')), findsNothing);
  });

  testWidgets('test_muestra_el_aviso_de_cuenta_bloqueada_del_servidor', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(
      handler: (r) => r.path == '/auth/login'
          ? failure(423, 'ACCOUNT_LOCKED',
              'La cuenta está bloqueada temporalmente por varios intentos fallidos. Inténtalo de nuevo en 15 minuto(s).',
              details: {'retryAfterSeconds': 900})
          : null,
    );
    await tester.pumpWidget(MotorixApp(apiClient: api.client, useGoogleFonts: false));

    await tester.enterText(find.widgetWithText(TextFormField, 'Usuario o correo'), 'ana');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'Correcta2026');
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.textContaining('bloqueada temporalmente'), findsOneWidget);
  });
}
