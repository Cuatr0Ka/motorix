import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../models/paged_result.dart';
import '../utils/tokens.dart';

/// Tabla densa con el estilo del sistema de diseño (borde fino, encabezado discreto, hover suave).
/// Debe colocarse en un espacio con altura acotada (por ejemplo, dentro de un `Expanded`).
class AppDataTable extends StatelessWidget {
  const AppDataTable({super.key, required this.columns, required this.rows, this.minWidth = 640});

  final List<DataColumn2> columns;
  final List<DataRow2> rows;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: DataTable2(
        columns: columns,
        rows: rows,
        minWidth: minWidth,
        columnSpacing: AppSpacing.md,
        horizontalMargin: AppSpacing.lg,
        headingRowHeight: 44,
        dataRowHeight: 52,
        showCheckboxColumn: false,
      ),
    );
  }
}

/// Campo de búsqueda que espera un instante tras la última tecla antes de avisar.
class DebouncedSearchField extends StatefulWidget {
  const DebouncedSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.initialValue = '',
    this.delay = const Duration(milliseconds: 350),
  });

  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final Duration delay;

  @override
  State<DebouncedSearchField> createState() => _DebouncedSearchFieldState();
}

class _DebouncedSearchFieldState extends State<DebouncedSearchField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _timer?.cancel();
    _timer = Timer(widget.delay, () => widget.onChanged(value.trim()));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _changed,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar búsqueda',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _controller.clear();
                  _timer?.cancel();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
      ),
    );
  }
}

/// Barra de paginación: "1–20 de 134" con botones anterior y siguiente.
class PaginationBar extends StatelessWidget {
  const PaginationBar({super.key, required this.result, required this.onPage});

  final PagedResult<dynamic> result;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('${result.firstItem}–${result.lastItem} de ${result.total}', style: style),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Página anterior',
            onPressed: result.page > 1 ? () => onPage(result.page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Página siguiente',
            onPressed: result.page < result.totalPages ? () => onPage(result.page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
