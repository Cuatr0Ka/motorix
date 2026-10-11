import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/widgets/client_selector.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

/// API simulada con el cliente 1 (Ana Morales, con un vehículo) y el vehículo 1.
FakeHandler ownerHandler({FakeHandler? extra}) {
  final base = vehiclesHandler(extra: extra);
  return (r) {
    final custom = extra?.call(r);
    if (custom != null) return custom;
    if (r.method == 'GET' && r.path == '/clients/1') {
      return ok({
        ...clientJson(1, 'Ana Morales', email: 'ana@x.local', vehicles: 1),
        'vehicles': [
          {'id': 1, 'brand': 'Honda', 'model': 'Civic', 'year': 2020, 'licensePlate': 'MNO-345-E', 'currentMileage': 51200},
        ],
      });
    }
    if (r.method == 'GET' && r.path == '/vehicles/1') return ok(vehicleJson(1));
    return base(r);
  };
}

Future<void> openVehicleDetail(WidgetTester tester) async {
  await openSection(tester, 'Vehículos');
  await tester.tap(find.text('MNO-345-E'));
  await tester.pumpAndSettle();
}

Future<void> openVehicleEdit(WidgetTester tester) async {
  await openVehicleDetail(tester);
  await tester.tap(find.text('Editar'));
  await tester.pumpAndSettle();
}

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(label == 'Confirmar' ? FilledButton : OutlinedButton, label),
    );

