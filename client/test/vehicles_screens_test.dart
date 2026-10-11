import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

void main() {
  testWidgets('test_muestra_el_listado_de_vehiculos_con_su_propietario', (tester) async {
    useDesktopWindow(tester);
    await pumpAppSignedIn(tester, FakeApi(handler: vehiclesHandler()));
    await openSection(tester, 'Vehículos');

    expect(find.text('MNO-345-E'), findsOneWidget);
    expect(find.text('Toyota'), findsOneWidget);
    expect(find.text('Ana Morales'), findsOneWidget);
    expect(find.text('Luis Pérez'), findsOneWidget);
    expect(find.text('1–2 de 2'), findsOneWidget);
  });

  testWidgets('test_muestra_el_estado_vacio_con_accion_para_quien_puede_registrar', (tester) async {
    useDesktopWindow(tester);
    await pumpAppSignedIn(tester, FakeApi(handler: vehiclesHandler(items: [])));
    await openSection(tester, 'Vehículos');

    expect(find.text('Todavía no hay vehículos registrados.'), findsOneWidget);
    expect(find.text('Registrar el primer vehículo'), findsOneWidget);
  });

  testWidgets('test_el_mecanico_ve_el_listado_pero_no_el_boton_de_alta', (tester) async {
    useDesktopWindow(tester);
    await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: vehiclesHandler()));
    await openSection(tester, 'Vehículos');

    expect(find.text('MNO-345-E'), findsOneWidget);
    expect(find.text('Nuevo vehículo'), findsNothing);
  });

  testWidgets('test_muestra_el_error_de_carga_y_permite_reintentar', (tester) async {
    useDesktopWindow(tester);
    var fallar = true;
    final api = FakeApi(
      handler: vehiclesHandler(
        extra: (r) {
          if (r.method == 'GET' && r.path == '/vehicles') {
            if (fallar) return failure(500, 'INTERNAL_ERROR', 'Ocurrió un error inesperado. Inténtalo de nuevo.');
            return ok([vehicleJson(1)], meta: {'page': 1, 'pageSize': 20, 'total': 1});
          }
          return null;
        },
      ),
    );
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Vehículos');
    expect(find.text('Ocurrió un error inesperado. Inténtalo de nuevo.'), findsOneWidget);

    fallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('MNO-345-E'), findsOneWidget);
  });

  group('formulario de vehículo', () {
    Future<void> openForm(WidgetTester tester) async {
      await openSection(tester, 'Vehículos');
      await tester.tap(find.text('Nuevo vehículo'));
      await tester.pumpAndSettle();
    }

    Future<void> chooseOwner(WidgetTester tester, String name) async {
      await tester.tap(find.text('Propietario *'));
      await tester.pumpAndSettle();
      expect(find.text('Elegir propietario'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(name)));
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, {String plate = 'ABC-123-A'}) async {
      await tester.enterText(find.widgetWithText(TextFormField, 'Placa *'), plate);
      await tester.enterText(find.widgetWithText(TextFormField, 'Marca *'), 'Nissan');
      await tester.enterText(find.widgetWithText(TextFormField, 'Modelo *'), 'Versa');
      await tester.enterText(find.widgetWithText(TextFormField, 'Año *'), '2019');
    }

    testWidgets('test_exige_propietario_y_datos_obligatorios_sin_llamar_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: vehiclesHandler());
      await pumpAppSignedIn(tester, api);
      await openForm(tester);

      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(find.text('Selecciona un propietario.'), findsOneWidget);
      expect(find.text('La placa es obligatoria.'), findsOneWidget);
      expect(find.text('La marca es obligatoria.'), findsOneWidget);
      expect(find.text('El modelo es obligatorio.'), findsOneWidget);
      expect(find.text('El año es obligatorio.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/vehicles'), isEmpty);
    });

    testWidgets('test_valida_el_anio_y_el_vin_en_el_formulario', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(handler: vehiclesHandler()));
      await openForm(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Año *'), '1900');
      await tester.enterText(find.widgetWithText(TextFormField, 'Número de serie (VIN)'), '12345');
      await tester.enterText(find.widgetWithText(TextFormField, 'Kilometraje actual'), '-5');
      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(find.text('El año no puede ser anterior a 1950.'), findsOneWidget);
      expect(find.textContaining('17 caracteres alfanuméricos'), findsOneWidget);
      expect(find.text('El kilometraje no puede ser negativo.'), findsOneWidget);
    });

    testWidgets('test_busca_y_elige_al_propietario_y_guarda_el_vehiculo_con_su_clientId', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: vehiclesHandler(
          extra: (r) => r.method == 'POST' && r.path == '/vehicles'
              ? created(vehicleJson(9, brand: 'Nissan', model: 'Versa', plate: 'ABC-123-A', ownerId: 2, ownerName: 'Luis Pérez'))
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openForm(tester);

      await chooseOwner(tester, 'Luis Pérez');
      expect(find.textContaining('Luis Pérez · 5512345678'), findsOneWidget);
      await fill(tester);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/vehicles');
      expect(post.body['clientId'], 2);
      expect(post.body['licensePlate'], 'ABC-123-A');
      expect(post.body['year'], 2019);
      expect(post.body['vin'], isNull);
      expect(find.text('Vehículo registrado correctamente.'), findsOneWidget);
      expect(find.text('Nuevo vehículo'), findsOneWidget); // de vuelta en el listado
    });

    testWidgets('test_el_buscador_de_propietarios_filtra_por_nombre', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: vehiclesHandler());
      await pumpAppSignedIn(tester, api);
      await openForm(tester);

      await tester.tap(find.text('Propietario *'));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'luis');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Luis Pérez')), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Ana Morales')), findsNothing);
      expect(api.requests.any((r) => r.path == '/clients' && r.query['search'] == 'luis'), isTrue);
    });

    testWidgets('test_placa_duplicada_se_muestra_en_el_campo', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: vehiclesHandler(
          extra: (r) => r.method == 'POST' && r.path == '/vehicles'
              ? failure(409, 'PLATE_DUPLICATE', 'Ya existe un vehículo con esa placa.')
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openForm(tester);
      await chooseOwner(tester, 'Ana Morales');
      await fill(tester);

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Ya existe un vehículo con esa placa.'), findsOneWidget);
      expect(find.text('Vehículo registrado correctamente.'), findsNothing);
    });

    testWidgets('test_propietario_inexistente_se_muestra_en_el_selector', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: vehiclesHandler(
          extra: (r) => r.method == 'POST' && r.path == '/vehicles'
              ? failure(422, 'OWNER_NOT_FOUND', 'El propietario seleccionado no existe. Elige un cliente registrado.')
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openForm(tester);
      await chooseOwner(tester, 'Ana Morales');
      await fill(tester);

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('El propietario seleccionado no existe. Elige un cliente registrado.'), findsOneWidget);
    });

    testWidgets('test_salir_con_cambios_pide_confirmacion', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(handler: vehiclesHandler()));
      await openForm(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Marca *'), 'Algo');
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Tienes cambios sin guardar. ¿Seguro que quieres salir?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
    });
  });
}
