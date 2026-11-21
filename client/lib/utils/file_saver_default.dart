// El guardado por omisión depende de la plataforma: en el navegador no existe `dart:io`.
export 'file_saver_io.dart' if (dart.library.js_interop) 'file_saver_web.dart' show createDefaultFileSaver;
