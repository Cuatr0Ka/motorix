import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:motorix_client/models/report.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

/// API simulada de reportes: guarda el periodo pedido y entrega datos de ejemplo o vacíos.
class FakeReports {
  bool empty = false;
  bool failingIncome = false;
  final List<FakeRequest> exports = [];

  FakeHandler handler() => (r) {
        if (r.method != 'GET' || !r.path.startsWith('/reports/')) return null;
        final name = r.path.substring('/reports/'.length);
        if (r.query['format'] == 'xlsx') {
          exports.add(r);
          return http.Response.bytes(
            [80, 75, 3, 4],
            200,
            headers: {
              'content-type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              'content-disposition': 'attachment; filename="reporte-$name-${r.query['from']}_${r.query['to']}.xlsx"',
            },
          );
        }
        final base = {'from': r.query['from'], 'to': r.query['to']};
        switch (name) {
          case 'income':
            if (failingIncome) return failure(500, 'INTERNAL_ERROR', 'Ocurrió un error inesperado.');
            return ok({
              ...base,
              'total': empty ? '0.00' : '1250.75',
              'paymentsCount': empty ? 0 : 2,
              'byMethod': empty
                  ? []
                  : [
                      {'method': 'EFECTIVO', 'payments': 1, 'total': '1000.50'},
                      {'method': 'TARJETA', 'payments': 1, 'total': '250.25'},
                    ],
              'byDay': empty
                  ? []
                  : [
                      {'day': '2026-10-02', 'payments': 1, 'total': '1000.50'},
                      {'day': '2026-10-05', 'payments': 1, 'total': '250.25'},
                    ],
            });
          case 'services':
            return ok({
              ...base,
              'items': empty
                  ? []
                  : [
                      {'name': 'Cambio de aceite', 'times': 9, 'amount': '4500.00'},
                      {'name': 'Balatas', 'times': 3, 'amount': '2550.00'},
                    ],
            });
          case 'productivity':
            return ok({
              ...base,
              'items': empty
                  ? []
                  : [
                      {'mechanicId': 3, 'name': 'Segundo mecánico', 'ordersFinished': 7, 'laborAmount': '3150.00'},
                    ],
            });
          case 'parts':
            return ok({
              ...base,
              'items': empty
                  ? []
                  : [
                      {'partId': 4, 'code': 'BAL-DEL', 'name': 'Balatas delanteras', 'units': 6, 'revenue': '4680.00', 'cost': '3120.00', 'margin': '1560.00', 'marginPercent': '33.33', 'noCost': false},
                      {'partId': 5, 'code': 'ACE-1', 'name': 'Aceite sintético', 'units': 2, 'revenue': '600.00', 'cost': null, 'margin': null, 'marginPercent': null, 'noCost': true},
                    ],
              'totals': {'revenue': empty ? '0.00' : '5280.00', 'cost': empty ? '0.00' : '3120.00', 'margin': empty ? '0.00' : '1560.00', 'marginPercent': empty ? null : '33.33', 'noCostLines': empty ? 0 : 1},
            });
          case 'rotation':
            return ok({
              ...base,
              'items': empty
                  ? []
                  : [
                      {'partId': 4, 'code': 'BAL-DEL', 'name': 'Balatas delanteras', 'out': 12, 'stockStart': 20, 'stockEnd': 8, 'averageStock': '14.00', 'rotation': '0.86'},
                    ],
            });
        }
        return null;
      };
}

Future<FakeApi> openReports(WidgetTester tester, FakeReports fake, {FakeFileSaver? saver, FakeLinkOpener? opener, String role = 'ADMIN'}) async {
  useDesktopWindow(tester);
  final api = FakeApi(role: role, handler: fake.handler());
  await pumpAppSignedIn(tester, api, fileSaver: saver, linkOpener: opener);
  if (role == 'ADMIN') await openSection(tester, 'Reportes');
  return api;
}

List<FakeRequest> pedidos(FakeApi api, String name) => api.requests.where((r) => r.path == '/reports/$name' && !r.query.containsKey('format')).toList();

