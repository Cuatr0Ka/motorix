import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/client.dart';
import '../services/api_client.dart';
import '../services/clients_service.dart';
import '../utils/tokens.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';

/// Formulario de cliente. Con [existing] edita ese cliente; sin él, registra uno nuevo.
/// Termina devolviendo (`pop`) el cliente guardado, o nada si se cancela.
class ClientFormScreen extends StatefulWidget {
  const ClientFormScreen({super.key, this.existing});

  final Client? existing;

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _address = TextEditingController(text: widget.existing?.address);

  /// Errores por campo devueltos por el servidor; se limpian al editar ese campo.
  final Map<String, String> _serverErrors = {};
  bool _dirty = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  void _changed(String field) {
    if (!_dirty || _serverErrors.containsKey(field)) {
      setState(() {
        _dirty = true;
        _serverErrors.remove(field);
      });
    }
  }

  String? _validateName(String? value) {
    if (_serverErrors['name'] != null) return _serverErrors['name'];
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'El nombre es obligatorio.';
    if (text.length > 120) return 'El nombre no puede pasar de 120 caracteres.';
    return null;
  }

  String? _validatePhone(String? value) {
    if (_serverErrors['phone'] != null) return _serverErrors['phone'];
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'El teléfono es obligatorio.';
    if (text.length > 20) return 'El teléfono no puede pasar de 20 caracteres.';
    if (!RegExp(r'^[0-9+\s().-]+$').hasMatch(text)) {
      return 'El teléfono solo puede llevar dígitos, +, espacios, guiones o paréntesis.';
    }
    if (text.replaceAll(RegExp(r'\D'), '').length < 7) return 'El teléfono debe tener al menos 7 dígitos.';
    return null;
  }

  String? _validateEmail(String? value) {
    if (_serverErrors['email'] != null) return _serverErrors['email'];
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) return 'El correo no es válido.';
    return null;
  }

  String? _validateAddress(String? value) {
    if (_serverErrors['address'] != null) return _serverErrors['address'];
    if ((value?.trim().length ?? 0) > 255) return 'La dirección no puede pasar de 255 caracteres.';
    return null;
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final service = context.read<ClientsService>();
    final input = ClientInput(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
    );

    setState(() => _saving = true);
    try {
      final saved = await _send(service, input, confirmDuplicatePhone: false);
      if (saved == null) return; // la persona canceló la advertencia de teléfono duplicado
      _dirty = false;
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      _showServerError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Envía el cliente; ante un teléfono repetido pide confirmación y reintenta una vez.
  Future<Client?> _send(ClientsService service, ClientInput input, {required bool confirmDuplicatePhone}) async {
    try {
      return _isEdit
          ? await service.update(widget.existing!.id, input, confirmDuplicatePhone: confirmDuplicatePhone)
          : await service.create(input, confirmDuplicatePhone: confirmDuplicatePhone);
    } on ApiException catch (e) {
      if (e.code != 'PHONE_DUPLICATE' || confirmDuplicatePhone) rethrow;
      final matches = (e.detailsMap['matches'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => '${m['name']} — ${m['phone']}')
          .toList();
      if (!mounted) return null;
      // Mientras la persona decide, el botón deja de mostrar el indicador de progreso.
      setState(() => _saving = false);
      final confirmed = await showConfirmDialog(
        context,
        title: 'Posible cliente duplicado',
        message: 'Ya hay clientes registrados con ese teléfono. ¿Quieres guardar este cliente de todos modos?',
        extra: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final line in matches) Text('• $line')],
        ),
      );
      if (!confirmed || !mounted) return null;
      setState(() => _saving = true);
      return _send(service, input, confirmDuplicatePhone: true);
    }
  }

  void _showServerError(ApiException e) {
    final fields = e.fieldErrors;
    if (fields.isNotEmpty) {
      setState(() {
        for (final error in fields) {
          _serverErrors[error.field] = error.message;
        }
      });
      _formKey.currentState?.validate();
    } else if (e.code == 'EMAIL_DUPLICATE') {
      setState(() => _serverErrors['email'] = e.message);
      _formKey.currentState?.validate();
    } else {
      showFailure(context, e.message);
    }
  }

  Future<void> _confirmExit() async {
    final leave = await showConfirmDialog(
      context,
      title: 'Salir sin guardar',
      message: 'Tienes cambios sin guardar. ¿Seguro que quieres salir?',
    );
    if (leave && mounted) {
      setState(() => _dirty = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: _isEdit ? 'Editar cliente' : 'Nuevo cliente',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _name,
                    autofocus: true,
                    onChanged: (_) => _changed('name'),
                    decoration: const InputDecoration(labelText: 'Nombre completo *'),
                    validator: _validateName,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => _changed('phone'),
                    decoration: const InputDecoration(labelText: 'Teléfono *'),
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => _changed('email'),
                    decoration: const InputDecoration(labelText: 'Correo electrónico'),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _address,
                    onChanged: (_) => _changed('address'),
                    decoration: const InputDecoration(labelText: 'Dirección'),
                    validator: _validateAddress,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Guardar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