void main() {
  group('registrar un vehículo desde el detalle del cliente', () {
    testWidgets('test_el_propietario_llega_preseleccionado_y_se_guarda_con_su_clientId', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: ownerHandler(
          extra: (r) => r.method == 'POST' && r.path == '/vehicles'
              ? created(vehicleJson(7, brand: 'Nissan', model: 'Versa', plate: 'ABC-123-A'))
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Clientes');
      await tester.tap(find.text('Ana Morales'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Registrar vehículo'));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo vehículo'), findsOneWidget);
      expect(find.textContaining('Ana Morales · 5512345678'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Placa *'), 'ABC-123-A');
      await tester.enterText(find.widgetWithText(TextFormField, 'Marca *'), 'Nissan');
      await tester.enterText(find.widgetWithText(TextFormField, 'Modelo *'), 'Versa');
      await tester.enterText(find.widgetWithText(TextFormField, 'Año *'), '2019');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/vehicles');
      expect(post.body['clientId'], 1);
      expect(find.text('Vehículo registrado correctamente.'), findsOneWidget);
      expect(find.text('Detalle del cliente'), findsOneWidget);
    });

    testWidgets('test_el_mecanico_no_ve_el_boton_registrar_vehiculo', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: ownerHandler()));
      await openSection(tester, 'Clientes');
      await tester.tap(find.text('Ana Morales'));
      await tester.pumpAndSettle();

      expect(find.text('Detalle del cliente'), findsOneWidget);
      expect(find.text('Registrar vehículo'), findsNothing);
    });
  });

  group('detalle del vehículo y su propietario', () {
    testWidgets('test_muestra_los_datos_y_el_propietario_con_enlace_al_cliente', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(handler: ownerHandler()));
      await openVehicleDetail(tester);

      expect(find.text('Detalle del vehículo'), findsOneWidget);
      expect(find.text('Propietario'), findsOneWidget);
      expect(find.text('Ana Morales'), findsWidgets);
      expect(find.text('51200 km'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ver-propietario')));
      await tester.pumpAndSettle();
      expect(find.text('Detalle del cliente'), findsOneWidget);
    });

    testWidgets('test_desde_el_detalle_del_cliente_se_abre_el_vehiculo', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(handler: ownerHandler()));
      await openSection(tester, 'Clientes');
      await tester.tap(find.text('Ana Morales'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('ver-vehiculo-1')));
      await tester.pumpAndSettle();

      expect(find.text('Detalle del vehículo'), findsOneWidget);
    });

    testWidgets('test_el_mecanico_no_ve_el_boton_editar', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: ownerHandler()));
      await openVehicleDetail(tester);

      expect(find.text('Detalle del vehículo'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
    });
  });

  group('edición de vehículo', () {
    FakeApi apiConPatch() => FakeApi(
          handler: ownerHandler(
            extra: (r) => r.method == 'PATCH' && r.path == '/vehicles/1'
                ? ok(vehicleJson(1, ownerId: (r.body['clientId'] as int?) ?? 1, ownerName: 'Luis Pérez'))
                : null,
          ),
        );

    Future<void> chooseOwner(WidgetTester tester, String name) async {
      await tester.tap(find.byType(ClientSelectorField));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(name)));
      await tester.pumpAndSettle();
    }

    testWidgets('test_el_formulario_de_edicion_llega_con_los_datos_actuales', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, apiConPatch());
      await openVehicleEdit(tester);

      expect(find.text('Editar vehículo'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'MNO-345-E'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Honda'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '51200'), findsOneWidget);
      expect(find.textContaining('Ana Morales · 5512345678'), findsOneWidget);
    });

    testWidgets('test_cambiar_el_propietario_pide_confirmacion_y_al_confirmar_envia_el_nuevo_clientId', (tester) async {
      useDesktopWindow(tester);
      final api = apiConPatch();
      await pumpAppSignedIn(tester, api);
      await openVehicleEdit(tester);

      await chooseOwner(tester, 'Luis Pérez');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Cambiar propietario'), findsOneWidget);
      expect(find.textContaining('de Ana Morales a Luis Pérez'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);

      await tester.tap(dialogButton('Confirmar'));
      await tester.pumpAndSettle();

      final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/vehicles/1');
      expect(patch.body['clientId'], 2);
      expect(patch.body.containsKey('mileageCorrection'), isFalse);
      expect(find.text('Vehículo actualizado correctamente.'), findsOneWidget);
    });

    testWidgets('test_cancelar_el_cambio_de_propietario_no_envia_nada', (tester) async {
      useDesktopWindow(tester);
      final api = apiConPatch();
      await pumpAppSignedIn(tester, api);
      await openVehicleEdit(tester);

      await chooseOwner(tester, 'Luis Pérez');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);
      expect(find.text('Editar vehículo'), findsOneWidget);
    });

    testWidgets('test_un_kilometraje_menor_pide_confirmar_la_correccion_y_envia_mileageCorrection', (tester) async {
      useDesktopWindow(tester);
      final api = apiConPatch();
      await pumpAppSignedIn(tester, api);
      await openVehicleEdit(tester);

      await tester.enterText(find.widgetWithText(TextFormField, '51200'), '40000');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Corregir kilometraje'), findsOneWidget);
      expect(find.textContaining('40000 km'), findsOneWidget);
      expect(find.textContaining('51200 km'), findsWidgets);

      await tester.tap(dialogButton('Confirmar'));
      await tester.pumpAndSettle();

      final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/vehicles/1');
      expect(patch.body['currentMileage'], 40000);
      expect(patch.body['mileageCorrection'], isTrue);
    });

    testWidgets('test_cancelar_la_correccion_de_kilometraje_no_envia_nada', (tester) async {
      useDesktopWindow(tester);
      final api = apiConPatch();
      await pumpAppSignedIn(tester, api);
      await openVehicleEdit(tester);

      await tester.enterText(find.widgetWithText(TextFormField, '51200'), '40000');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);
    });

    testWidgets('test_un_kilometraje_mayor_se_guarda_sin_pedir_correccion', (tester) async {
      useDesktopWindow(tester);
      final api = apiConPatch();
      await pumpAppSignedIn(tester, api);
      await openVehicleEdit(tester);

      await tester.enterText(find.widgetWithText(TextFormField, '51200'), '52000');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Corregir kilometraje'), findsNothing);
      final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/vehicles/1');
      expect(patch.body['currentMileage'], 52000);
      expect(patch.body.containsKey('mileageCorrection'), isFalse);
    });

    testWidgets('test_borrar_el_kilometraje_registrado_tambien_pide_confirmacion', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, apiConPatch());
      await openVehicleEdit(tester);

      await tester.enterText(find.widgetWithText(TextFormField, '51200'), '');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Corregir kilometraje'), findsOneWidget);
      expect(find.textContaining('Vas a borrar el kilometraje registrado'), findsOneWidget);
    });
  });
}
