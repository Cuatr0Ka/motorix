import 'file_saver.dart';

/// Guardado por omisión en escritorio y móvil: la carpeta de descargas del sistema.
FileSaver createDefaultFileSaver() => const DownloadsFileSaver();
