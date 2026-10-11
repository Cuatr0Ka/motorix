import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mechanic.dart';
import '../services/api_client.dart';
import '../services/orders_service.dart';

/// Lista desplegable de mecánicos activos. El valor `null` representa [noneLabel]
/// («Sin asignar» en formularios, «Todos» en filtros).
class MechanicDropdown extends StatefulWidget {
  const MechanicDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Mecánico',
    this.noneLabel = 'Sin asignar',
    this.enabled = true,
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final String label;
  final String noneLabel;
  final bool enabled;

  @override
  State<MechanicDropdown> createState() => _MechanicDropdownState();
}

class _MechanicDropdownState extends State<MechanicDropdown> {
  List<Mechanic>? _mechanics;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final mechanics = await context.read<OrdersService>().listMechanics();
      if (mounted) setState(() => _mechanics = mechanics);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mechanics = _mechanics;
    // Si el valor actual ya no está entre los activos (por ejemplo, se desactivó), no se ofrece como opción.
    final value = mechanics != null && mechanics.any((m) => m.id == widget.value) ? widget.value : null;
    return DropdownButtonFormField<int?>(
      key: ValueKey('mecanico-${mechanics?.length}-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: widget.label, errorText: _error),
      items: [
        DropdownMenuItem<int?>(value: null, child: Text(widget.noneLabel)),
        for (final mechanic in mechanics ?? const <Mechanic>[])
          DropdownMenuItem<int?>(value: mechanic.id, child: Text(mechanic.name, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: widget.enabled && mechanics != null ? widget.onChanged : null,
    );
  }
}
