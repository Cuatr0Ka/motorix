import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

final _mio = {'id': 3, 'name': 'Mario Mecánico'};

Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(label == 'Confirmar' || label == 'Guardar' ? FilledButton : OutlinedButton, label),
    );

Map<String, dynamic> typeJson(int id, String name, {int? days, int? km, bool active = true, int inUse = 0}) =>
    {'id': id, 'name': name, 'intervalDays': days, 'intervalKm': km, 'active': active, 'inUse': inUse};

/// API simulada del catálogo de tipos de servicio y de una orden con líneas de servicio.
class FakeTypes {
  FakeTypes({List<Map<String, dynamic>>? types, this.suggestion, this.status = 'EN_REPARACION'})
      : types = types ?? [typeJson(1, 'Cambio de aceite', days: 180, km: 5000, inUse: 2), typeJson(2, 'Afinación', km: 10000, active: false)];

  final List<Map<String, dynamic>> types;
  final Map<String, dynamic>? suggestion;
  final String status;
  final List<Map<String, dynamic>> services = [];
  int _nextId = 1;

  FakeHandler handler() => ordersHandler(
        items: [orderSummaryJson(1, status: status, mechanic: _mio)],
        extra: (r) {
          if (r.path == '/service-types' && r.method == 'GET') return ok(types);
          if (r.path == '/service-types/options') return ok(types.where((t) => t['active'] == true).toList());
          if (r.path == '/service-types' && r.method == 'POST') {
            types.add(typeJson(types.length + 1, '${r.body['name']}', days: r.body['intervalDays'] as int?, km: r.body['intervalKm'] as int?));
            return created(types.last);
          }
          final patch = RegExp(r'^/service-types/(\d+)$').firstMatch(r.path);
          if (patch != null && r.method == 'PATCH') {
            final i = types.indexWhere((t) => t['id'] == int.parse(patch.group(1)!));
            types[i] = {...types[i], ...r.body};
            return ok(types[i]);
          }
          if (r.method == 'GET' && r.path == '/orders/1') {
            return ok(orderDetailJson(1, status: status, mechanic: _mio, services: services));
          }
          if (r.method == 'GET' && r.path == '/orders/1/maintenance/suggestion') {
            return suggestion == null ? http.Response('', 204) : ok(suggestion!);
          }
          if (r.method == 'POST' && r.path == '/orders/1/services') {
            final id = r.body['serviceTypeId'] as int?;
            final type = id == null ? null : types.firstWhere((t) => t['id'] == id);
            services.add({
              ...lineJson(_nextId++, '${r.body['description']}', double.parse('${r.body['amount']}').toStringAsFixed(2)),
              'serviceType': type == null ? null : {'id': type['id'], 'name': type['name']},
            });
            return created({'item': services.last, 'totals': orderDetailJson(1, services: services)['totals']});
          }
          return null;
        },
      );
}

Future<void> openOrder(WidgetTester tester) async {
  await openSection(tester, 'Mis órdenes');
  await tester.tap(find.text('OS-000001'));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).last);

Future<void> openTypesTab(WidgetTester tester, FakeApi api) async {
  useDesktopWindow(tester);
  await pumpAppSignedIn(tester, api);
  await openSection(tester, 'Configuración');
  await tester.tap(find.byKey(const ValueKey('pestana-tipos-servicio')));
  await tester.pumpAndSettle();
}

