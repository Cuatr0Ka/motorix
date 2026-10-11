import 'package:url_launcher/url_launcher.dart';

/// Abre un enlace en el navegador del sistema. Es una interfaz para poder sustituirla en las pruebas.
abstract class LinkOpener {
  const LinkOpener();

  /// Devuelve `true` si se pudo abrir el enlace.
  Future<bool> open(String url);
}

/// Implementación real: usa `url_launcher` y abre el navegador externo.
class SystemLinkOpener extends LinkOpener {
  const SystemLinkOpener();

  @override
  Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
