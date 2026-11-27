import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/data.dart';
import 'helpers/fake_api.dart';

/// API simulada de términos: la versión vigente, si la persona ya aceptó y las aceptaciones de administración.
class FakeTerms {
  FakeTerms({this.accepted = false, this.withPrivacy = false});

  /// Versión 2.0: el aviso de privacidad viene como un texto aparte.
  final bool withPrivacy;

  bool accepted;
  bool failingToLoad = false;
  bool rejectNextClients = false;
  int accepts = 0;

  Map<String, dynamic> get doc => {
        'id': 1,
        'version': '1.0',
        'title': 'Términos y condiciones y aviso de privacidad',
        'body': 'TÉRMINOS DE USO DE MOTORIX\n\n1. Uso permitido del sistema',
        if (withPrivacy) 'privacyNotice': 'AVISO DE PRIVACIDAD INTEGRAL\n\n1. Quién es el responsable de sus datos',
        'publishedAt': '2026-11-21T00:00:00.000Z',
        'accepted': accepted,
      };

  FakeHandler handler() => (r) {
        if (r.method == 'GET' && r.path == '/terms/current') {
          if (failingToLoad) return failure(500, 'INTERNAL_ERROR', 'Ocurrió un error inesperado.');
          return ok(doc);
        }
        if (r.method == 'POST' && r.path == '/terms/accept') {
          accepts += 1;
          accepted = true;
          return ok({'versionId': 1, 'version': '1.0', 'acceptedAt': '2026-11-21T15:00:00.000Z'});
        }
        if (r.method == 'GET' && r.path == '/terms/acceptances') {
          return ok(
            [
              {'userId': 1, 'username': 'admin', 'name': 'Administrador', 'acceptedAt': '2026-11-21T15:00:00.000Z'},
            ],
            meta: {'page': 1, 'pageSize': 10, 'total': 1, 'pending': 1, 'version': '1.0'},
          );
        }
        if (r.method == 'GET' && r.path == '/clients' && rejectNextClients) {
          rejectNextClients = false;
          accepted = false;
          return failure(403, 'TERMS_NOT_ACCEPTED', 'Debes aceptar los términos y condiciones para continuar.',
              details: {'version': '1.0', 'versionId': 1});
        }
        return null;
      };
}