void main() {
  group('pestaña Tipos de servicio (US3)', () {
    testWidgets('test_lista_nombre_dias_km_y_estado_con_el_chip', (tester) async {
      final api = FakeApi(role: 'ADMIN', handler: FakeTypes().handler());
      await openTypesTab(tester, api);

      expect(find.text('Cambio de aceite'), findsOneWidget);
      expect(find.text('Afinación'), findsOneWidget);
      expect(find.text('Activo'), findsOneWidget);
      expect(find.text('Inactivo'), findsOneWidget);
      expect(find.textContaining('Días: 180 · Km: 5000'), findsOneWidget);
      expect(find.textContaining('Días: — · Km: 10000'), findsOneWidget);
    });

    testWidgets('test_sin_tipos_muestra_el_estado_vacio', (tester) async {
      final api = FakeApi(role: 'ADMIN', handler: FakeTypes(types: []).handler());
      await openTypesTab(tester, api);

      expect(find.text('Todavía no hay tipos de servicio'), findsOneWidget);
    });

    testWidgets('test_nuevo_tipo_valida_el_nombre_y_que_haya_un_intervalo', (tester) async {
      final api = FakeApi(role: 'ADMIN', handler: FakeTypes().handler());
      await openTypesTab(tester, api);

      await tester.tap(find.byKey(const ValueKey('nuevo-tipo-servicio')));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('El nombre es obligatorio.'), findsOneWidget);
      expect(find.byKey(const ValueKey('tipo-intervalo-error')), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/service-types'), isEmpty);
    });

    testWidgets('test_crea_un_tipo_y_aparece_en_la_lista', (tester) async {
      final api = FakeApi(role: 'ADMIN', handler: FakeTypes().handler());
      await openTypesTab(tester, api);

      await tester.tap(find.byKey(const ValueKey('nuevo-tipo-servicio')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('tipo-nombre')), 'Revisión de frenos');
      await tester.enterText(find.byKey(const ValueKey('tipo-dias')), '90');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/service-types');
      expect(post.body, {'name': 'Revisión de frenos', 'intervalDays': 90, 'intervalKm': null});
      expect(find.text('Revisión de frenos'), findsOneWidget);
      expect(find.text('Tipo de servicio creado correctamente.'), findsOneWidget);
    });

    testWidgets('test_desactivar_pide_confirmacion_y_las_ordenes_anteriores_conservan_el_tipo', (tester) async {
      final api = FakeApi(role: 'ADMIN', handler: FakeTypes().handler());
      await openTypesTab(tester, api);

      await tester.tap(find.byKey(const ValueKey('estado-tipo-1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Las órdenes anteriores conservan el tipo'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'PATCH' && r.path.startsWith('/service-types')), isEmpty);

      await tester.tap(dialogButton('Confirmar'));
      await tester.pumpAndSettle();

      final patch = api.requests.firstWhere((r) => r.method == 'PATCH' && r.path == '/service-types/1');
      expect(patch.body, {'active': false});
      expect(find.text('Tipo de servicio desactivado.'), findsOneWidget);
    });

    testWidgets('test_un_error_del_servidor_se_muestra_sin_perder_el_formulario', (tester) async {
      final fake = FakeTypes();
      final inner = fake.handler();
      final api = FakeApi(
        role: 'ADMIN',
        handler: (r) => r.method == 'POST' && r.path == '/service-types'
            ? failure(409, 'SERVICE_TYPE_DUPLICATE', 'Ya existe un tipo de servicio con ese nombre.')
            : inner(r),
      );
      await openTypesTab(tester, api);

      await tester.tap(find.byKey(const ValueKey('nuevo-tipo-servicio')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('tipo-nombre')), 'Cambio de aceite');
      await tester.enterText(find.byKey(const ValueKey('tipo-km')), '5000');
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Ya existe un tipo de servicio con ese nombre.'), findsOneWidget);
    });
  });

  group('tipo de servicio en las líneas de la orden (US3)', () {
    testWidgets('test_el_formulario_de_servicio_ofrece_el_selector_con_los_tipos_activos', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: FakeTypes().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('agregar-servicio')));
      await tester.tap(find.byKey(const ValueKey('agregar-servicio')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('linea-tipo-servicio')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('linea-tipo-servicio')));
      await tester.pumpAndSettle();
      expect(find.text('Cambio de aceite').last, findsOneWidget);
      expect(find.text('Afinación'), findsNothing); // desactivado: no se ofrece
      expect(find.text('Sin tipo'), findsWidgets);
    });

    testWidgets('test_elegir_un_tipo_lo_envia_y_se_muestra_el_chip_en_la_linea', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: FakeTypes().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('agregar-servicio')));
      await tester.tap(find.byKey(const ValueKey('agregar-servicio')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('linea-descripcion')), 'Cambio de aceite sintético');
      await tester.enterText(find.byKey(const ValueKey('linea-importe')), '650');
      await tester.tap(find.byKey(const ValueKey('linea-tipo-servicio')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambio de aceite').last);
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Guardar'));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/orders/1/services');
      expect(post.body, {'description': 'Cambio de aceite sintético', 'amount': '650', 'serviceTypeId': 1});
      expect(find.byKey(const ValueKey('tipo-servicio-1')), findsOneWidget);
    });

    testWidgets('test_la_mano_de_obra_no_ofrece_tipo_de_servicio', (tester) async {
      useDesktopWindow(tester);
      final api = FakeApi(role: 'MECHANIC', handler: FakeTypes().handler());
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('agregar-mano-de-obra')));
      await tester.tap(find.byKey(const ValueKey('agregar-mano-de-obra')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('linea-tipo-servicio')), findsNothing);
    });
  });

  group('Usar el intervalo del servicio (US3)', () {
    Future<void> openDialog(WidgetTester tester, FakeApi api) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, api);
      await openOrder(tester);
      await scrollTo(tester, find.byKey(const ValueKey('programar-mantenimiento')));
      await tester.tap(find.byKey(const ValueKey('programar-mantenimiento')));
      await tester.pumpAndSettle();
    }

    testWidgets('test_rellena_fecha_y_kilometraje_con_la_propuesta', (tester) async {
      final fake = FakeTypes(
        status: 'TERMINADO',
        suggestion: {
          'dueDate': '2031-05-20',
          'dueMileage': 55000,
          'basedOn': [
            {'serviceTypeId': 1, 'name': 'Cambio de aceite'},
          ],
        },
      );
      await openDialog(tester, FakeApi(role: 'MECHANIC', handler: fake.handler()));

      await tester.tap(find.byKey(const ValueKey('usar-intervalo')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, '2031-05-20'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '55000'), findsOneWidget);
      expect(find.textContaining('Propuesta basada en: Cambio de aceite'), findsOneWidget);
    });

    testWidgets('test_sin_propuesta_explica_que_ningun_servicio_tiene_intervalo', (tester) async {
      final fake = FakeTypes(status: 'TERMINADO');
      await openDialog(tester, FakeApi(role: 'MECHANIC', handler: fake.handler()));

      await tester.tap(find.byKey(const ValueKey('usar-intervalo')));
      await tester.pumpAndSettle();

      expect(find.text('Ningún servicio de la orden tiene un intervalo.'), findsOneWidget);
    });
  });
}
