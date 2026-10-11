import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

final _mio = {'id': 3, 'name': 'Mario Mecánico'};

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(label == 'Confirmar' || label == 'Guardar' ? FilledButton : OutlinedButton, label),
    );

/// Orden simulada con estado: las operaciones de trabajo cambian lo que devuelven las lecturas.
class FakeOrder {
  FakeOrder({this.status = 'EN_REPARACION'});

  String status;
  String? diagnosis;
  String? observations;
  String? recommendations;
  final List<Map<String, dynamic>> services = [];
  final List<Map<String, dynamic>> labor = [];
  int _nextId = 1;

  Map<String, dynamic> toJson() => orderDetailJson(
        1,
        status: status,
        mechanic: _mio,
        diagnosis: diagnosis,
        observations: observations,
        recommendations: recommendations,
        services: services,
        labor: labor,
      );

  FakeHandler handler() {
    return ordersHandler(
      items: [orderSummaryJson(1, status: status, mechanic: _mio)],
      extra: (r) {
        List<Map<String, dynamic>>? lines(String path) =>
            path.contains('/services') ? services : (path.contains('/labor') ? labor : null);

        if (r.method == 'GET' && r.path == '/orders/1') return ok(toJson());
        if (r.method == 'PATCH' && r.path == '/orders/1/work') {
          if (r.body.containsKey('diagnosis')) diagnosis = r.body['diagnosis'] as String?;
          if (r.body.containsKey('observations')) observations = r.body['observations'] as String?;
          if (r.body.containsKey('recommendations')) recommendations = r.body['recommendations'] as String?;
          return ok(toJson());
        }
        final list = lines(r.path);
        if (list != null && r.path.startsWith('/orders/1/')) {
          final match = RegExp(r'/(\d+)$').firstMatch(r.path);
          if (r.method == 'POST') {
            list.add(lineJson(_nextId++, '${r.body['description']}', double.parse('${r.body['amount']}').toStringAsFixed(2)));
            return created({'item': list.last, 'totals': toJson()['totals']});
          }
          if (r.method == 'PATCH' && match != null) {
            final i = list.indexWhere((l) => l['id'] == int.parse(match.group(1)!));
            list[i] = lineJson(list[i]['id'] as int, '${r.body['description']}', double.parse('${r.body['amount']}').toStringAsFixed(2));
            return ok({'item': list[i], 'totals': toJson()['totals']});
          }
          if (r.method == 'DELETE' && match != null) {
            list.removeWhere((l) => l['id'] == int.parse(match.group(1)!));
            return ok({'deleted': true, 'totals': toJson()['totals']});
          }
        }
        return null;
      },
    );
  }
}

Future<void> openOrder(WidgetTester tester, {String section = 'Mis órdenes'}) async {
  await openSection(tester, section);
  await tester.tap(find.text('OS-000001'));
  await tester.pumpAndSettle();
}

