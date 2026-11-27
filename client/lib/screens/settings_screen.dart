import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/service_type.dart';
import '../models/settings.dart';
import '../providers/service_types_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/status_labels.dart';
import '../utils/tokens.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';
import '../widgets/status_chip.dart';

/// Configuración del taller (solo administración): datos del taller, márgenes de mantenimiento y catálogo de tipos de
/// servicio. Cada pestaña se llena con su historia del Sprint 7.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SettingsProvider>().load();
      context.read<ServiceTypesProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Configuración',
            subtitle: 'Datos del taller, márgenes de mantenimiento y tipos de servicio',
          ),
          const SizedBox(height: AppSpacing.lg),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(key: ValueKey('pestana-taller'), text: 'Taller'),
              Tab(key: ValueKey('pestana-mantenimiento'), text: 'Mantenimiento'),
              Tab(key: ValueKey('pestana-tipos-servicio'), text: 'Tipos de servicio'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _ShopTab(),
                _MaintenanceTab(),
                _ServiceTypesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tono del chip de origen de un valor.
StatusTone _toneOf(SettingSource source) {
  switch (source) {
    case SettingSource.stored:
      return StatusTone.success;
    case SettingSource.env:
      return StatusTone.active;
    case SettingSource.defaults:
      return StatusTone.neutral;
  }
}

/// Chip con el origen de un valor (siempre lleva texto además del color).
class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.source});

  final SettingSource source;

  @override
  Widget build(BuildContext context) => StatusChip(label: source.label, tone: _toneOf(source));
}

class _ShopTab extends StatelessWidget {
  const _ShopTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final snapshot = provider.snapshot;
    if (snapshot == null) {
      if (provider.error != null) return ErrorView(message: provider.error!, onRetry: provider.load);
      return const LoadingView();
    }
    return SingleChildScrollView(child: _ShopForm(snapshot: snapshot));
  }
}

class _ShopForm extends StatefulWidget {
  const _ShopForm({required this.snapshot});

  final SettingsSnapshot snapshot;

