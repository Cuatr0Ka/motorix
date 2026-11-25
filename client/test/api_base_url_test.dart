import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/services/api_client.dart';

void main() {
  group('URL base de la API', () {
    test('test_una_url_absoluta_se_conserva_sin_barras_finales', () {
      expect(ApiClient.resolveBaseUrl('http://localhost:3000/api/'), 'http://localhost:3000/api');
    });

    test('test_una_url_relativa_se_completa_con_el_origen_de_la_pagina', () {
      expect(ApiClient.resolveBaseUrl('/api', origin: 'https://motorix.example.com'), 'https://motorix.example.com/api');
    });
  });
}