void main() {
  group('diagnóstico, observaciones y recomendaciones', () {
    testWidgets('test_el_mecanico_registra_el_diagnostico_y_se_guarda_en_la_orden', (tester) async {
      useDesktopWindow(tester);
      final order = FakeOrder();
      final api = FakeApi(role: 'MECHANIC', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);

      expect(find.text('Sin diagnóstico registrado.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('editar-diagnostico')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('texto-trabajo')), 'Balatas gastadas');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/orders/1/work');
      expect(patch.body, {'diagnosis': 'Balatas gastadas'});
      expect(find.text('Balatas gastadas'), findsOneWidget);
      expect(find.text('Información guardada correctamente.'), findsOneWidget);
    });

    testWidgets('test_cancelar_el_dialogo_no_llama_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: FakeOrder().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);

      await tester.tap(find.byKey(const ValueKey('editar-diagnostico')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('texto-trabajo')), 'No se guarda');
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);
    });

    testWidgets('test_vaciar_el_texto_envia_null_para_borrar_el_campo', (tester) async {
      useDesktopWindow(tester);
      final order = FakeOrder()..diagnosis = 'Anterior';
      final api = FakeApi(role: 'MECHANIC', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);

      await tester.tap(find.byKey(const ValueKey('editar-diagnostico')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('texto-trabajo')), '   ');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      expect(api.requests.firstWhere((r) => r.method == 'PATCH').body, {'diagnosis': null});
      expect(find.text('Sin diagnóstico registrado.'), findsOneWidget);
    });

    testWidgets('test_registra_observaciones_y_recomendaciones_por_separado', (tester) async {
      useDesktopWindow(tester);
      final order = FakeOrder();
      final api = FakeApi(role: 'MECHANIC', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('editar-observaciones')));
      await tester.tap(find.byKey(const ValueKey('editar-observaciones')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('texto-trabajo')), 'Disco rayado');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('editar-recomendaciones')));
      await tester.tap(find.byKey(const ValueKey('editar-recomendaciones')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('texto-trabajo')), 'Cambiar discos en 10,000 km');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      final bodies = api.requests.where((r) => r.method == 'PATCH').map((r) => r.body).toList();
      expect(bodies, [
        {'observations': 'Disco rayado'},
        {'recommendations': 'Cambiar discos en 10,000 km'},
      ]);
      expect(find.text('Disco rayado'), findsOneWidget);
      expect(find.text('Cambiar discos en 10,000 km'), findsOneWidget);
    });
  });

  group('servicios y mano de obra', () {
    testWidgets('test_valida_la_descripcion_y_el_importe_antes_de_llamar_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: FakeOrder().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('agregar-servicio')));
      await tester.tap(find.byKey(const ValueKey('agregar-servicio')));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Guardar'));
      await tester.pump();
      expect(find.text('La descripción es obligatoria.'), findsOneWidget);
      expect(find.text('El importe es obligatorio.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('linea-descripcion')), 'Cambio de balatas');
      for (final (texto, mensaje) in [
        ('-5', 'El importe no puede ser negativo.'),
        ('abc', 'El importe debe ser un número.'),
        ('10.555', 'El importe admite hasta dos decimales.'),
        ('10000000', 'El importe no puede pasar de 9,999,999.99.'),
      ]) {
        await tester.enterText(find.byKey(const ValueKey('linea-importe')), texto);
        await tester.tap(dialogButton('Guardar'));
        await tester.pump();
        expect(find.text(mensaje), findsOneWidget, reason: texto);
      }
      expect(api.requests.where((r) => r.method == 'POST' && r.path.startsWith('/orders')), isEmpty);
    });

    testWidgets('test_agrega_un_servicio_y_se_actualizan_las_lineas_y_los_totales', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: FakeOrder().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('agregar-servicio')));
      await tester.tap(find.byKey(const ValueKey('agregar-servicio')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('linea-descripcion')), 'Cambio de balatas');
      await tester.enterText(find.byKey(const ValueKey('linea-importe')), '850');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/orders/1/services');
      expect(post.body, {'description': 'Cambio de balatas', 'amount': '850'});
      expect(find.text('Cambio de balatas'), findsOneWidget);
      expect(find.text('\$850.00'), findsWidgets);
      expect(find.text('Línea agregada correctamente.'), findsOneWidget);
    });

    testWidgets('test_agrega_mano_de_obra_a_su_propia_seccion_y_suma_el_total', (tester) async {
      useDesktopWindow(tester);
      final order = FakeOrder();
      order.services.add(lineJson(90, 'Cambio de aceite', '500.00'));
      final api = FakeApi(role: 'MECHANIC', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('agregar-mano-de-obra')));
      await tester.tap(find.byKey(const ValueKey('agregar-mano-de-obra')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('linea-descripcion')), 'Mano de obra aceite');
      await tester.enterText(find.byKey(const ValueKey('linea-importe')), '150.50');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      expect(api.requests.any((r) => r.method == 'POST' && r.path == '/orders/1/labor'), isTrue);
      expect(find.text('\$650.50'), findsOneWidget);
    });

    testWidgets('test_corrige_una_linea_existente', (tester) async {
      useDesktopWindow(tester);
      final order = FakeOrder();
      order.services.add(lineJson(5, 'Cambio de balatas', '850.00'));
      final api = FakeApi(role: 'MECHANIC', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('editar-services-5')));
      await tester.tap(find.byKey(const ValueKey('editar-services-5')));
      await tester.pumpAndSettle();
      expect(find.text('Editar servicio'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('linea-importe')), '900');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/orders/1/services/5');
      expect(patch.body, {'description': 'Cambio de balatas', 'amount': '900'});
      expect(find.text('Línea actualizada correctamente.'), findsOneWidget);
    });

    testWidgets('test_quitar_una_linea_pide_confirmacion_y_cancelar_no_llama_a_la_api', (tester) async {
      useDesktopWindow(tester);
      final order = FakeOrder();
      order.labor.add(lineJson(7, 'Mano de obra frenos', '400.00'));
      final api = FakeApi(role: 'MECHANIC', handler: order.handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('quitar-labor-7')));
      await tester.tap(find.byKey(const ValueKey('quitar-labor-7')));
      await tester.pumpAndSettle();
      expect(find.text('Quitar línea'), findsOneWidget);
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);

      await tester.tap(find.byKey(const ValueKey('quitar-labor-7')));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Confirmar'));
      await tester.pumpAndSettle();

      expect(api.requests.any((r) => r.method == 'DELETE' && r.path == '/orders/1/labor/7'), isTrue);
      expect(find.text('Sin mano de obra registrada.'), findsOneWidget);
      expect(find.text('Línea quitada correctamente.'), findsOneWidget);
    });

    testWidgets('test_muestra_el_error_del_servidor_si_la_orden_ya_fue_entregada', (tester) async {
      useDesktopWindow(tester);
      final order = FakeOrder();
      final base = order.handler();
      final api = FakeApi(
        role: 'MECHANIC',
        handler: (r) {
          if (r.method == 'POST' && r.path == '/orders/1/services') {
            return failure(409, 'ORDER_READ_ONLY', 'La orden está entregada: es de solo lectura y no admite cambios.');
          }
          return base(r);
        },
      );
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('agregar-servicio')));
      await tester.tap(find.byKey(const ValueKey('agregar-servicio')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('linea-descripcion')), 'Tarde');
      await tester.enterText(find.byKey(const ValueKey('linea-importe')), '10');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('La orden está entregada: es de solo lectura y no admite cambios.'), findsOneWidget);
    });
  });

  group('permisos y solo lectura', () {
    testWidgets('test_recepcion_no_ve_las_acciones_de_edicion_del_trabajo', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: FakeOrder().handler()));
      await openOrder(tester, section: 'Órdenes');

      expect(find.byKey(const ValueKey('editar-diagnostico')), findsNothing);
      expect(find.byKey(const ValueKey('agregar-servicio')), findsNothing);
      expect(find.byKey(const ValueKey('agregar-mano-de-obra')), findsNothing);
      expect(find.byKey(const ValueKey('editar-observaciones')), findsNothing);
    });

    testWidgets('test_el_administrador_si_ve_las_acciones_de_edicion', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: FakeOrder().handler()));
      await openOrder(tester, section: 'Órdenes');

      expect(find.byKey(const ValueKey('editar-diagnostico')), findsOneWidget);
      expect(find.byKey(const ValueKey('agregar-servicio')), findsOneWidget);
    });

    testWidgets('test_una_orden_entregada_es_de_solo_lectura_y_lo_avisa', (tester) async {
      useDesktopWindow(tester);
      final order = FakeOrder(status: 'ENTREGADO')
        ..diagnosis = 'Listo'
        ..services.add(lineJson(1, 'Cambio de aceite', '500.00'));
      await pumpAppSignedIn(tester, FakeApi(role: 'MECHANIC', handler: order.handler()));
      await openSection(tester, 'Mis órdenes');
      await tester.tap(find.byKey(const ValueKey('filtro-estado-orden')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entregado').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OS-000001'));
      await tester.pumpAndSettle();

      expect(find.text('Orden entregada: solo lectura.'), findsOneWidget);
      expect(find.byKey(const ValueKey('editar-diagnostico')), findsNothing);
      expect(find.byKey(const ValueKey('agregar-servicio')), findsNothing);
      expect(find.byKey(const ValueKey('editar-services-1')), findsNothing);
      expect(find.byKey(const ValueKey('quitar-services-1')), findsNothing);
    });
  });
}
