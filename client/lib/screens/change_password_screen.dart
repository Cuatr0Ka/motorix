import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../utils/password_policy.dart';
import '../utils/tokens.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';

/// Cambio de la contraseña propia: exige la actual y valida la política mínima.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _saving = false;
  final Map<String, String> _serverErrors = {};

  @override
  void dispose() {
    for (final controller in [_current, _new, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field)) setState(() => _serverErrors.remove(field));
  }

  String? _validateCurrent(String? value) {
    if (_serverErrors['currentPassword'] != null) return _serverErrors['currentPassword'];
    if (value == null || value.isEmpty) return 'Escribe tu contraseña actual.';
    return null;
  }

  String? _validateNew(String? value) {
    if (_serverErrors['newPassword'] != null) return _serverErrors['newPassword'];
    if (value == null || value.isEmpty) return 'Escribe la contraseña nueva.';
    if (value == _current.text) return 'La contraseña nueva debe ser distinta a la actual.';
    return checkPasswordPolicy(value);
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Confirma la contraseña nueva.';
    if (value != _new.text) return 'Las contraseñas no coinciden.';
    return null;
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthService>();
    setState(() => _saving = true);
    try {
      await auth.changePassword(_current.text, _new.text);
      if (!mounted) return;
      _current.clear();
      _new.clear();
      _confirm.clear();
      _formKey.currentState?.reset();
      showSuccess(context, 'Contraseña actualizada correctamente.');
    } on ApiException catch (e) {
      _showServerError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showServerError(ApiException e) {
    final field = switch (e.code) {
      'INVALID_CREDENTIALS' => 'currentPassword',
      'PASSWORD_POLICY' || 'SAME_PASSWORD' => 'newPassword',
      _ => null,
    };
    if (field != null) {
      setState(() => _serverErrors[field] =
          e.code == 'INVALID_CREDENTIALS' ? 'La contraseña actual es incorrecta.' : e.message);
      _formKey.currentState?.validate();
    } else {
      showFailure(context, e.message);
    }
  }

  InputDecoration _decoration(String label, {String? helper}) => InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Mostrar contraseñas' : 'Ocultar contraseñas',
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeader(
                  title: 'Cambiar contraseña',
                  subtitle: 'La contraseña nueva debe cumplir la política mínima de seguridad',
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _current,
                  obscureText: _obscure,
                  onChanged: (_) => _clearServerError('currentPassword'),
                  decoration: _decoration('Contraseña actual *'),
                  validator: _validateCurrent,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _new,
                  obscureText: _obscure,
                  onChanged: (_) => _clearServerError('newPassword'),
                  decoration: _decoration('Contraseña nueva *', helper: kPasswordPolicyHint),
                  validator: _validateNew,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  onFieldSubmitted: (_) => _save(),
                  decoration: _decoration('Confirmar contraseña nueva *'),
                  validator: _validateConfirm,
                ),
                const SizedBox(height: AppSpacing.xl),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Guardar contraseña'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