  @override
  State<_ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends State<_ShopForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.snapshot.shop.name);
  late final TextEditingController _address = TextEditingController(text: widget.snapshot.shop.address);
  late final TextEditingController _phone = TextEditingController(text: widget.snapshot.shop.phone);
  late final TextEditingController _email = TextEditingController(text: widget.snapshot.shop.email);

  @override
  void dispose() {
    for (final controller in [_name, _address, _phone, _email]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Campos que cambiaron respecto de lo que está guardado en el servidor.
  Map<String, String> _changes() {
    final shop = widget.snapshot.shop;
    return {
      if (_name.text.trim() != shop.name) 'name': _name.text.trim(),
      if (_address.text.trim() != shop.address) 'address': _address.text.trim(),
      if (_phone.text.trim() != shop.phone) 'phone': _phone.text.trim(),
      if (_email.text.trim() != shop.email) 'email': _email.text.trim(),
    };
  }

  String? _validateName(String? value) {
    final serverError = context.read<SettingsProvider>().fieldErrors['shop.name'];
    if (serverError != null) return serverError;
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'El nombre del taller es obligatorio.';
    if (text.length > 100) return 'El nombre del taller no puede pasar de 100 caracteres.';
    return null;
  }

  String? _validateAddress(String? value) {
    final serverError = context.read<SettingsProvider>().fieldErrors['shop.address'];
    if (serverError != null) return serverError;
    if ((value?.trim().length ?? 0) > 200) return 'La dirección no puede pasar de 200 caracteres.';
    return null;
  }

  String? _validateEmail(String? value) {
    final serverError = context.read<SettingsProvider>().fieldErrors['shop.email'];
    if (serverError != null) return serverError;
    final text = value?.trim() ?? '';
    if (text.length > 254) return 'El correo no puede pasar de 254 caracteres.';
    if (text.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
      return 'El correo no tiene un formato válido.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final serverError = context.read<SettingsProvider>().fieldErrors['shop.phone'];
    if (serverError != null) return serverError;
    final text = value?.trim() ?? '';
    if (text.length > 20) return 'El teléfono no puede pasar de 20 caracteres.';
    if (!RegExp(r'^[0-9+\-() ]*$').hasMatch(text)) {
      return 'El teléfono solo puede llevar dígitos, espacios, +, - y paréntesis.';
    }
    return null;
  }

  Future<void> _save() async {
    final provider = context.read<SettingsProvider>();
    // Se limpian los errores del servidor de un intento anterior y se valida en pantalla antes de enviar.
    provider.clearFieldErrors();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final changes = _changes();
    if (changes.isEmpty) return;
    final failure = await provider.save({'shop': changes});    if (!mounted) return;
    _formKey.currentState?.validate();
    if (failure == null) {
      showSuccess(context, 'Datos del taller guardados. Los tickets nuevos los usarán; los emitidos no cambian.');
    } else if (provider.fieldErrors.isEmpty) {
      showFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final snapshot = provider.snapshot ?? widget.snapshot;
    final changed = _changes().isNotEmpty;
    final theme = Theme.of(context);

    Widget field({
      required String label,
      required TextEditingController controller,
      required Key fieldKey,
      required String sourceKey,
      required String? Function(String?) validator,
      required int maxLength,
      String? hint,
      TextInputType? keyboard,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: AppSpacing.sm),
              KeyedSubtree(key: ValueKey('origen-$sourceKey'), child: SourceChip(source: snapshot.sourceOf(sourceKey))),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            key: fieldKey,
            controller: controller,
            keyboardType: keyboard,
            maxLength: maxLength,
            decoration: InputDecoration(hintText: hint, counterText: ''),
            validator: validator,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            field(
              label: 'Nombre del taller',
              controller: _name,
              fieldKey: const ValueKey('campo-taller-nombre'),
              sourceKey: 'shop.name',
              validator: _validateName,
              maxLength: 100,
            ),
            field(
              label: 'Dirección',
              controller: _address,
              fieldKey: const ValueKey('campo-taller-direccion'),
              sourceKey: 'shop.address',
              validator: _validateAddress,
              maxLength: 200,
              hint: 'Opcional',
            ),
            field(
              label: 'Teléfono',
              controller: _phone,
              fieldKey: const ValueKey('campo-taller-telefono'),
              sourceKey: 'shop.phone',
              validator: _validatePhone,
              maxLength: 20,
              hint: 'Opcional',
              keyboard: TextInputType.phone,
            ),
            field(
              label: 'Correo para asuntos de privacidad',
              controller: _email,
              fieldKey: const ValueKey('campo-taller-correo'),
              sourceKey: 'shop.email',
              validator: _validateEmail,
              maxLength: 254,
              hint: 'Opcional; aparece en el aviso de privacidad',
              keyboard: TextInputType.emailAddress,
            ),
            Text(
              'Nombre, dirección y teléfono se imprimen en los tickets nuevos (los ya emitidos conservan sus datos). Todos estos datos, con el correo, aparecen también en el aviso de privacidad y en los términos y condiciones.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const ValueKey('guardar-taller'),
              onPressed: (!changed || provider.saving) ? null : _save,
              child: Text(provider.saving ? 'Guardando…' : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceTab extends StatelessWidget {
  const _MaintenanceTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final snapshot = provider.snapshot;
    if (snapshot == null) {
      if (provider.error != null) return ErrorView(message: provider.error!, onRetry: provider.load);
      return const LoadingView();
    }
    return SingleChildScrollView(child: _MaintenanceForm(snapshot: snapshot));
  }
}

class _MaintenanceForm extends StatefulWidget {
  const _MaintenanceForm({required this.snapshot});

  final SettingsSnapshot snapshot;

  @override
  State<_MaintenanceForm> createState() => _MaintenanceFormState();
}

class _MaintenanceFormState extends State<_MaintenanceForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _days = TextEditingController(text: '${widget.snapshot.maintenance.warnDays}');
  late final TextEditingController _km = TextEditingController(text: '${widget.snapshot.maintenance.warnKm}');

  @override
  void dispose() {
    _days.dispose();
    _km.dispose();
    super.dispose();
  }

  Map<String, int> _changes() {
    final maintenance = widget.snapshot.maintenance;
    final days = int.tryParse(_days.text.trim());
    final km = int.tryParse(_km.text.trim());
    return {
      if (days != null && days != maintenance.warnDays) 'warnDays': days,
      if (km != null && km != maintenance.warnKm) 'warnKm': km,
    };
  }

  String? _validateRange(String? value, {required String serverKey, required int max, required String limit}) {
    final serverError = context.read<SettingsProvider>().fieldErrors[serverKey];
    if (serverError != null) return serverError;
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null) return 'Escribe un número entero.';
    if (number < 1 || number > max) return 'El valor debe estar entre 1 y $limit.';
    return null;
  }

  Future<void> _save() async {
    final provider = context.read<SettingsProvider>();
    provider.clearFieldErrors();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final changes = _changes();
    if (changes.isEmpty) return;
    final failure = await provider.save({'maintenance': changes});
    if (!mounted) return;
    _formKey.currentState?.validate();
    if (failure == null) {
      showSuccess(context, 'Márgenes de mantenimiento guardados. La lista de Mantenimientos, el panel y los avisos los usan desde ahora.');
    } else if (provider.fieldErrors.isEmpty) {
      showFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final snapshot = provider.snapshot ?? widget.snapshot;
    final theme = Theme.of(context);
    // Hay cambios si el texto difiere de lo guardado (aunque no sea un número válido: así se puede validar y marcar).
    final saved = widget.snapshot.maintenance;
    final changed = _days.text.trim() != '${saved.warnDays}' || _km.text.trim() != '${saved.warnKm}';

    Widget field({
      required String label,
      required TextEditingController controller,
      required Key fieldKey,
      required String sourceKey,
      required String serverKey,
      required int max,
      required String limit,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: AppSpacing.sm),
              KeyedSubtree(key: ValueKey('origen-$sourceKey'), child: SourceChip(source: snapshot.sourceOf(sourceKey))),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            key: fieldKey,
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(helperText: 'Entre 1 y $limit'),
            validator: (value) => _validateRange(value, serverKey: serverKey, max: max, limit: limit),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            field(
              label: 'Margen de Próximo (días)',
              controller: _days,
              fieldKey: const ValueKey('campo-margen-dias'),
              sourceKey: 'maintenance.warn_days',
              serverKey: 'maintenance.warnDays',
              max: 365,
              limit: '365',
            ),
            field(
              label: 'Margen de Próximo (km)',
              controller: _km,
              fieldKey: const ValueKey('campo-margen-km'),
              sourceKey: 'maintenance.warn_km',
              serverKey: 'maintenance.warnKm',
              max: 100000,
              limit: '100 000',
            ),
            Text(
              'Un mantenimiento es Próximo cuando falta este margen o menos, en días o en kilómetros.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const ValueKey('guardar-margenes'),
              onPressed: (!changed || provider.saving) ? null : _save,
              child: Text(provider.saving ? 'Guardando…' : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulario de alta o edición de un tipo de servicio. Devuelve (`pop`) los datos o nada si se cancela.
class _ServiceTypeDialog extends StatefulWidget {
  const _ServiceTypeDialog({this.existing});

  final ServiceType? existing;

  @override
  State<_ServiceTypeDialog> createState() => _ServiceTypeDialogState();
}

class _ServiceTypeDialogState extends State<_ServiceTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _days = TextEditingController(text: widget.existing?.intervalDays?.toString() ?? '');
  late final _km = TextEditingController(text: widget.existing?.intervalKm?.toString() ?? '');
  String? _intervalError;

  @override
  void dispose() {
    _name.dispose();
    _days.dispose();
    _km.dispose();
    super.dispose();
  }

  String? _validateInterval(String? value, {required int max, required String limit}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    if (number == null) return 'Escribe un número entero.';
    if (number < 1 || number > max) return 'El valor debe estar entre 1 y $limit.';
    return null;
  }

  void _save() {
    final valid = _formKey.currentState?.validate() ?? false;
    final hasInterval = _days.text.trim().isNotEmpty || _km.text.trim().isNotEmpty;
    setState(() => _intervalError = hasInterval ? null : 'Indica al menos un intervalo: en días, en kilómetros o ambos.');
    if (!valid || !hasInterval) return;
    Navigator.of(context).pop(
      ServiceTypeInput(
        name: _name.text.trim(),
        intervalDays: int.tryParse(_days.text.trim()),
        intervalKm: int.tryParse(_km.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo tipo de servicio' : 'Editar tipo de servicio'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const ValueKey('tipo-nombre'),
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'El nombre es obligatorio.';
                  if (text.length > 100) return 'El nombre no puede pasar de 100 caracteres.';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const ValueKey('tipo-dias'),
                controller: _days,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Intervalo en días', helperText: 'Entre 1 y 3 650'),
                validator: (value) => _validateInterval(value, max: 3650, limit: '3 650'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const ValueKey('tipo-km'),
                controller: _km,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Intervalo en kilómetros', helperText: 'Entre 1 y 1 000 000'),
                validator: (value) => _validateInterval(value, max: 1000000, limit: '1 000 000'),
              ),
              if (_intervalError != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _intervalError!,
                    key: const ValueKey('tipo-intervalo-error'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

class _ServiceTypesTab extends StatelessWidget {
  const _ServiceTypesTab();

  Future<void> _create(BuildContext context) async {
    final provider = context.read<ServiceTypesProvider>();
    final input = await showDialog<ServiceTypeInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ServiceTypeDialog(),
    );
    if (input == null || !context.mounted) return;
    final failure = await provider.create(input);
    if (!context.mounted) return;
    failure == null ? showSuccess(context, 'Tipo de servicio creado correctamente.') : showFailure(context, failure);
  }

  Future<void> _edit(BuildContext context, ServiceType type) async {
    final provider = context.read<ServiceTypesProvider>();
    final input = await showDialog<ServiceTypeInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ServiceTypeDialog(existing: type),
    );
    if (input == null || !context.mounted) return;
    final failure = await provider.edit(type.id, input);
    if (!context.mounted) return;
    failure == null ? showSuccess(context, 'Tipo de servicio actualizado correctamente.') : showFailure(context, failure);
  }

  Future<void> _toggle(BuildContext context, ServiceType type) async {
    final provider = context.read<ServiceTypesProvider>();
    if (type.active) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Desactivar tipo de servicio',
        message: '¿Desactivar "${type.name}"? Ya no se podrá elegir en servicios nuevos. Las órdenes anteriores conservan el tipo.',
      );
      if (!confirmed || !context.mounted) return;
    }
    final failure = await provider.setActive(type.id, !type.active);
    if (!context.mounted) return;
    failure == null
        ? showSuccess(context, type.active ? 'Tipo de servicio desactivado.' : 'Tipo de servicio reactivado.')
        : showFailure(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServiceTypesProvider>();
    final items = provider.items;
    if (items == null) {
      if (provider.error != null) return ErrorView(message: provider.error!, onRetry: provider.load);
      return const LoadingView();
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Cada servicio de una orden puede llevar un tipo; con su intervalo se propone el próximo mantenimiento.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            FilledButton.icon(
              key: const ValueKey('nuevo-tipo-servicio'),
              onPressed: () => _create(context),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo tipo de servicio'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: items.isEmpty
              ? const EmptyView(message: 'Todavía no hay tipos de servicio')
              : ListView(
                  children: [
                    for (final type in items)
                      Card(
                        key: ValueKey('tipo-${type.id}'),
                        child: ListTile(
                          title: Text(type.name),
                          subtitle: Text('Días: ${type.intervalDays ?? '—'} · Km: ${type.intervalKm ?? '—'}'
                              '${type.inUse > 0 ? ' · En ${type.inUse} servicio(s)' : ''}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusChip(label: type.active ? 'Activo' : 'Inactivo', tone: type.active ? StatusTone.success : StatusTone.neutral),
                              IconButton(
                                key: ValueKey('editar-tipo-${type.id}'),
                                tooltip: 'Editar',
                                onPressed: () => _edit(context, type),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                key: ValueKey('estado-tipo-${type.id}'),
                                tooltip: type.active ? 'Desactivar' : 'Reactivar',
                                onPressed: () => _toggle(context, type),
                                icon: Icon(type.active ? Icons.block_outlined : Icons.check_circle_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
