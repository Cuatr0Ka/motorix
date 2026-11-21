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

  test('test_las_carpetas_candidatas_son_descargas_documentos_y_temporal_en_ese_orden', () {
    final lista = DownloadsFileSaver.candidates({'USERPROFILE': r'C:\Users\ana'}, true).map((d) => d.path).toList();

    expect(lista[0], endsWith('Downloads'));
    expect(lista[1], endsWith('Documents'));
    expect(lista[2], Directory.systemTemp.path);
  });

  test('test_el_mensaje_de_un_error_de_archivo_incluye_el_motivo_y_la_ruta', () {
    const error = FileSystemException('No se pudo escribir', r'C:\Users\ana\Downloads\r.xlsx', OSError('Acceso denegado', 5));

    expect(describeFileError(error), r'Acceso denegado (C:\Users\ana\Downloads\r.xlsx)');
    expect(describeFileError(const FileSystemException('Sin ruta')), 'Sin ruta');
  });
}
