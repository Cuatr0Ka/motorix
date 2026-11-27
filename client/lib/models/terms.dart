/// Versión de los términos y condiciones con la bandera de aceptación de quien consulta.
class TermsDocument {
  const TermsDocument({
    required this.id,
    required this.version,
    required this.title,
    required this.body,
    this.privacyNotice,
    required this.accepted,
    this.publishedAt,
  });

  factory TermsDocument.fromJson(Map<String, dynamic> json) => TermsDocument(
        id: (json['id'] as num).toInt(),
        version: '${json['version']}',
        title: '${json['title']}',
        body: '${json['body']}',
        privacyNotice: json['privacyNotice'] == null ? null : '${json['privacyNotice']}',
        accepted: json['accepted'] as bool? ?? false,
        publishedAt: json['publishedAt'] == null ? null : DateTime.tryParse('${json['publishedAt']}'),
      );

  final int id;
  final String version;
  final String title;
  final String body;

  /// Aviso de privacidad (versión 2.0 en adelante). En versiones anteriores es nulo y su texto va dentro de [body].
  final String? privacyNotice;
  final bool accepted;
  final DateTime? publishedAt;
}

/// Aceptación de la versión vigente por una persona (lista de administración).
class TermsAcceptance {
  const TermsAcceptance({required this.userId, required this.username, required this.name, this.acceptedAt});

  factory TermsAcceptance.fromJson(Map<String, dynamic> json) => TermsAcceptance(
        userId: (json['userId'] as num).toInt(),
        username: '${json['username']}',
        name: '${json['name']}',
        acceptedAt: json['acceptedAt'] == null ? null : DateTime.tryParse('${json['acceptedAt']}')?.toLocal(),
      );

  final int userId;
  final String username;
  final String name;
  final DateTime? acceptedAt;
}

/// Una página de aceptaciones con el total y los usuarios activos que todavía no aceptan.
class TermsAcceptancesPage {
  const TermsAcceptancesPage({required this.items, required this.total, required this.pending, required this.page, required this.pageSize});

  final List<TermsAcceptance> items;
  final int total;
  final int pending;
  final int page;
  final int pageSize;

  int get pages => total == 0 ? 1 : (total / pageSize).ceil();
}
