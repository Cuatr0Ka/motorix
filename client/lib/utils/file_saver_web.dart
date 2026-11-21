import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'file_saver.dart';

/// Guardado por omisión en el navegador: `dart:io` no existe en la web, así que se arma un `Blob` y se dispara la descarga del
/// navegador con un enlace temporal. El archivo queda en la carpeta de descargas que tenga configurada el navegador.
FileSaver createDefaultFileSaver() => const BrowserFileSaver();

const _xlsxType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

class BrowserFileSaver extends FileSaver {
  const BrowserFileSaver();

  @override
  bool get opensFolder => false;

  @override
  Future<String> save(String filename, List<int> bytes) async {
    final data = Uint8List.fromList(bytes).toJS;
    final options = <String, String>{'type': _xlsxType}.jsify()! as JSObject;
    final blob = (globalContext['Blob']! as JSFunction).callAsConstructor<JSObject>(<JSAny>[data].toJS, options);

    final urlApi = globalContext['URL']! as JSObject;
    final url = urlApi.callMethod<JSString>('createObjectURL'.toJS, blob).toDart;

    final document = globalContext['document']! as JSObject;
    final link = document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
    link['href'] = url.toJS;
    link['download'] = filename.toJS;
    final body = document['body']! as JSObject;
    body.callMethod<JSAny?>('appendChild'.toJS, link);
    link.callMethod<JSAny?>('click'.toJS);
    link.callMethod<JSAny?>('remove'.toJS);
    // El navegador ya tomó el archivo: se libera la URL temporal un instante después.
    await Future<void>.delayed(const Duration(seconds: 1));
    urlApi.callMethod<JSAny?>('revokeObjectURL'.toJS, url.toJS);
    return filename;
  }
}
