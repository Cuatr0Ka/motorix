import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// URL base de la API; se define al ejecutar con `--dart-define=API_BASE_URL=...`.
const String kDefaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000/api',
);

/// Error de un campo individual devuelto por la API (`details`).
class FieldError {
  const FieldError(this.field, this.message);

  final String field;
  final String message;
}

/// Error de la API o de red, ya con mensaje en español listo para mostrar.
class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.code,
    required this.message,
    this.details,
  });

  /// 0 cuando no hubo respuesta del servidor.
  final int status;
  final String code;
  final String message;

  /// Datos extra del error: lista de [FieldError], coincidencias, segundos de bloqueo, etc.
  final Object? details;

  List<FieldError> get fieldErrors {
    final raw = details;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .where((e) => e['field'] != null)
        .map((e) => FieldError('${e['field']}', '${e['message'] ?? ''}'))
        .toList();
  }

  Map<String, dynamic> get detailsMap {
    final raw = details;
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  @override
  String toString() => 'ApiException($status, $code): $message';
}

/// Respuesta exitosa: `data` y, en listados, `meta` de paginación.
class ApiResponse {
  const ApiResponse(this.data, this.meta);

  final dynamic data;
  final Map<String, dynamic>? meta;

  Map<String, dynamic> get map => Map<String, dynamic>.from(data as Map);
  List<Map<String, dynamic>> get list =>
      (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  int get total => (meta?['total'] as num?)?.toInt() ?? 0;
}

/// Cliente HTTP de la API de Motorix. Solo el backend toca la base de datos;
/// la aplicación únicamente consume estos endpoints.
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _baseUrl = (baseUrl ?? kDefaultApiBaseUrl).replaceAll(RegExp(r'/+$'), '');

  final http.Client _http;
  final String _baseUrl;

  /// Token de la sesión actual; se envía como `Authorization: Bearer`.
  String? token;

  /// Se invoca cuando el servidor rechaza el token (sesión vencida o cuenta desactivada).
  void Function()? onSessionExpired;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value != null && '$value'.isNotEmpty) params[key] = '$value';
    });
    return Uri.parse('$_baseUrl$path').replace(queryParameters: params.isEmpty ? null : params);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<ApiResponse> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<ApiResponse> post(String path, {Object? body}) =>
      _send(() => _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<ApiResponse> patch(String path, {Object? body}) =>
      _send(() => _http.patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<ApiResponse> put(String path, {Object? body}) =>
      _send(() => _http.put(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<ApiResponse> delete(String path) => _send(() => _http.delete(_uri(path), headers: _headers));

  Future<ApiResponse> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException(
        status: 0,
        code: 'TIMEOUT',
        message: 'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
      );
    } catch (_) {
      throw const ApiException(
        status: 0,
        code: 'NETWORK_ERROR',
        message: 'No se pudo conectar con el servidor. Revisa tu conexión.',
      );
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      body = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300 && body != null) {
      final meta = body['meta'];
      return ApiResponse(body['data'], meta is Map ? Map<String, dynamic>.from(meta) : null);
    }

    final error = body?['error'];
    final code = error is Map ? '${error['code'] ?? 'ERROR'}' : 'ERROR';
    final message = error is Map && error['message'] != null
        ? '${error['message']}'
        : 'Ocurrió un error inesperado. Inténtalo de nuevo.';

    // Un 401 con token activo significa sesión vencida o cuenta desactivada.
    if (response.statusCode == 401 && code == 'UNAUTHENTICATED' && token != null) {
      onSessionExpired?.call();
    }

    throw ApiException(
      status: response.statusCode,
      code: code,
      message: message,
      details: error is Map ? error['details'] : null,
    );
  }
}