void main() {
  group('pantalla de aceptación (US9)', () {
    testWidgets('test_tras_iniciar_sesion_sin_aceptar_aparece_la_pantalla_y_no_el_menu', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: FakeTerms().handler()));

      expect(find.text('Términos y condiciones y aviso de privacidad'), findsOneWidget);
      expect(find.byKey(const ValueKey('terms-version')), findsOneWidget);
      expect(find.text('Versión 1.0'), findsOneWidget);
      expect(find.byKey(const ValueKey('terms-body')), findsOneWidget);
      expect(find.text('Clientes'), findsNothing); // el menú de la aplicación no se muestra
    });

    testWidgets('test_aceptar_y_continuar_esta_deshabilitado_hasta_marcar_la_casilla_y_luego_entra', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeTerms();
      final api = FakeApi(role: 'RECEPTIONIST', handler: fake.handler());
      await pumpAppSignedIn(tester, api);

      FilledButton boton() => tester.widget<FilledButton>(find.byKey(const ValueKey('terms-accept')));
      expect(boton().onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('terms-check')));
      await tester.pump();
      expect(boton().onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('terms-accept')));
      await tester.pumpAndSettle();

      final post = api.requests.firstWhere((r) => r.method == 'POST' && r.path == '/terms/accept');
      expect(post.body, {'versionId': 1});
      expect(find.byKey(const ValueKey('terms-accept')), findsNothing);
      expect(find.text('Clientes'), findsWidgets); // ya está dentro de la aplicación
    });

    testWidgets('test_rechazar_y_salir_cierra_la_sesion_con_el_aviso', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: FakeTerms().handler()));

      await tester.tap(find.byKey(const ValueKey('terms-reject')));
      await tester.pumpAndSettle();

      expect(find.text('Para usar Motorix debes aceptar los términos y condiciones.'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsWidgets);
    });

    testWidgets('test_con_los_terminos_aceptados_no_aparece_la_pantalla', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: FakeTerms(accepted: true).handler()));

      expect(find.byKey(const ValueKey('terms-accept')), findsNothing);
      expect(find.text('Clientes'), findsWidgets);
    });

    testWidgets('test_un_403_a_mitad_de_sesion_vuelve_a_mostrar_la_pantalla', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeTerms(accepted: true)..rejectNextClients = true;
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));

      await openSection(tester, 'Clientes');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('terms-accept')), findsOneWidget);
    });

    testWidgets('test_si_falla_la_carga_muestra_el_error_y_reintentar_la_recupera', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeTerms()..failingToLoad = true;
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: fake.handler()));

      expect(find.text('Ocurrió un error inesperado.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      fake.failingToLoad = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('terms-accept')), findsOneWidget);
    });
  });

  group('sección Términos de administración (US9)', () {
    testWidgets('test_muestra_la_version_vigente_las_aceptaciones_y_los_pendientes_sin_boton_de_edicion', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: FakeTerms(accepted: true).handler()));
      await openSection(tester, 'Términos y privacidad');

      expect(find.textContaining('Versión vigente 1.0'), findsOneWidget);
      expect(find.byKey(const ValueKey('aceptacion-1')), findsOneWidget);
      expect(find.text('1 pendientes de aceptar'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    for (final role in ['RECEPTIONIST', 'MECHANIC']) {
      testWidgets('test_la_seccion_terminos_no_existe_para_${role.toLowerCase()}', (tester) async {
        useDesktopWindow(tester);
        await pumpAppSignedIn(tester, FakeApi(role: role, handler: FakeTerms(accepted: true).handler()));

        expect(find.text('Términos y privacidad'), findsNothing);
      });
    }
  });

  group('términos y aviso de privacidad como dos textos', () {
    Finder terminosTab() => find.descendant(of: find.byKey(const ValueKey('legal-selector')), matching: find.text('Términos y condiciones'));
    Finder privacidadTab() => find.descendant(of: find.byKey(const ValueKey('legal-selector')), matching: find.text('Aviso de privacidad'));

    testWidgets('test_con_aviso_aparte_muestra_el_selector_y_cambia_entre_los_dos_textos', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: FakeTerms(withPrivacy: true).handler()));

      expect(find.byKey(const ValueKey('legal-selector')), findsOneWidget);
      expect(find.byKey(const ValueKey('terms-body')), findsOneWidget);
      expect(find.byKey(const ValueKey('privacy-body')), findsNothing);

      await tester.tap(privacidadTab());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('privacy-body')), findsOneWidget);
      expect(find.textContaining('AVISO DE PRIVACIDAD INTEGRAL'), findsOneWidget);
      expect(find.byKey(const ValueKey('terms-body')), findsNothing);

      await tester.tap(terminosTab());
      await tester.pumpAndSettle();
      expect(find.textContaining('TÉRMINOS DE USO DE MOTORIX'), findsOneWidget);
    });

    testWidgets('test_aceptar_exige_las_dos_casillas_y_envia_una_sola_aceptacion', (tester) async {
      useDesktopWindow(tester);
      final fake = FakeTerms(withPrivacy: true);
      final api = FakeApi(role: 'RECEPTIONIST', handler: fake.handler());
      await pumpAppSignedIn(tester, api);

      FilledButton boton() => tester.widget<FilledButton>(find.byKey(const ValueKey('terms-accept')));
      expect(boton().onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('terms-check')));
      await tester.pump();
      expect(boton().onPressed, isNull, reason: 'falta aceptar el aviso de privacidad');

      await tester.tap(find.byKey(const ValueKey('privacy-check')));
      await tester.pump();
      expect(boton().onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('terms-accept')));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'POST' && r.path == '/terms/accept'), hasLength(1));
      expect(fake.accepts, 1);
      expect(find.text('Clientes'), findsWidgets);
    });

    testWidgets('test_sin_aviso_aparte_no_aparecen_el_selector_ni_la_segunda_casilla', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'RECEPTIONIST', handler: FakeTerms().handler()));

      expect(find.byKey(const ValueKey('legal-selector')), findsNothing);
      expect(find.byKey(const ValueKey('privacy-check')), findsNothing);
    });

    testWidgets('test_la_administracion_puede_leer_el_aviso_de_privacidad_en_su_seccion', (tester) async {
      useDesktopWindow(tester);
      await pumpAppSignedIn(tester, FakeApi(role: 'ADMIN', handler: FakeTerms(accepted: true, withPrivacy: true).handler()));
      await openSection(tester, 'Términos y privacidad');

      await tester.tap(privacidadTab());
      await tester.pumpAndSettle();

      expect(find.textContaining('AVISO DE PRIVACIDAD INTEGRAL'), findsOneWidget);
    });
  });
}
