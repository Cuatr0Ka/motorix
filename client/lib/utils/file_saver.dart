import 'dart:io';

/// Guarda un archivo descargado y devuelve la ruta donde quedó. Se sustituye en las pruebas.
abstract class FileSaver {
  const FileSaver();

  Future<String> save(String filename, List<int> bytes);

  /// Si es verdadero, la ruta devuelta es una carpeta real del equipo que se puede abrir. En el navegador no: la descarga
  /// la gestiona el navegador y deja el archivo en su carpeta de descargas.
  bool get opensFolder => true;
}

/// Texto legible de un error de archivo: el mensaje del sistema operativo y la ruta, para saber qué falló de verdad.
String describeFileError(Object error) {
  if (error is FileSystemException) {
    final detail = error.osError?.message.trim();
    final reason = (detail != null && detail.isNotEmpty) ? detail : error.message;
    return error.path == null || error.path!.isEmpty ? reason : '$reason (${error.path})';
  }
  return '$error';
}

/// Guarda en la carpeta de descargas del sistema (`USERPROFILE\Downloads` en Windows y `HOME/Downloads` en los demás) sin
/// sobrescribir un archivo existente: si ya existe agrega un sufijo « (1)», « (2)»... Si la carpeta de descargas no se puede
/// escribir (permisos, carpeta protegida o redirigida), prueba con Documentos y, al final, con la carpeta temporal, y devuelve
/// la ruta donde quedó. Si ninguna sirve, lanza un [FileSystemException] con el motivo de cada intento.
class DownloadsFileSaver extends FileSaver {
  const DownloadsFileSaver();

  static String? _home(Map<String, String> env, bool windows) {
    final home = windows ? env['USERPROFILE'] : env['HOME'];
    return (home == null || home.isEmpty) ? null : home;
  }

  static Directory downloadsDirectory([Map<String, String>? environment, bool? windows]) {
    final home = _home(environment ?? Platform.environment, windows ?? Platform.isWindows);
    if (home == null) throw const FileSystemException('No se encontró la carpeta personal del usuario.');
    return Directory('$home${Platform.pathSeparator}Downloads');
  }

  /// Carpetas donde se intenta guardar, en orden: Descargas, Documentos y la carpeta temporal.
  static List<Directory> candidates([Map<String, String>? environment, bool? windows]) {
    final env = environment ?? Platform.environment;
    final isWindows = windows ?? Platform.isWindows;
    final home = _home(env, isWindows);
    return [
      if (home != null) Directory('$home${Platform.pathSeparator}Downloads'),
      if (home != null) Directory('$home${Platform.pathSeparator}Documents'),
      Directory.systemTemp,
    ];
  }

  @override
  Future<String> save(String filename, List<int> bytes) async {
    final failures = <String>[];
    for (final directory in candidates()) {
      try {
        await directory.create(recursive: true);
        return await writeUnique(directory, filename, bytes);
      } on FileSystemException catch (e) {
        failures.add('${directory.path}: ${describeFileError(e)}');
      }
    }
    throw FileSystemException(failures.join(' | '));
  }

  /// Escribe en [directory] sin pisar un archivo que ya exista.
  static Future<String> writeUnique(Directory directory, String filename, List<int> bytes) async {
    final dot = filename.lastIndexOf('.');
    final base = dot > 0 ? filename.substring(0, dot) : filename;
    final extension = dot > 0 ? filename.substring(dot) : '';
    var candidate = File('${directory.path}${Platform.pathSeparator}$filename');
    var n = 0;
    while (await candidate.exists()) {
      n += 1;
      candidate = File('${directory.path}${Platform.pathSeparator}$base ($n)$extension');
    }
    await candidate.writeAsBytes(bytes, flush: true);
    return candidate.path;
  }
}
