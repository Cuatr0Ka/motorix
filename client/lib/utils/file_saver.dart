import 'dart:io';

/// Guarda un archivo descargado y devuelve la ruta donde quedó. Se sustituye en las pruebas.
abstract class FileSaver {
  const FileSaver();

  Future<String> save(String filename, List<int> bytes);
}

/// Guarda en la carpeta de descargas del sistema (`USERPROFILE\Downloads` en Windows y `HOME/Downloads` en los demás) sin
/// sobrescribir un archivo existente: si ya existe agrega un sufijo « (1)», « (2)»...
class DownloadsFileSaver extends FileSaver {
  const DownloadsFileSaver();

  static Directory downloadsDirectory([Map<String, String>? environment, bool? windows]) {
    final env = environment ?? Platform.environment;
    final isWindows = windows ?? Platform.isWindows;
    final home = isWindows ? env['USERPROFILE'] : env['HOME'];
    if (home == null || home.isEmpty) throw const FileSystemException('No se encontró la carpeta de descargas.');
    return Directory('$home${Platform.pathSeparator}Downloads');
  }

  @override
  Future<String> save(String filename, List<int> bytes) async {
    final directory = downloadsDirectory();
    await directory.create(recursive: true);
    return writeUnique(directory, filename, bytes);
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
