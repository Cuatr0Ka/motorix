import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';

Map<String, dynamic> userRow(int id, String username, String role, {bool active = true, String? name}) => {
      'id': id,
      'username': username,
      'name': name ?? 'Persona $username',
      'email': '$username@prueba.local',
      'role': role,
      'active': active,
      'createdAt': '2026-10-10T10:00:00.000Z',
    };

/// API simulada de usuarios: la sesión se inicia como el usuario 1 (ADMIN) de [FakeApi].
FakeHandler usersHandler({List<Map<String, dynamic>>? items, FakeHandler? extra}) {
  final list = items ??
      [
        userRow(1, 'admin', 'ADMIN', name: 'Persona de prueba'),
        userRow(2, 'recepcion', 'RECEPTIONIST'),
        userRow(3, 'baja', 'MECHANIC', active: false),
      ];
  return (r) {
    final custom = extra?.call(r);
    if (custom != null) return custom;
    if (r.method == 'GET' && r.path == '/users') {
      return ok(list, meta: {'page': 1, 'pageSize': 20, 'total': list.length});
    }
    return null;
  };
}

Future<void> openUsers(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Usuarios')));
  await tester.pumpAndSettle();
}

Future<void> openRowMenu(WidgetTester tester, String username) async {
  await tester.tap(find.byTooltip('Acciones de $username'));
  await tester.pumpAndSettle();
}

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(label == 'Confirmar' || label == 'Guardar' ? FilledButton : OutlinedButton, label),
    );

