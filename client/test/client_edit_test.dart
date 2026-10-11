import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

/// Cliente 1 (Ana Morales) con detalle editable: el PATCH actualiza lo que devuelve el GET siguiente.
class EditableClients {
  Map<String, dynamic> ana = {
    ...clientJson(1, 'Ana Morales', email: 'ana@x.local', vehicles: 0),
    'address': 'Calle 1',
    'vehicles': <Map<String, dynamic>>[],
  };

  FakeHandler handler({FakeHandler? onPatch}) => clientsHandler(
        extra: (r) {
          if (r.method == 'GET' && r.path == '/clients/1') return ok(ana);
          if (r.method == 'PATCH' && r.path == '/clients/1') {
            final custom = onPatch?.call(r);
            if (custom != null) return custom;
            ana = {...ana, ...Map<String, dynamic>.from(r.body)..remove('confirmDuplicatePhone')};
            return ok(ana);
          }
          return null;
        },
      );
}

Future<void> openDetail(WidgetTester tester) async {
  await openSection(tester, 'Clientes');
  await tester.tap(find.text('Ana Morales'));
  await tester.pumpAndSettle();
}

Future<void> openEditFromDetail(WidgetTester tester) async {
  await openDetail(tester);
  await tester.tap(find.text('Editar'));
  await tester.pumpAndSettle();
}

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(label == 'Confirmar' ? FilledButton : OutlinedButton, label),
    );

