import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

final _mio = {'id': 3, 'name': 'Mario Mecánico'};

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(label == 'Confirmar' || label == 'Guardar' ? FilledButton : OutlinedButton, label),
    );

Map<String, dynamic> maintenanceJson({String status = 'PENDIENTE', String? indicator = 'NORMAL'}) => {
      'id': 5,
      'description': 'Cambio de aceite',
      'dueDate': '2031-03-20',
      'dueMileage': 60000,
      'status': status,
      'indicator': status == 'PENDIENTE' ? indicator : null,
    };

/// Orden simulada con estado propio: registrar el kilometraje o el mantenimiento cambia las lecturas.
class FakeFinishedOrder {
  FakeFinishedOrder({this.status = 'TERMINADO', this.maintenance});

  String status;
  int? serviceMileage;
  Map<String, dynamic>? maintenance;

  Map<String, dynamic> toJson() => orderDetailJson(
        1,
        status: status,
        mechanic: _mio,
        serviceMileage: serviceMileage,
        maintenance: maintenance,
      );

  FakeHandler handler() => ordersHandler(
        items: [orderSummaryJson(1, status: status, mechanic: _mio)],
        extra: (r) {
          if (r.method == 'GET' && r.path == '/orders/1') return ok(toJson());
          if (r.method == 'PUT' && r.path == '/orders/1/service-mileage') {
            final value = r.body['serviceMileage'] as int;
            if (value < 51200) {
              return failure(422, 'SERVICE_MILEAGE_TOO_LOW', 'El kilometraje del servicio (50000 km) no puede ser menor al de entrada (51200 km).');
            }
            serviceMileage = value;
            return ok(toJson());
          }
          if (r.method == 'POST' && r.path == '/orders/1/maintenance') {
            maintenance = {...maintenanceJson(), 'description': r.body['description'], 'dueDate': r.body['dueDate'], 'dueMileage': r.body['dueMileage']};
            return created(maintenance!);
          }
          if (r.method == 'PATCH' && r.path == '/maintenance/5') {
            maintenance = {...maintenance!, ...r.body};
            return ok(maintenance!);
          }
          if (r.method == 'POST' && r.path == '/maintenance/5/attend') {
            maintenance = maintenanceJson(status: 'ATENDIDO');
            return ok(maintenance!);
          }
          return null;
        },
      );
}

Future<void> openOrder(WidgetTester tester, {String section = 'Mis órdenes'}) async {
  await openSection(tester, section);
  await tester.tap(find.text('OS-000001'));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).last);

