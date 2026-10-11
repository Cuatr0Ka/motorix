import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motorix_client/main.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/models/ticket.dart';
import 'package:motorix_client/utils/link_opener.dart';
import 'package:motorix_client/utils/ticket_printer.dart';

/// Petición recibida por la API simulada.
class FakeRequest {
  FakeRequest(this.method, this.path, this.query, this.body);

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, dynamic> body;
}

typedef FakeHandler = http.Response? Function(FakeRequest request);

http.Response jsonResponse(int status, Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response ok(Object data, {Map<String, dynamic>? meta}) =>
    jsonResponse(200, {'data': data, 'meta': ?meta});

http.Response created(Object data) => jsonResponse(201, {'data': data});

http.Response failure(int status, String code, String message, {Object? details}) =>
    jsonResponse(status, {
      'error': {'code': code, 'message': message, 'details': ?details},
    });

Map<String, dynamic> userJson(String role, {int id = 1, String? name, String? username}) => {
      'id': id,
      'username': username ?? role.toLowerCase(),
      'name': name ?? 'Persona de prueba',
      'email': '${role.toLowerCase()}@prueba.local',
      'role': role,
    };

/// Cliente HTTP simulado: atiende primero `handler` y, si devuelve null, el inicio de sesión.
/// Guarda las peticiones en [requests] para poder verificarlas.
class FakeApi {
  FakeApi({this.role = 'RECEPTIONIST', this.handler});

  final String role;
  final FakeHandler? handler;
  final List<FakeRequest> requests = [];

  late final ApiClient client = ApiClient(
    baseUrl: 'http://prueba.local/api',
    httpClient: MockClient((request) async {
      final body = request.body.isEmpty ? <String, dynamic>{} : jsonDecode(request.body);
      final fake = FakeRequest(
        request.method,
        request.url.path.replaceFirst('/api', ''),
        request.url.queryParameters,
        body is Map<String, dynamic> ? body : {},
      );
      requests.add(fake);

      final custom = handler?.call(fake);
      if (custom != null) return custom;

      if (fake.method == 'POST' && fake.path == '/auth/login') {
        if (fake.body['password'] == 'Incorrecta1') {
          return failure(401, 'INVALID_CREDENTIALS', 'Usuario o contraseña incorrectos.');
        }
        return ok({'token': 'token-de-prueba', 'expiresIn': 28800, 'user': userJson(role)});
      }
      return failure(404, 'NOT_FOUND', 'No se encontró el recurso solicitado.');
    }),
  );
}

/// Ventana de escritorio grande para que el sidebar arranque expandido.
void useDesktopWindow(WidgetTester tester, {double width = 1400, double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Monta la aplicación e inicia sesión con el rol del [api].
/// Abridor de enlaces simulado: guarda las URL que se pidió abrir.
class FakeLinkOpener extends LinkOpener {
  FakeLinkOpener({this.succeeds = true});

  final bool succeeds;
  final List<String> opened = [];

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return succeeds;
  }
}

/// Impresora de tickets simulada: guarda los tickets que se pidió imprimir.
class FakeTicketPrinter extends TicketPrinter {
  FakeTicketPrinter({this.succeeds = true});

  final bool succeeds;
  final List<Ticket> printed = [];

  @override
  Future<bool> printTicket(Ticket ticket) async {
    printed.add(ticket);
    return succeeds;
  }
}

Future<void> pumpAppSignedIn(WidgetTester tester, FakeApi api, {LinkOpener? linkOpener, TicketPrinter? ticketPrinter}) async {
  await tester.pumpWidget(
    MotorixApp(
      apiClient: api.client,
      useGoogleFonts: false,
      linkOpener: linkOpener ?? FakeLinkOpener(),
      ticketPrinter: ticketPrinter ?? FakeTicketPrinter(),
    ),
  );
  await tester.enterText(find.widgetWithText(TextFormField, 'Usuario o correo'), 'usuario');
  await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'Correcta2026');
  await tester.tap(find.text('Iniciar sesión').last);
  await tester.pumpAndSettle();
}
