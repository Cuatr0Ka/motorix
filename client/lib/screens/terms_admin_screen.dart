import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/terms_provider.dart';
import '../utils/formatters.dart';
import '../utils/tokens.dart';
import '../widgets/legal_texts_view.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';

/// Sección «Términos» (solo administración): versión vigente y quién la aceptó. Es de solo lectura: el texto lo versiona el
/// equipo y no se edita desde la aplicación.
class TermsAdminScreen extends StatefulWidget {
  const TermsAdminScreen({super.key});

  @override
  State<TermsAdminScreen> createState() => _TermsAdminScreenState();
}

class _TermsAdminScreenState extends State<TermsAdminScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TermsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TermsProvider>();
    final current = provider.current;
    final page = provider.page;
    final theme = Theme.of(context);

    Widget body;
    if (current == null || page == null) {
      body = provider.error != null ? ErrorView(message: provider.error!, onRetry: provider.load) : const LoadingView();
    } else {
      body = ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (current.privacyNotice ?? '').trim().isEmpty ? current.title : 'Términos y condiciones y aviso de privacidad',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Versión vigente ${current.version}${current.publishedAt == null ? '' : ' · publicada el ${formatDate(current.publishedAt!.toLocal())}'}',
                    key: const ValueKey('terms-admin-version'),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LegalTextsView(document: current),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: Text('Aceptaciones', style: theme.textTheme.titleMedium)),
              Text('${page.pending} pendientes de aceptar', key: const ValueKey('terms-pending'), style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (page.items.isEmpty)
            const EmptyView(message: 'Todavía nadie ha aceptado esta versión')
          else
            Card(
              child: Column(
                children: [
                  for (final item in page.items)
                    ListTile(
                      key: ValueKey('aceptacion-${item.userId}'),
                      title: Text(item.name),
                      subtitle: Text(item.username),
                      trailing: Text(item.acceptedAt == null ? '' : formatDateTime(item.acceptedAt!)),
                    ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                key: const ValueKey('terms-anterior'),
                tooltip: 'Página anterior',
                onPressed: page.page > 1 ? () => provider.goTo(page.page - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Página ${page.page} de ${page.pages}'),
              IconButton(
                key: const ValueKey('terms-siguiente'),
                tooltip: 'Página siguiente',
                onPressed: page.page < page.pages ? () => provider.goTo(page.page + 1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'Términos y privacidad', subtitle: 'Términos y condiciones, aviso de privacidad y quién los ha aceptado'),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: body),
        ],
      ),
    );
  }
}
