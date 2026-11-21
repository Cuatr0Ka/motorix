import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

Map<String, dynamic> _snapshot({
  String name = 'Motorix Taller Mecánico',
  String address = '',
  String phone = '',
  int warnDays = 30,
  int warnKm = 1000,
  Map<String, String>? sources,
}) =>
    {
      'shop': {'name': name, 'address': address, 'phone': phone},
      'maintenance': {'warnDays': warnDays, 'warnKm': warnKm},
      'sources': sources ??
          {
            'shop.name': 'DEFAULT',
            'shop.address': 'DEFAULT',
            'shop.phone': 'DEFAULT',
            'maintenance.warn_days': 'DEFAULT',
            'maintenance.warn_km': 'DEFAULT',
          },
    };

/// API simulada de configuración: guarda lo que recibe y marca el origen como guardado, como el servidor.
class FakeSettings {
  FakeSettings([Map<String, dynamic>? initial]) : data = initial ?? _snapshot();

  Map<String, dynamic> data;
  bool failingToLoad = false;
  Map<String, dynamic>? saveError;
  final List<Map<String, dynamic>> saved = [];
  int loads = 0;

  FakeHandler handler() => (r) {
        if (r.path != '/settings') return null;
        if (r.method == 'GET') {
          loads += 1;
          if (failingToLoad) return failure(500, 'INTERNAL_ERROR', 'Ocurrió un error inesperado.');
          return ok(data);
        }
        if (r.method == 'PUT') {
          saved.add(r.body);
          final fail = saveError;
          if (fail != null) {
            return failure(400, 'VALIDATION_ERROR', 'Revisa los campos marcados.', details: fail['details']);
          }
          final shop = Map<String, dynamic>.from(data['shop'] as Map);
          final maintenance = Map<String, dynamic>.from(data['maintenance'] as Map);
          final sources = Map<String, dynamic>.from(data['sources'] as Map);
          final body = r.body;
          (body['shop'] as Map?)?.forEach((k, v) {
            shop[k as String] = v;
            sources['shop.$k'] = 'STORED';
          });
          (body['maintenance'] as Map?)?.forEach((k, v) {
            maintenance[k as String] = v;
            sources[k == 'warnDays' ? 'maintenance.warn_days' : 'maintenance.warn_km'] = 'STORED';
          });
          data = {'shop': shop, 'maintenance': maintenance, 'sources': sources};
          return ok(data);
        }
        return null;
      };
}

void main() {
  group('sección Configuración en el menú', () {
    testWidgets('test_el_administrador_ve_configuracion', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: FakeSettings().handler()));

      expect(find.text('Configuración'), findsWidgets);
    });

    for (final role in ['RECEPTIONIST', 'MECHANIC']) {
      testWidgets('test_${role.toLowerCase()}_no_ve_configuracion', (tester) async {
        useDesktopWindow(tester);
        await pumpAppSignedIn(tester, FakeApi(role: role, handler: FakeSettings().handler()));

        expect(find.text('Configuración'), findsNothing);
      });
    }
  });

  group('pestaña Taller (US1)', () {
    testWidgets('test_muestra_los_datos_del_taller_con_el_origen_de_cada_valor', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeSettings(_snapshot(
        name: 'Taller del Norte',
        address: 'Calle 5 #10',
        sources: {
          'shop.name': 'STORED',
          'shop.address': 'ENV',
          'shop.phone': 'DEFAULT',
          'maintenance.warn_days': 'DEFAULT',
          'maintenance.warn_km': 'DEFAULT',
        },
      ));
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));
      await openSection(tester, 'Configuración');

      expect(find.byKey(const ValueKey('pestana-taller')), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Taller del Norte'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Calle 5 #10'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('origen-shop.name')), matching: find.text('Guardado')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('origen-shop.address')), matching: find.text('Variable de entorno')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('origen-shop.phone')), matching: find.text('Predeterminado')), findsOneWidget);
    });

    testWidgets('test_guardar_esta_deshabilitado_sin_cambios_y_se_habilita_al_editar', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeSettings();
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));
      await openSection(tester, 'Configuración');

      FilledButton boton() => tester.widget<FilledButton>(find.byKey(const ValueKey('guardar-taller')));
      expect(boton().onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('campo-taller-nombre')), 'Taller Nuevo');
      await tester.pump();

      expect(boton().onPressed, isNotNull);
    });

    testWidgets('test_guardar_envia_solo_lo_cambiado_y_muestra_el_aviso_del_ticket', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeSettings();
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));
      await openSection(tester, 'Configuración');

      await tester.enterText(find.byKey(const ValueKey('campo-taller-nombre')), 'Taller Los Pinos');
      await tester.enterText(find.byKey(const ValueKey('campo-taller-telefono')), '7761112233');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('guardar-taller')));
      await tester.pumpAndSettle();

      expect(fake.saved, [
        {
          'shop': {'name': 'Taller Los Pinos', 'phone': '7761112233'},
        },
      ]);
      expect(find.text('Datos del taller guardados. Los tickets nuevos los usarán; los emitidos no cambian.'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('origen-shop.name')), matching: find.text('Guardado')), findsOneWidget);
    });

    testWidgets('test_un_nombre_vacio_se_marca_en_su_campo_sin_enviar_nada', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeSettings();
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));
      await openSection(tester, 'Configuración');

      await tester.enterText(find.byKey(const ValueKey('campo-taller-nombre')), '');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('guardar-taller')));
      await tester.pumpAndSettle();

      expect(find.text('El nombre del taller es obligatorio.'), findsOneWidget);
    });

    testWidgets('test_un_telefono_con_letras_se_marca_en_su_campo', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeSettings();
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));
      await openSection(tester, 'Configuración');

      await tester.enterText(find.byKey(const ValueKey('campo-taller-telefono')), 'llamar al taller');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('guardar-taller')));
      await tester.pumpAndSettle();

      expect(find.text('El teléfono solo puede llevar dígitos, espacios, +, - y paréntesis.'), findsOneWidget);
      expect(fake.saved, isEmpty);
    });

    testWidgets('test_un_error_del_servidor_se_muestra_en_su_campo', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeSettings()
        ..saveError = {
          'details': [
            {'field': 'shop.name', 'message': 'El nombre del taller ya está en uso por otro dato.'},
          ],
        };
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));
      await openSection(tester, 'Configuración');

      await tester.enterText(find.byKey(const ValueKey('campo-taller-nombre')), 'Taller Repetido');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('guardar-taller')));
      await tester.pumpAndSettle();

      expect(find.text('El nombre del taller ya está en uso por otro dato.'), findsOneWidget);
    });

    testWidgets('test_si_falla_la_carga_muestra_el_error_y_reintentar_la_recupera', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeSettings()..failingToLoad = true;
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: fake.handler()));
      await openSection(tester, 'Configuración');

      expect(find.text('Ocurrió un error inesperado.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      fake.failingToLoad = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('campo-taller-nombre')), findsOneWidget);
    });
  });
}
