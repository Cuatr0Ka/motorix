import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(label == 'Confirmar' ? FilledButton : OutlinedButton, label),
    );

Future<void> chooseClientAndVehicle(WidgetTester tester) async {
  await tester.tap(find.text('Cliente *'));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Luis Pérez')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Vehículo *'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('vehiculo-opcion-2')));
  await tester.pumpAndSettle();
}

Future<void> chooseDateTime(WidgetTester tester) async {
  await tester.tap(find.text('Fecha y hora *'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Aceptar')); // fecha propuesta (mañana)
  await tester.pumpAndSettle();
  await tester.tap(find.text('Aceptar')); // hora propuesta
  await tester.pumpAndSettle();
}

void main() {
  group('listado de citas', () {
    testWidgets('test_muestra_las_citas_con_su_cliente_vehiculo_y_estado', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(handler: appointmentsHandler()));
      await openSection(tester, 'Citas');

      expect(find.text('Ana Morales'), findsOneWidget);
      expect(find.text('Luis Pérez'), findsOneWidget);
      expect(find.text('MNO-345-E'), findsOneWidget);
      expect(find.text('Pendiente'), findsWidgets);
      expect(find.text('Confirmada'), findsWidgets);
      expect(find.text('1–2 de 2'), findsNothing);
    });

    testWidgets('test_muestra_el_estado_vacio_con_accion_para_registrar', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(handler: appointmentsHandler(items: [])));
      await openSection(tester, 'Citas');

      expect(find.text('Todavía no hay citas registradas.'), findsOneWidget);
      expect(find.text('Registrar la primera cita'), findsOneWidget);
    });

    testWidgets('test_el_filtro_de_estado_pide_solo_las_citas_de_ese_estado', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: appointmentsHandler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Citas');

      await tester.tap(find.byKey(const ValueKey('filtro-estado-cita')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmada').last);
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.path == '/appointments').last.query['status'], 'CONFIRMADA');
      expect(find.text('Luis Pérez'), findsOneWidget);
      expect(find.text('Ana Morales'), findsNothing);
    });

    testWidgets('test_confirmar_una_cita_pendiente_llama_a_la_api_y_avisa', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: appointmentsHandler(
          extra: (r) => r.method == 'POST' && r.path == '/appointments/1/confirm'
              ? ok(appointmentJson(1, status: 'CONFIRMADA'))
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Citas');

      await tester.tap(find.byKey(const ValueKey('confirmar-cita-1')));
      await tester.pumpAndSettle();

      expect(api.requests.any((r) => r.method == 'POST' && r.path == '/appointments/1/confirm'), isTrue);
      expect(find.text('Cita confirmada.'), findsOneWidget);
    });

    testWidgets('test_cancelar_pide_confirmacion_y_volver_no_llama_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: appointmentsHandler());
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Citas');

      await tester.tap(find.byKey(const ValueKey('cancelar-cita-1')));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar cita'), findsOneWidget);
      await tester.tap(dialogButton('Volver'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.path.endsWith('/cancel')), isEmpty);
    });

    testWidgets('test_cancelar_con_motivo_envia_el_motivo_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: appointmentsHandler(
          extra: (r) => r.method == 'POST' && r.path == '/appointments/1/cancel'
              ? ok(appointmentJson(1, status: 'CANCELADA'))
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Citas');

      await tester.tap(find.byKey(const ValueKey('cancelar-cita-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('motivo-cancelacion')), 'El cliente reprogramó');
      await tester.tap(dialogButton('Confirmar'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.path == '/appointments/1/cancel');
      expect(post.body['reason'], 'El cliente reprogramó');
      expect(find.text('Cita cancelada.'), findsOneWidget);
    });

    testWidgets('test_las_citas_canceladas_no_ofrecen_confirmar_ni_cancelar', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(
        tester,
        FakeApi(handler: appointmentsHandler(items: [appointmentJson(5, status: 'CANCELADA')])),
      );
      await openSection(tester, 'Citas');

      expect(find.byKey(const ValueKey('confirmar-cita-5')), findsNothing);
      expect(find.byKey(const ValueKey('cancelar-cita-5')), findsNothing);
    });
  });

  group('formulario de cita', () {
    Future<void> openForm(WidgetTester tester) async {
      await openSection(tester, 'Citas');
      await tester.tap(find.text('Nueva cita'));
      await tester.pumpAndSettle();
    }

    testWidgets('test_exige_cliente_vehiculo_fecha_y_motivo_sin_llamar_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: appointmentsHandler());
      await pumpAppSignedIn(tester, api);
      await openForm(tester);

      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(find.text('Selecciona un cliente.'), findsOneWidget);
      expect(find.text('Selecciona un vehículo.'), findsOneWidget);
      expect(find.text('Elige la fecha y la hora.'), findsOneWidget);
      expect(find.text('El motivo es obligatorio.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/appointments'), isEmpty);
    });

    testWidgets('test_el_vehiculo_se_filtra_por_el_cliente_elegido', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(handler: appointmentsHandler());
      await pumpAppSignedIn(tester, api);
      await openForm(tester);

      await tester.tap(find.text('Cliente *'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Luis Pérez')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vehículo *'));
      await tester.pumpAndSettle();

      expect(find.text('Elegir vehículo'), findsOneWidget);
      expect(api.requests.where((r) => r.path == '/vehicles').last.query['clientId'], '2');
      expect(find.textContaining('DEF-456-B'), findsOneWidget);
      expect(find.textContaining('MNO-345-E'), findsNothing);
    });

    testWidgets('test_registra_la_cita_con_fecha_hora_y_motivo_y_avisa', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: appointmentsHandler(
          extra: (r) => r.method == 'POST' && r.path == '/appointments'
              ? created(appointmentJson(9, clientId: 2, clientName: 'Luis Pérez', plate: 'DEF-456-B'))
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openForm(tester);

      await chooseClientAndVehicle(tester);
      await chooseDateTime(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Motivo *'), 'Cambio de aceite');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/appointments');
      expect(post.body['clientId'], 2);
      expect(post.body['vehicleId'], 2);
      expect(post.body['reason'], 'Cambio de aceite');
      expect(DateTime.parse(post.body['scheduledAt'] as String).isAfter(DateTime.now()), isTrue);
      expect(find.text('Cita registrada correctamente.'), findsOneWidget);
    });

    testWidgets('test_muestra_el_error_de_horario_ocupado_en_el_campo_de_fecha', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: appointmentsHandler(
          extra: (r) => r.method == 'POST' && r.path == '/appointments'
              ? failure(409, 'APPOINTMENT_SLOT_TAKEN', 'Ese vehículo ya tiene una cita activa en esa fecha y hora.')
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openForm(tester);

      await chooseClientAndVehicle(tester);
      await chooseDateTime(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Motivo *'), 'Afinación');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Ese vehículo ya tiene una cita activa en esa fecha y hora.'), findsOneWidget);
    });
  });

  group('permisos', () {
    testWidgets('test_el_mecanico_no_ve_la_seccion_citas', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: appointmentsHandler()));

      expect(
        find.descendant(of: find.byType(NavigationRail), matching: find.text('Citas')),
        findsNothing,
      );
    });
  });

  group('detalle de cita', () {
    testWidgets('test_muestra_los_datos_y_las_acciones_de_una_cita_pendiente', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: appointmentsHandler(
          extra: (r) => r.method == 'GET' && r.path == '/appointments/1' ? ok(appointmentJson(1, notes: 'Llega temprano')) : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Citas');
      await tester.tap(find.text('Servicio de 50 000 km'));
      await tester.pumpAndSettle();

      expect(find.text('Detalle de la cita'), findsOneWidget);
      expect(find.text('Llega temprano'), findsOneWidget);
      expect(find.byKey(const ValueKey('confirmar-cita')), findsOneWidget);
      expect(find.byKey(const ValueKey('cancelar-cita')), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
    });

    testWidgets('test_una_cita_completada_no_muestra_acciones_de_edicion', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(
        handler: appointmentsHandler(
          items: [appointmentJson(3, status: 'COMPLETADA')],
          extra: (r) => r.method == 'GET' && r.path == '/appointments/3'
              ? ok(appointmentJson(3, status: 'COMPLETADA', order: {'id': 4, 'folio': 'OS-000004', 'status': 'TERMINADO'}))
              : null,
        ),
      );
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Citas');
      await tester.tap(find.text('Servicio de 50 000 km'));
      await tester.pumpAndSettle();

      expect(find.text('OS-000004 · Terminado'), findsOneWidget);
      expect(find.byKey(const ValueKey('cancelar-cita')), findsNothing);
      expect(find.text('Editar'), findsNothing);
    });
  });
}
