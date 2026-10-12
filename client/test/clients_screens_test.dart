import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

void main() {
  testWidgets('test_muestra_el_listado_de_clientes_con_sus_datos', (tester) async {
    useDesktopWindow(tester);
    await pumpAppSignedIn(tester, FakeApi(handler: clientsHandler()));
    await openSection(tester, 'Clientes');

    expect(find.text('Ana Morales'), findsOneWidget);
    expect(find.text('ana@x.local'), findsOneWidget);
    expect(find.text('Luis Pérez'), findsOneWidget);
    expect(find.text('1–2 de 2'), findsNothing);
  });

  testWidgets('test_muestra_el_estado_vacio_con_accion_para_quien_puede_registrar', (tester) async {
    useDesktopWindow(tester);
    await pumpAppSignedIn(tester, FakeApi(handler: clientsHandler(items: [])));
    await openSection(tester, 'Clientes');

    expect(find.text('Todavía no hay clientes registrados.'), findsOneWidget);
    expect(find.text('Registrar el primer cliente'), findsOneWidget);
  });

  testWidgets('test_el_mecanico_ve_el_listado_pero_no_los_botones_de_alta', (tester) async {
    useDesktopWindow(tester);
    await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: clientsHandler()));
    await openSection(tester, 'Clientes');

    expect(find.text('Ana Morales'), findsOneWidget);
    expect(find.text('Nuevo cliente'), findsNothing);
  });

  testWidgets('test_muestra_el_estado_de_error_y_permite_reintentar', (tester) async {
    useDesktopWindow(tester);
    var fallar = true;
    final api = FakeApi(
      handler: (r) {
        if (r.method == 'GET' && r.path == '/clients') {
          if (fallar) return failure(500, 'INTERNAL_ERROR', 'Ocurrió un error inesperado. Inténtalo de nuevo.');
          return ok([clientJson(1, 'Ana Morales')], meta: {'page': 1, 'pageSize': 20, 'total': 1});
        }
        return null;
      },
    );
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Clientes');

    expect(find.text('Ocurrió un error inesperado. Inténtalo de nuevo.'), findsOneWidget);

    fallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Morales'), findsOneWidget);
  });

  testWidgets('test_la_busqueda_envia_el_texto_al_servidor_y_muestra_sin_resultados', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(
      handler: (r) {
        if (r.method == 'GET' && r.path == '/clients' && r.query['search'] == 'zzz') {
          return ok([], meta: {'page': 1, 'pageSize': 20, 'total': 0});
        }
        return clientsHandler()(r);
      },
    );
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Clientes');

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(api.requests.any((r) => r.path == '/clients' && r.query['search'] == 'zzz'), isTrue);
    expect(find.text('No se encontraron clientes con esa búsqueda.'), findsOneWidget);
  });

  group('formulario de cliente', () {
    Future<void> openForm(WidgetTester tester) async {
      await openSection(tester, 'Clientes');
      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();
    }

    testWidgets('test_valida_los_campos_obligatorios_sin_llamar_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: clientsHandler());
      await pumpAppSignedIn(tester, api);
      await openForm(tester);

      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(find.text('El nombre es obligatorio.'), findsOneWidget);
      expect(find.text('El teléfono es obligatorio.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/clients'), isEmpty);
    });

    testWidgets('test_guarda_el_cliente_vuelve_al_listado_y_muestra_el_aviso_de_exito', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: clientsHandler(
          extra: (r) => r.method == 'POST' && r.path == '/clients'
              ? created({...clientJson(9, r.body['name'] as String), 'vehicles': []})
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openForm(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre completo *'), 'María Gómez');
      await tester.enterText(find.widgetWithText(TextFormField, 'Teléfono *'), '5598765432');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/clients');
      expect(post.body['name'], 'María Gómez');
      expect(post.body.containsKey('confirmDuplicatePhone'), isFalse);
      expect(find.text('Cliente registrado correctamente.'), findsOneWidget);
      expect(find.text('Nuevo cliente'), findsOneWidget); // volvió al listado
    });

    testWidgets('test_telefono_duplicado_muestra_coincidencias_y_reenvia_al_confirmar', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: clientsHandler(
          extra: (r) {
            if (r.method == 'POST' && r.path == '/clients') {
              if (r.body['confirmDuplicatePhone'] == true) {
                return created({...clientJson(9, 'Luis Morales'), 'vehicles': []});
              }
              return failure(409, 'PHONE_DUPLICATE', 'Ya existe un cliente con ese teléfono.', details: {
                'matches': [
                  {'id': 1, 'name': 'Ana Morales', 'phone': '5512345678'},
                ],
              });
            }
            return null;
          },
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openForm(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre completo *'), 'Luis Morales');
      await tester.enterText(find.widgetWithText(TextFormField, 'Teléfono *'), '5512345678');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Posible cliente duplicado'), findsOneWidget);
      expect(find.textContaining('Ana Morales — 5512345678'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();

      final posts = api.requests.where((r) => r.method == 'POST' && r.path == '/clients').toList();
      expect(posts, hasLength(2));
      expect(posts.last.body['confirmDuplicatePhone'], isTrue);
      expect(find.text('Cliente registrado correctamente.'), findsOneWidget);
    });

    testWidgets('test_cancelar_la_advertencia_de_telefono_no_guarda_nada', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: clientsHandler(
          extra: (r) => r.method == 'POST' && r.path == '/clients'
              ? failure(409, 'PHONE_DUPLICATE', 'Ya existe un cliente con ese teléfono.', details: {
                  'matches': [
                    {'id': 1, 'name': 'Ana Morales', 'phone': '5512345678'},
                  ],
                })
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openForm(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre completo *'), 'Luis Morales');
      await tester.enterText(find.widgetWithText(TextFormField, 'Teléfono *'), '5512345678');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(OutlinedButton, 'Cancelar'),
      ));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/clients'), hasLength(1));
      expect(find.text('Nuevo cliente'), findsOneWidget); // sigue en el formulario (título)
      expect(find.text('Cliente registrado correctamente.'), findsNothing);
    });

    testWidgets('test_correo_duplicado_se_muestra_en_el_campo_sin_opcion_de_confirmar', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: clientsHandler(
          extra: (r) => r.method == 'POST' && r.path == '/clients'
              ? failure(409, 'EMAIL_DUPLICATE', 'Ya existe un cliente con ese correo electrónico.')
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openForm(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre completo *'), 'Luis');
      await tester.enterText(find.widgetWithText(TextFormField, 'Teléfono *'), '5512345678');
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), 'ana@x.local');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Ya existe un cliente con ese correo electrónico.'), findsOneWidget);
      expect(find.text('Posible cliente duplicado'), findsNothing);
    });

    testWidgets('test_salir_con_cambios_pide_confirmacion', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(handler: clientsHandler()));
      await openForm(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre completo *'), 'Algo');
      await tester.pump(); // el formulario se marca como modificado antes de pulsar "Cancelar"
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Tienes cambios sin guardar. ¿Seguro que quieres salir?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo cliente'), findsOneWidget); // de vuelta en el listado (botón)
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('test_salir_sin_cambios_no_pide_confirmacion', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(handler: clientsHandler()));
      await openForm(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Salir sin guardar'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
    });
  });

  group('detalle de cliente', () {
    testWidgets('test_muestra_los_datos_y_la_lista_de_vehiculos', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: clientsHandler(
          extra: (r) => r.method == 'GET' && r.path == '/clients/1'
              ? ok({
                  ...clientJson(1, 'Ana Morales', email: 'ana@x.local'),
                  'vehicles': [
                    {'id': 5, 'brand': 'Honda', 'model': 'Civic', 'year': 2020, 'licensePlate': 'MNO-345-E', 'currentMileage': 51200},
                  ],
                })
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Clientes');
      await tester.tap(find.text('Ana Morales'));
      await tester.pumpAndSettle();

      expect(find.text('Detalle del cliente'), findsOneWidget);
      expect(find.text('ana@x.local'), findsOneWidget);
      expect(find.text('Vehículos (1)'), findsOneWidget);
      expect(find.text('MNO-345-E'), findsOneWidget);
      expect(find.text('51200 km'), findsOneWidget);
    });

    testWidgets('test_muestra_un_mensaje_si_el_cliente_no_tiene_vehiculos', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: clientsHandler(
          extra: (r) => r.method == 'GET' && r.path == '/clients/2'
              ? ok({...clientJson(2, 'Luis Pérez'), 'vehicles': []})
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Clientes');
      await tester.tap(find.text('Luis Pérez'));
      await tester.pumpAndSettle();

      expect(find.text('Este cliente todavía no tiene vehículos registrados.'), findsOneWidget);
    });

    testWidgets('test_el_mecanico_no_ve_el_boton_editar', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        role: 'MECHANIC',
        handler: clientsHandler(
          extra: (r) => r.method == 'GET' && r.path == '/clients/2'
              ? ok({...clientJson(2, 'Luis Pérez'), 'vehicles': []})
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Clientes');
      await tester.tap(find.text('Luis Pérez'));
      await tester.pumpAndSettle();

      expect(find.text('Detalle del cliente'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
    });
  });
}