void main() {
  testWidgets('test_el_formulario_de_edicion_llega_con_los_datos_actuales', (tester) async {
    useDesktopWindow(tester);
    await pumpAppSignedIn(tester, FakeApi(handler: EditableClients().handler()));
    await openEditFromDetail(tester);

    expect(find.text('Editar cliente'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Ana Morales'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '5512345678'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'ana@x.local'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Calle 1'), findsOneWidget);
  });

  testWidgets('test_cambiar_el_telefono_lo_envia_por_patch_y_se_ve_en_el_detalle', (tester) async {
    useDesktopWindow(tester);
    final clientes = EditableClients();
    final api = FakeApi(handler: clientes.handler());
    await pumpAppSignedIn(tester, api);
    await openEditFromDetail(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '5512345678'), '5599998888');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/clients/1');
    expect(patch.body['phone'], '5599998888');
    expect(find.text('Cliente actualizado correctamente.'), findsOneWidget);
    expect(find.text('Detalle del cliente'), findsOneWidget);
    expect(find.text('5599998888'), findsOneWidget);
  });

  testWidgets('test_una_edicion_invalida_no_llama_a_la_api_y_conserva_los_datos', (tester) async {
    useDesktopWindow(tester);
    final api = FakeApi(handler: EditableClients().handler());
    await pumpAppSignedIn(tester, api);
    await openEditFromDetail(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Ana Morales'), '   ');
    await tester.enterText(find.widgetWithText(TextFormField, '5512345678'), 'abc');
    await tester.enterText(find.widgetWithText(TextFormField, 'ana@x.local'), 'sin-arroba');
    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(find.text('El nombre es obligatorio.'), findsOneWidget);
    expect(find.text('El teléfono solo puede llevar dígitos, +, espacios, guiones o paréntesis.'), findsOneWidget);
    expect(find.text('El correo no es válido.'), findsOneWidget);
    expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);
  });

  testWidgets('test_el_rechazo_del_servidor_se_muestra_y_no_cambia_el_detalle', (tester) async {
    useDesktopWindow(tester);
    final clientes = EditableClients();
    final api = FakeApi(
      handler: clientes.handler(
        onPatch: (r) => failure(409, 'EMAIL_DUPLICATE', 'Ya existe un cliente con ese correo electrónico.'),
      ),
    );
    await pumpAppSignedIn(tester, api);
    await openEditFromDetail(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'ana@x.local'), 'otro@x.local');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Ya existe un cliente con ese correo electrónico.'), findsOneWidget);
    expect(find.text('Editar cliente'), findsOneWidget);
    expect(clientes.ana['email'], 'ana@x.local');
  });

  testWidgets('test_telefono_de_otro_cliente_pide_confirmacion_y_reenvia_con_confirmDuplicatePhone', (tester) async {
    useDesktopWindow(tester);
    final clientes = EditableClients();
    final api = FakeApi(
      handler: clientes.handler(
        onPatch: (r) => r.body['confirmDuplicatePhone'] == true
            ? null
            : failure(409, 'PHONE_DUPLICATE', 'Ya existe un cliente con ese teléfono.', details: {
                'matches': [
                  {'id': 2, 'name': 'Luis Pérez', 'phone': '5533334444'},
                ],
              }),
      ),
    );
    await pumpAppSignedIn(tester, api);
    await openEditFromDetail(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '5512345678'), '5533334444');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Posible cliente duplicado'), findsOneWidget);
    expect(find.textContaining('Luis Pérez — 5533334444'), findsOneWidget);

    await tester.tap(dialogButton('Confirmar'));
    await tester.pumpAndSettle();

    final patches = api.requests.where((r) => r.method == 'PATCH' && r.path == '/clients/1').toList();
    expect(patches, hasLength(2));
    expect(patches.last.body['confirmDuplicatePhone'], isTrue);
    expect(find.text('Cliente actualizado correctamente.'), findsOneWidget);
  });

  testWidgets('test_cancelar_la_advertencia_de_telefono_no_guarda_y_sigue_en_el_formulario', (tester) async {
    useDesktopWindow(tester);
    final clientes = EditableClients();
    final api = FakeApi(
      handler: clientes.handler(
        onPatch: (r) => failure(409, 'PHONE_DUPLICATE', 'Ya existe un cliente con ese teléfono.', details: {
          'matches': [
            {'id': 2, 'name': 'Luis Pérez', 'phone': '5533334444'},
          ],
        }),
      ),
    );
    await pumpAppSignedIn(tester, api);
    await openEditFromDetail(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '5512345678'), '5533334444');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(dialogButton('Cancelar'));
    await tester.pumpAndSettle();

    expect(api.requests.where((r) => r.method == 'PATCH'), hasLength(1));
    expect(find.text('Editar cliente'), findsOneWidget);
    expect(clientes.ana['phone'], '5512345678');
  });

  testWidgets('test_salir_con_cambios_pide_confirmacion_y_sin_cambios_no', (tester) async {
    useDesktopWindow(tester);
    await pumpAppSignedIn(tester, FakeApi(handler: EditableClients().handler()));
    await openEditFromDetail(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Salir sin guardar'), findsNothing);
    expect(find.text('Detalle del cliente'), findsOneWidget);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Ana Morales'), 'Ana M.');
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Tienes cambios sin guardar. ¿Seguro que quieres salir?'), findsOneWidget);
  });

  testWidgets('test_el_listado_ofrece_editar_y_actualiza_la_fila_tras_guardar', (tester) async {
    useDesktopWindow(tester);
    final clientes = EditableClients();
    final api = FakeApi(handler: clientes.handler());
    await pumpAppSignedIn(tester, api);
    await openSection(tester, 'Clientes');

    await tester.tap(find.byTooltip('Editar a Ana Morales'));
    await tester.pumpAndSettle();
    expect(find.text('Editar cliente'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '5512345678'), '5577776666');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(api.requests.any((r) => r.method == 'PATCH' && r.body['phone'] == '5577776666'), isTrue);
    expect(find.text('Cliente actualizado correctamente.'), findsOneWidget);
    expect(find.text('Nuevo cliente'), findsOneWidget); // de vuelta en el listado
  });

  testWidgets('test_el_mecanico_no_ve_acciones_de_edicion_ni_en_el_listado_ni_en_el_detalle', (tester) async {
    useDesktopWindow(tester);
    await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: EditableClients().handler()));
    await openSection(tester, 'Clientes');

    expect(find.byTooltip('Editar a Ana Morales'), findsNothing);

    await tester.tap(find.text('Ana Morales'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle del cliente'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
  });
}