void main() {
  group('listado de usuarios', () {
    testWidgets('test_el_administrador_ve_la_tabla_con_rol_y_estado', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: usersHandler()));
      await openUsers(tester);

      expect(find.text('Usuarios'), findsWidgets);
      expect(find.text('recepcion'), findsOneWidget);
      expect(find.text('Recepcionista'), findsOneWidget);
      expect(find.text('Activo'), findsNWidgets(2));
      expect(find.text('Inactivo'), findsOneWidget);
      expect(find.text('admin (tú)'), findsOneWidget);
    });

    for (final role in ['RECEPTIONIST', 'MECHANIC']) {
      testWidgets('test_el_rol_${role}_no_ve_la_opcion_usuarios_en_el_menu', (tester) async {
        useDesktopWindow(tester);
        await pumpAppSignedIn(tester, FakeApi(role: role));

        expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Usuarios')), findsNothing);
      });
    }

    testWidgets('test_muestra_el_error_de_carga_y_permite_reintentar', (tester) async {
      useDesktopWindow(tester);
      var fallar = true;
      final api = FakeApi(
        role: 'ADMIN',
        handler: usersHandler(
          extra: (r) {
            if (r.method == 'GET' && r.path == '/users') {
              if (fallar) return failure(500, 'INTERNAL_ERROR', 'Ocurrió un error inesperado. Inténtalo de nuevo.');
              return ok([userRow(1, 'admin', 'ADMIN')], meta: {'page': 1, 'pageSize': 20, 'total': 1});
            }
            return null;
          },
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openUsers(tester);
      expect(find.text('Ocurrió un error inesperado. Inténtalo de nuevo.'), findsOneWidget);

      fallar = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('admin (tú)'), findsOneWidget);
    });
  });

  group('desactivar y activar', () {
    testWidgets('test_desactivar_pide_confirmacion_y_cancelar_no_envia_nada', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: usersHandler());
      await pumpAppSignedIn(tester, api);
      await openUsers(tester);

      await openRowMenu(tester, 'recepcion');
      await tester.tap(find.text('Desactivar'));
      await tester.pumpAndSettle();
      expect(find.text('Desactivar usuario'), findsOneWidget);

      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);
    });

    testWidgets('test_confirmar_la_desactivacion_envia_active_false_y_avisa', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        role: 'ADMIN',
        handler: usersHandler(
          extra: (r) => r.method == 'PATCH' && r.path == '/users/2'
              ? ok(userRow(2, 'recepcion', 'RECEPTIONIST', active: false))
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openUsers(tester);

      await openRowMenu(tester, 'recepcion');
      await tester.tap(find.text('Desactivar'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Confirmar'));
      await tester.pumpAndSettle();

      final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/users/2');
      expect(patch.body, {'active': false});
      expect(find.text('Usuario desactivado.'), findsOneWidget);
    });

    testWidgets('test_reactivar_no_pide_confirmacion', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        role: 'ADMIN',
        handler: usersHandler(
          extra: (r) => r.method == 'PATCH' && r.path == '/users/3'
              ? ok(userRow(3, 'baja', 'MECHANIC'))
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openUsers(tester);

      await openRowMenu(tester, 'baja');
      await tester.tap(find.text('Activar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/users/3');
      expect(patch.body, {'active': true});
      expect(find.text('Usuario activado.'), findsOneWidget);
    });

    testWidgets('test_el_conflicto_de_ultimo_administrador_se_muestra_al_usuario', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        role: 'ADMIN',
        handler: usersHandler(
          extra: (r) => r.method == 'PATCH' && r.path == '/users/1'
              ? failure(409, 'LAST_ADMIN',
                  'No se puede desactivar ni cambiar el rol del único administrador activo. Crea o activa otro administrador primero.')
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openUsers(tester);

      await openRowMenu(tester, 'admin');
      await tester.tap(find.text('Desactivar'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('único administrador activo'), findsOneWidget);
    });
  });

  group('cambiar rol', () {
    testWidgets('test_cambia_el_rol_con_el_selector_y_envia_el_valor_de_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        role: 'ADMIN',
        handler: usersHandler(
          extra: (r) => r.method == 'PATCH' && r.path == '/users/2'
              ? ok(userRow(2, 'recepcion', 'MECHANIC'))
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openUsers(tester);

      await openRowMenu(tester, 'recepcion');
      await tester.tap(find.text('Cambiar rol'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selector-rol')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mecánico').last);
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/users/2');
      expect(patch.body, {'role': 'MECHANIC'});
      expect(find.text('Rol actualizado. Rige desde su siguiente acción.'), findsOneWidget);
    });

    testWidgets('test_no_envia_nada_si_se_deja_el_mismo_rol', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: usersHandler());
      await pumpAppSignedIn(tester, api);
      await openUsers(tester);

      await openRowMenu(tester, 'recepcion');
      await tester.tap(find.text('Cambiar rol'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);
    });
  });

  group('alta de usuario', () {
    Future<void> openForm(WidgetTester tester) async {
      await openUsers(tester);
      await tester.tap(find.text('Nuevo usuario'));
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, {String password = 'Clave2026x'}) async {
      await tester.enterText(find.widgetWithText(TextFormField, 'Usuario *'), 'nuevo.usuario');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre completo *'), 'Nuevo Usuario');
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo electrónico *'), 'nuevo@prueba.local');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña inicial *'), password);
      await tester.tap(find.byKey(const ValueKey('rol')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mecánico').last);
      await tester.pumpAndSettle();
    }

    testWidgets('test_valida_los_campos_obligatorios_sin_llamar_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: usersHandler());
      await pumpAppSignedIn(tester, api);
      await openForm(tester);

      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(find.text('El usuario es obligatorio.'), findsOneWidget);
      expect(find.text('El nombre es obligatorio.'), findsOneWidget);
      expect(find.text('El correo es obligatorio.'), findsOneWidget);
      expect(find.text('Selecciona un rol.'), findsOneWidget);
      expect(find.text('La contraseña es obligatoria.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/users'), isEmpty);
    });

    testWidgets('test_aplica_la_politica_de_contrasena_antes_de_enviar', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: usersHandler());
      await pumpAppSignedIn(tester, api);
      await openForm(tester);
      await fill(tester, password: 'sinmayuscula1');

      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(find.text('La contraseña debe incluir al menos una letra mayúscula.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/users'), isEmpty);
    });

    testWidgets('test_muestra_la_politica_de_contrasena_como_ayuda', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: usersHandler()));
      await openForm(tester);

      expect(find.text('Mínimo 8 caracteres, con una mayúscula, una minúscula y un número.'), findsOneWidget);
    });

    testWidgets('test_crea_el_usuario_con_el_rol_elegido_y_vuelve_al_listado', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        role: 'ADMIN',
        handler: usersHandler(
          extra: (r) => r.method == 'POST' && r.path == '/users'
              ? created(userRow(9, 'nuevo.usuario', 'MECHANIC', name: 'Nuevo Usuario'))
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openForm(tester);
      await fill(tester);

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/users');
      expect(post.body['username'], 'nuevo.usuario');
      expect(post.body['role'], 'MECHANIC');
      expect(post.body['password'], 'Clave2026x');
      expect(find.text('Usuario creado correctamente.'), findsOneWidget);
    });

    testWidgets('test_usuario_y_correo_duplicados_se_muestran_en_su_campo', (tester) async {
      useDesktopWindow(tester);
      var respuesta = failure(409, 'USERNAME_DUPLICATE', 'Ya existe un usuario con ese nombre de usuario.');
      final api = FakeApi(
        role: 'ADMIN',
        handler: usersHandler(
          extra: (r) => r.method == 'POST' && r.path == '/users' ? respuesta : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openForm(tester);
      await fill(tester);

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Ya existe un usuario con ese nombre de usuario.'), findsOneWidget);

      respuesta = failure(409, 'EMAIL_DUPLICATE', 'Ya existe un usuario con ese correo electrónico.');
      await tester.enterText(find.widgetWithText(TextFormField, 'Usuario *'), 'otro.usuario');
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Ya existe un usuario con ese correo electrónico.'), findsOneWidget);
    });

    testWidgets('test_salir_con_cambios_pide_confirmacion', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: usersHandler()));
      await openForm(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Usuario *'), 'algo');
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Tienes cambios sin guardar. ¿Seguro que quieres salir?'), findsOneWidget);
    });
  });

  group('cambiar contraseña propia', () {
    Future<void> openChangePassword(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Opciones de la cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, {String current = 'Actual2026a', String next = 'Nueva2026b', String? confirm}) async {
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña actual *'), current);
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña nueva *'), next);
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirmar contraseña nueva *'), confirm ?? next);
    }

    for (final role in ['ADMIN', 'RECEPTIONIST', 'MECHANIC']) {
      testWidgets('test_el_rol_${role}_puede_abrir_la_pantalla_desde_el_menu_de_la_cuenta', (tester) async {
        useDesktopWindow(tester);
        await pumpAppSignedIn(tester, FakeApi(role: role, handler: usersHandler()));
        await openChangePassword(tester);

        expect(find.text('Contraseña actual *'), findsOneWidget);
        expect(find.text('Mínimo 8 caracteres, con una mayúscula, una minúscula y un número.'), findsOneWidget);
      });
    }

    testWidgets('test_valida_confirmacion_politica_y_que_sea_distinta_sin_llamar_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: usersHandler());
      await pumpAppSignedIn(tester, api);
      await openChangePassword(tester);

      await fill(tester, next: 'Nueva2026b', confirm: 'Otra2026c');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pump();
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);

      await fill(tester, next: 'corta1A');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pump();
      expect(find.text('La contraseña debe tener al menos 8 caracteres.'), findsOneWidget);

      await fill(tester, current: 'Misma2026a', next: 'Misma2026a');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pump();
      expect(find.text('La contraseña nueva debe ser distinta a la actual.'), findsOneWidget);

      expect(api.requests.where((r) => r.path == '/auth/change-password'), isEmpty);
    });

    testWidgets('test_cambia_la_contrasena_limpia_los_campos_y_avisa', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        role: 'ADMIN',
        handler: usersHandler(
          extra: (r) => r.method == 'POST' && r.path == '/auth/change-password' ? ok({'changed': true}) : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openChangePassword(tester);
      await fill(tester);

      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.path == '/auth/change-password');
      expect(post.body, {'currentPassword': 'Actual2026a', 'newPassword': 'Nueva2026b'});
      expect(find.text('Contraseña actualizada correctamente.'), findsOneWidget);
      expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Contraseña actual *')).controller!.text, isEmpty);
    });

    testWidgets('test_una_contrasena_actual_incorrecta_se_muestra_en_su_campo', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        role: 'ADMIN',
        handler: usersHandler(
          extra: (r) => r.path == '/auth/change-password'
              ? failure(401, 'INVALID_CREDENTIALS', 'Usuario o contraseña incorrectos.')
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openChangePassword(tester);
      await fill(tester);

      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();

      expect(find.text('La contraseña actual es incorrecta.'), findsOneWidget);
    });
  });
}
