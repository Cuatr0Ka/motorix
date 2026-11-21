import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audit_entry.dart';
import '../providers/audit_provider.dart';
import '../utils/formatters.dart';
import '../utils/tokens.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';

/// Bitácora de acciones sensibles (solo administración, solo lectura): quién, cuándo, qué y sobre qué.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  String? _dateError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuditProvider>().init();
    });
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  bool _validDate(String text) {
    if (text.isEmpty) return true;
    if (!_datePattern.hasMatch(text)) return false;
    final parsed = DateTime.tryParse(text);
    return parsed != null && formatIso(parsed) == text;
  }

  static String formatIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _applyDates() {
    final from = _from.text.trim();
    final to = _to.text.trim();
    if (!_validDate(from) || !_validDate(to)) {
      setState(() => _dateError = 'Usa el formato AAAA-MM-DD en las fechas.');
      return;
    }
    setState(() => _dateError = null);
    context.read<AuditProvider>().applyFilters(from: from, to: to);
  }

  void _clear() {
    _from.clear();
    _to.clear();
    setState(() => _dateError = null);
    context.read<AuditProvider>().clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuditProvider>();
    final theme = Theme.of(context);
    final page = provider.page;

    Widget body;
    if (page == null) {
      body = provider.error != null ? ErrorView(message: provider.error!, onRetry: provider.load) : const LoadingView();
    } else if (page.items.isEmpty) {
      body = const EmptyView(message: 'No hay registros con esos filtros');
    } else {
      body = ListView(
        children: [
          for (final entry in page.items)
            Card(
              key: ValueKey('bitacora-${entry.id}'),
              child: ListTile(
                title: Text(entry.summary),
                subtitle: Text('${formatDateTime(entry.createdAt)} · ${entry.actorName ?? 'Sistema'} · ${entry.entityLabel}'),
                trailing: Chip(label: Text(auditActionLabel(entry.action)), visualDensity: VisualDensity.compact),
              ),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'Bitácora', subtitle: 'Acciones sensibles del sistema (solo lectura)'),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 160,
                child: TextField(
                  key: const ValueKey('bitacora-desde'),
                  controller: _from,
                  decoration: const InputDecoration(labelText: 'Desde (AAAA-MM-DD)'),
                  onSubmitted: (_) => _applyDates(),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  key: const ValueKey('bitacora-hasta'),
                  controller: _to,
                  decoration: const InputDecoration(labelText: 'Hasta (AAAA-MM-DD)'),
                  onSubmitted: (_) => _applyDates(),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<int?>(
                  key: const ValueKey('bitacora-usuario'),
                  initialValue: provider.userId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Usuario'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
                    for (final user in provider.users) DropdownMenuItem<int?>(value: user.id, child: Text(user.name)),
                  ],
                  onChanged: (value) => provider.applyFilters(userId: value, clearUser: value == null),
                ),
              ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String?>(
                  key: const ValueKey('bitacora-accion'),
                  initialValue: provider.action,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Acción'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                    for (final entry in kAuditActionLabels.entries) DropdownMenuItem<String?>(value: entry.key, child: Text(entry.value)),
                  ],
                  onChanged: (value) => provider.applyFilters(action: value, clearAction: value == null),
                ),
              ),
              FilledButton(key: const ValueKey('bitacora-filtrar'), onPressed: _applyDates, child: const Text('Filtrar')),
              if (provider.hasFilters || _from.text.isNotEmpty || _to.text.isNotEmpty)
                OutlinedButton(key: const ValueKey('bitacora-limpiar'), onPressed: _clear, child: const Text('Limpiar filtros')),
            ],
          ),
          if (_dateError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(_dateError!, key: const ValueKey('bitacora-error-fecha'), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger)),
            ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: body),
          if (page != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('${page.total} registro(s)'),
                const SizedBox(width: AppSpacing.md),
                IconButton(
                  key: const ValueKey('bitacora-anterior'),
                  tooltip: 'Página anterior',
                  onPressed: page.page > 1 ? () => provider.load(page: page.page - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Página ${page.page} de ${page.pages}'),
                IconButton(
                  key: const ValueKey('bitacora-siguiente'),
                  tooltip: 'Página siguiente',
                  onPressed: page.page < page.pages ? () => provider.load(page: page.page + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