void main() {
  group('kilometraje del servicio', () {
    testWidgets('test_el_mecanico_registra_el_kilometraje_y_se_muestra', (tester) async {
      useDesktopWindow(tester);
      final order = FakeFinishedOrder();
      final api = FakeApi(role: 'MECHANIC', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('registrar-kilometraje')));

      expect(find.text('Sin registrar.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('registrar-kilometraje')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('km-servicio')), '51400');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      final put = api.requests.firstWhere((r) => r.method == 'PUT' && r.path == '/orders/1/service-mileage');
      expect(put.body, {'serviceMileage': 51400});
      await scrollTo(tester, find.byKey(const ValueKey('kilometraje-servicio')));
      expect(find.text('51,400 km'), findsWidgets);
      expect(find.text('Kilometraje del servicio guardado correctamente.'), findsOneWidget);
    });

    testWidgets('test_un_kilometraje_menor_al_de_entrada_se_rechaza_en_el_formulario_sin_llamar_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: FakeFinishedOrder().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('registrar-kilometraje')));

      await tester.tap(find.byKey(const ValueKey('registrar-kilometraje')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('km-servicio')), '50000');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No puede ser menor al kilometraje de entrada'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'PUT'), isEmpty);
    });

    testWidgets('test_la_orden_entregada_no_ofrece_registrar_kilometraje', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: FakeFinishedOrder(status: 'ENTREGADO').handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester, section: 'Mis órdenes');
      // Las entregadas no aparecen en "Mis órdenes" por defecto: se abre con el filtro de estado.
      expect(find.byKey(const ValueKey('registrar-kilometraje')), findsNothing);
    });
  });

  group('próximo mantenimiento', () {
    testWidgets('test_exige_al_menos_fecha_o_kilometraje', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: FakeFinishedOrder().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('programar-mantenimiento')));

      await tester.tap(find.byKey(const ValueKey('programar-mantenimiento')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('mantenimiento-descripcion')), 'Cambio de aceite');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mantenimiento-objetivo-error')), findsOneWidget);
      expect(find.text('Indica una fecha, un kilometraje o ambos.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/orders/1/maintenance'), isEmpty);
    });

    testWidgets('test_programa_el_mantenimiento_con_kilometraje_y_lo_muestra', (tester) async {
      useDesktopWindow(tester);
      final order = FakeFinishedOrder();
      final api = FakeApi(role: 'MECHANIC', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('programar-mantenimiento')));

      expect(find.text('Sin mantenimiento programado.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('programar-mantenimiento')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('mantenimiento-descripcion')), 'Cambio de aceite');
      await tester.enterText(find.byKey(const ValueKey('mantenimiento-kilometraje')), '60000');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/orders/1/maintenance');
      expect(post.body, {'description': 'Cambio de aceite', 'dueDate': null, 'dueMileage': 60000});
      await scrollTo(tester, find.text('Cambio de aceite'));
      expect(find.text('Cambio de aceite'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Próximo mantenimiento programado correctamente.'), findsOneWidget);
    });

    testWidgets('test_rechaza_una_fecha_con_formato_invalido', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: FakeFinishedOrder().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('programar-mantenimiento')));

      await tester.tap(find.byKey(const ValueKey('programar-mantenimiento')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('mantenimiento-descripcion')), 'Revisión');
      await tester.enterText(find.byKey(const ValueKey('mantenimiento-fecha')), '20/03/2031');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Usa el formato AAAA-MM-DD.'), findsOneWidget);
    });

    testWidgets('test_marcar_como_atendido_pide_confirmacion', (tester) async {
      useDesktopWindow(tester);
      final order = FakeFinishedOrder(maintenance: maintenanceJson());
      final api = FakeApi(role: 'MECHANIC', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('atender-mantenimiento')));

      await tester.tap(find.byKey(const ValueKey('atender-mantenimiento')));
      await tester.pumpAndSettle();
      expect(find.text('Marcar como atendido'), findsWidgets);
      expect(api.requests.where((r) => r.path == '/maintenance/5/attend'), isEmpty);

      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.path == '/maintenance/5/attend'), isEmpty);

      await tester.tap(find.byKey(const ValueKey('atender-mantenimiento')));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Confirmar'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/maintenance/5/attend'), hasLength(1));
      await scrollTo(tester, find.text('Atendido'));
      expect(find.text('Atendido'), findsOneWidget);
      expect(find.byKey(const ValueKey('atender-mantenimiento')), findsNothing);
    });

    testWidgets('test_la_recepcion_ve_el_mantenimiento_pero_sin_acciones', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'RECEPTIONIST', handler: FakeFinishedOrder(maintenance: maintenanceJson(indicator: 'VENCIDO')).handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester, section: 'Órdenes');
      await scrollTo(tester, find.text('Vencido'));

      expect(find.text('Cambio de aceite'), findsOneWidget);
      expect(find.text('Vencido'), findsOneWidget);
      expect(find.byKey(const ValueKey('programar-mantenimiento')), findsNothing);
      expect(find.byKey(const ValueKey('editar-mantenimiento')), findsNothing);
      expect(find.byKey(const ValueKey('atender-mantenimiento')), findsNothing);
      expect(find.byKey(const ValueKey('registrar-kilometraje')), findsNothing);
    });

    testWidgets('test_la_orden_entregada_permite_programar_pero_no_registrar_kilometraje', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'ADMIN', handler: FakeFinishedOrder(status: 'ENTREGADO').handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester, section: 'Órdenes');
      await scrollTo(tester, find.byKey(const ValueKey('programar-mantenimiento')));

      expect(find.byKey(const ValueKey('programar-mantenimiento')), findsOneWidget);
      expect(find.byKey(const ValueKey('registrar-kilometraje')), findsNothing);
    });
  });
}