void main() {
  final hoy = DateTime.now();

  group('sección Reportes y selector de periodo (US4)', () {
    testWidgets('test_la_seccion_solo_existe_para_el_administrador', (tester) async {
      await openReports(tester, FakeReports(), role: 'RECEPTIONIST');
      expect(find.text('Reportes'), findsNothing);
    });

    testWidgets('test_por_omision_muestra_este_mes_y_pide_el_periodo_al_servidor', (tester) async {
      final api = await openReports(tester, FakeReports());
      final mes = ReportPeriod.month(hoy);

      expect(find.text('Periodo: del ${mes.fromText} al ${mes.toText}'), findsOneWidget);
      expect(pedidos(api, 'income').last.query, {'from': mes.fromText, 'to': mes.toText});
    });

    testWidgets('test_hoy_y_esta_semana_cambian_el_periodo_y_lo_muestran', (tester) async {
      final api = await openReports(tester, FakeReports());

      await tester.tap(find.byKey(const ValueKey('periodo-today')));
      await tester.pumpAndSettle();
      final dia = ReportPeriod.today(hoy);
      expect(find.text('Periodo: del ${dia.fromText} al ${dia.toText}'), findsOneWidget);
      expect(pedidos(api, 'income').last.query, {'from': dia.fromText, 'to': dia.toText});

      await tester.tap(find.byKey(const ValueKey('periodo-week')));
      await tester.pumpAndSettle();
      final semana = ReportPeriod.week(hoy);
      expect(pedidos(api, 'income').last.query, {'from': semana.fromText, 'to': semana.toText});
      expect(semana.from.weekday, DateTime.monday);
    });

    testWidgets('test_un_rango_valido_se_aplica_y_mas_de_un_anio_se_rechaza_sin_pedir_nada', (tester) async {
      final api = await openReports(tester, FakeReports());

      await tester.tap(find.byKey(const ValueKey('periodo-range')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('periodo-desde')), '2026-10-01');
      await tester.enterText(find.byKey(const ValueKey('periodo-hasta')), '2026-10-31');
      await tester.tap(find.byKey(const ValueKey('periodo-aplicar')));
      await tester.pumpAndSettle();
      expect(pedidos(api, 'income').last.query, {'from': '2026-10-01', 'to': '2026-10-31'});

      final antes = pedidos(api, 'income').length;
      await tester.enterText(find.byKey(const ValueKey('periodo-desde')), '2025-01-01');
      await tester.enterText(find.byKey(const ValueKey('periodo-hasta')), '2026-12-31');
      await tester.tap(find.byKey(const ValueKey('periodo-aplicar')));
      await tester.pumpAndSettle();

      expect(find.text('El periodo no puede pasar de un año.'), findsOneWidget);
      expect(pedidos(api, 'income').length, antes);
    });

    testWidgets('test_unas_fechas_mal_escritas_se_marcan', (tester) async {
      await openReports(tester, FakeReports());
      await tester.tap(find.byKey(const ValueKey('periodo-range')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('periodo-desde')), 'ayer');
      await tester.tap(find.byKey(const ValueKey('periodo-aplicar')));
      await tester.pumpAndSettle();

      expect(find.text('Usa el formato AAAA-MM-DD en las dos fechas.'), findsOneWidget);
    });
  });

  group('pestaña Ingresos (US4)', () {
    testWidgets('test_muestra_el_total_el_numero_de_pagos_las_barras_y_la_tabla_por_metodo', (tester) async {
      await openReports(tester, FakeReports());

      expect(find.byKey(const ValueKey('ingresos-total')), findsOneWidget);
      expect(find.text('\$1,250.75'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('ingresos-pagos')), matching: find.text('2')), findsOneWidget);
      expect(find.byKey(const ValueKey('ingresos-grafica')), findsOneWidget);
      expect(find.text('Efectivo'), findsOneWidget);
      expect(find.text('Tarjeta'), findsOneWidget);
    });

    testWidgets('test_sin_datos_muestra_el_estado_vacio', (tester) async {
      await openReports(tester, FakeReports()..empty = true);

      expect(find.text('No hay datos en este periodo'), findsOneWidget);
    });

    testWidgets('test_si_falla_muestra_el_error_y_reintentar_lo_recupera', (tester) async {
      final fake = FakeReports()..failingIncome = true;
      await openReports(tester, fake);

      expect(find.text('Ocurrió un error inesperado.'), findsOneWidget);
      fake.failingIncome = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ingresos-total')), findsOneWidget);
    });
  });

  group('pestañas de servicios, productividad y refacciones (US5 y US6)', () {
    testWidgets('test_servicios_y_productividad_muestran_sus_tablas_y_el_estado_vacio', (tester) async {
      await openReports(tester, FakeReports());
      await tester.tap(find.byKey(const ValueKey('pestana-servicios')));
      await tester.pumpAndSettle();

      expect(find.text('Cambio de aceite'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('\$4,500.00'), findsOneWidget);
      expect(find.text('Segundo mecánico'), findsOneWidget);
      expect(find.text('\$3,150.00'), findsOneWidget);
    });

    testWidgets('test_servicios_sin_datos_muestra_no_hay_datos_en_este_periodo', (tester) async {
      await openReports(tester, FakeReports()..empty = true);
      await tester.tap(find.byKey(const ValueKey('pestana-servicios')));
      await tester.pumpAndSettle();

      expect(find.text('No hay datos en este periodo'), findsOneWidget);
    });

    testWidgets('test_refacciones_muestra_costo_margen_el_chip_sin_costo_y_la_rotacion', (tester) async {
      await openReports(tester, FakeReports());
      await tester.tap(find.byKey(const ValueKey('pestana-refacciones')));
      await tester.pumpAndSettle();

      expect(find.text('Balatas delanteras'), findsNWidgets(2)); // en costo y margen y en rotación
      expect(find.text('\$3,120.00'), findsOneWidget);
      expect(find.text('\$1,560.00'), findsWidgets);
      expect(find.text('33.33%'), findsOneWidget);
      expect(find.byKey(const ValueKey('sin-costo')), findsOneWidget);
      expect(find.text('Sin costo'), findsOneWidget);
      expect(find.textContaining('1 refacción(es) sin costo'), findsOneWidget);
      expect(find.text('0.86'), findsOneWidget);
      expect(find.text('14.00'), findsOneWidget);
    });
  });

  group('exportar a Excel (US7)', () {
    testWidgets('test_exportar_descarga_el_reporte_de_la_pestana_con_el_periodo_y_lo_guarda', (tester) async {
      final fake = FakeReports();
      final saver = FakeFileSaver();
      final opener = FakeLinkOpener();
      await openReports(tester, fake, saver: saver, opener: opener);
      final mes = ReportPeriod.month(hoy);

      await tester.tap(find.byKey(const ValueKey('exportar-excel')));
      await tester.pumpAndSettle();

      expect(fake.exports.single.path, '/reports/income');
      expect(fake.exports.single.query, {'from': mes.fromText, 'to': mes.toText, 'format': 'xlsx'});
      expect(saver.saved.single.filename, 'reporte-income-${mes.fromText}_${mes.toText}.xlsx');
      expect(saver.saved.single.bytes, [80, 75, 3, 4]);
      expect(find.textContaining('Archivo guardado en C:\\Descargas\\reporte-income-'), findsOneWidget);

      await tester.tap(find.text('Abrir carpeta'));
      await tester.pump();
      expect(opener.opened, hasLength(1));
    });

    testWidgets('test_en_una_pestana_con_dos_reportes_exporta_los_dos_archivos', (tester) async {
      final fake = FakeReports();
      final saver = FakeFileSaver();
      await openReports(tester, fake, saver: saver);
      await tester.tap(find.byKey(const ValueKey('pestana-servicios')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('exportar-excel')));
      await tester.pumpAndSettle();

      expect(fake.exports.map((r) => r.path), ['/reports/services', '/reports/productivity']);
      expect(saver.saved, hasLength(2));
      expect(find.textContaining('Archivos guardados en'), findsOneWidget);
    });

    testWidgets('test_si_no_se_puede_escribir_muestra_el_error_y_no_pierde_el_reporte', (tester) async {
      final fake = FakeReports();
      await openReports(tester, fake, saver: FakeFileSaver(fails: true));

      await tester.tap(find.byKey(const ValueKey('exportar-excel')));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo guardar el archivo'), findsOneWidget);
      expect(find.byKey(const ValueKey('ingresos-total')), findsOneWidget);
    });

    testWidgets('test_un_error_del_servidor_al_exportar_se_muestra', (tester) async {
      final fake = FakeReports();
      final inner = fake.handler();
      final api = FakeApi(
        role: 'ADMIN',
        handler: (r) => r.query['format'] == 'xlsx' ? failure(400, 'VALIDATION_ERROR', 'El periodo no puede pasar de un año.') : inner(r),
      );
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, api);
      await openSection(tester, 'Reportes');

      await tester.tap(find.byKey(const ValueKey('exportar-excel')));
      await tester.pumpAndSettle();

      expect(find.text('El periodo no puede pasar de un año.'), findsWidgets);
    });
  });
}
