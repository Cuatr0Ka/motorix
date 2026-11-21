import 'package:flutter/material.dart';

import '../models/report.dart';
import '../providers/reports_provider.dart';
import '../utils/tokens.dart';

/// Selector del periodo de un reporte: Hoy, Esta semana, Este mes y Rango (dos fechas). Muestra el periodo elegido y rechaza
/// más de un año.
class PeriodSelector extends StatefulWidget {
  const PeriodSelector({super.key, required this.period, required this.preset, required this.onSelect});

  final ReportPeriod period;
  final String preset;

  /// Pide aplicar un periodo; devuelve el mensaje de error o null si se aplicó.
  final Future<String?> Function(String preset, {ReportPeriod? custom}) onSelect;

  @override
  State<PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<PeriodSelector> {
  late final _from = TextEditingController(text: widget.period.fromText);
  late final _to = TextEditingController(text: widget.period.toText);
  bool _custom = false;
  String? _error;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  DateTime? _parse(String text) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
    final parsed = DateTime.tryParse(text);
    return parsed != null && ReportPeriod.iso(parsed) == text ? parsed : null;
  }

  Future<void> _preset(String preset) async {
    setState(() {
      _custom = false;
      _error = null;
    });
    final error = await widget.onSelect(preset);
    if (mounted) setState(() => _error = error);
  }

  Future<void> _applyRange() async {
    final from = _parse(_from.text.trim());
    final to = _parse(_to.text.trim());
    if (from == null || to == null) {
      setState(() => _error = 'Usa el formato AAAA-MM-DD en las dos fechas.');
      return;
    }
    final error = await widget.onSelect('range', custom: ReportPeriod(from: from, to: to));
    if (mounted) setState(() => _error = error);
  }

  Future<void> _pick(TextEditingController controller) async {
    final initial = _parse(controller.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(DateTime.now().year + 1));
    if (picked != null) setState(() => controller.text = ReportPeriod.iso(picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _custom ? 'range' : widget.preset;

    Widget chip(String key, String label) => ChoiceChip(
          key: ValueKey('periodo-$key'),
          label: Text(label),
          selected: selected == key,
          onSelected: (_) => key == 'range' ? setState(() => _custom = true) : _preset(key),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            chip('today', 'Hoy'),
            chip('week', 'Esta semana'),
            chip('month', 'Este mes'),
            chip('range', 'Rango'),
            Text(
              'Periodo: del ${widget.period.fromText} al ${widget.period.toText}',
              key: const ValueKey('periodo-texto'),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        if (_custom) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 190,
                child: TextField(
                  key: const ValueKey('periodo-desde'),
                  controller: _from,
                  decoration: InputDecoration(
                    labelText: 'Desde (AAAA-MM-DD)',
                    suffixIcon: IconButton(tooltip: 'Elegir fecha', icon: const Icon(Icons.calendar_today_outlined, size: 18), onPressed: () => _pick(_from)),
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: TextField(
                  key: const ValueKey('periodo-hasta'),
                  controller: _to,
                  decoration: InputDecoration(
                    labelText: 'Hasta (AAAA-MM-DD)',
                    suffixIcon: IconButton(tooltip: 'Elegir fecha', icon: const Icon(Icons.calendar_today_outlined, size: 18), onPressed: () => _pick(_to)),
                  ),
                ),
              ),
              FilledButton(key: const ValueKey('periodo-aplicar'), onPressed: _applyRange, child: const Text('Aplicar')),
            ],
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(_error!, key: const ValueKey('periodo-error'), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger)),
          ),
      ],
    );
  }
}

/// Mensaje de error de un periodo (para reutilizar la validación fuera del selector).
String? periodError(ReportPeriod period) => ReportsProvider.validate(period);
