import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/utils/file_saver.dart';

void main() {
  late Directory carpeta;

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('motorix_descargas_');
  });

  tearDown(() async {
    await carpeta.delete(recursive: true);
  });

  test('test_guarda_el_archivo_con_los_bytes_recibidos', () async {
    final ruta = await DownloadsFileSaver.writeUnique(carpeta, 'reporte-income-2026-10-01_2026-10-31.xlsx', [80, 75, 3, 4]);

    expect(await File(ruta).readAsBytes(), [80, 75, 3, 4]);
    expect(ruta.endsWith('reporte-income-2026-10-01_2026-10-31.xlsx'), isTrue);
  });

  test('test_no_sobrescribe_un_archivo_existente_y_agrega_un_sufijo', () async {
    final primero = await DownloadsFileSaver.writeUnique(carpeta, 'reporte.xlsx', [1]);
    final segundo = await DownloadsFileSaver.writeUnique(carpeta, 'reporte.xlsx', [2]);
    final tercero = await DownloadsFileSaver.writeUnique(carpeta, 'reporte.xlsx', [3]);

    expect(segundo.endsWith('reporte (1).xlsx'), isTrue);
    expect(tercero.endsWith('reporte (2).xlsx'), isTrue);
    expect(await File(primero).readAsBytes(), [1]); // el original no se tocó
    expect(await File(segundo).readAsBytes(), [2]);
  });

  test('test_la_carpeta_de_descargas_sale_de_userprofile_en_windows_y_de_home_en_los_demas', () {
    expect(DownloadsFileSaver.downloadsDirectory({'USERPROFILE': r'C:\Users\ana'}, true).path, r'C:\Users\ana' '${Platform.pathSeparator}Downloads');
    expect(DownloadsFileSaver.downloadsDirectory({'HOME': '/home/ana'}, false).path, '/home/ana${Platform.pathSeparator}Downloads');
  });

  test('test_sin_carpeta_personal_lanza_un_error_de_archivo', () {
    expect(() => DownloadsFileSaver.downloadsDirectory({}, true), throwsA(isA<FileSystemException>()));
  });
}
