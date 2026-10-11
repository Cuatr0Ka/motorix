import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/users_service.dart';
import '../utils/password_policy.dart';
import '../utils/tokens.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/state_views.dart';

/// Alta de usuario (solo administrador). Devuelve (`pop`) el usuario creado, o nada si se cancela.
class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  UserRole? _role;
  bool _obscure = true;
  bool _dirty = false;
  bool _saving = false;
  final Map<String, String> _serverErrors = {};

  @override
  void dispose() {
    for (final controller in [_username, _name, _email, _password]) {
      controller.dispose();
    }
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

  String? _validateUsername(String? value) {
    if (_serverErrors['username'] != null) return _serverErrors['username'];
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'El usuario es obligatorio.';
    if (text.length < 3) return 'El usuario debe tener al menos 3 caracteres.';
    if (text.length > 50) return 'El usuario no puede pasar de 50 caracteres.';
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(text)) {
      return 'El usuario solo puede llevar letras, números, punto, guion y guion bajo.';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (_serverErrors['name'] != null) return _serverErrors['name'];
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'El nombre es obligatorio.';
    if (text.length > 120) return 'El nombre no puede pasar de 120 caracteres.';
    return null;
  }

  String? _validateEmail(String? value) {
    if (_serverErrors['email'] != null) return _serverErrors['email'];
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'El correo es obligatorio.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) return 'El correo no es válido.';
    return null;
  }

  String? _validatePassword(String? value) {
    if (_serverErrors['password'] != null) return _serverErrors['password'];
    if (value == null || value.isEmpty) return 'La contraseña es obligatoria.';
    return checkPasswordPolicy(value);
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false) || _role == null) return;
    final service = context.read<UsersService>();
    setState(() => _saving = true);
    try {
      final created = await service.create(UserInput(
        username: _username.text.trim(),
        name: _name.text.trim(),
        email: _email.text.trim(),
        role: _role!,
        password: _password.text,
      ));
      _dirty = false;
      if (mounted) Navigator.of(context).pop(created);
    } on ApiException catch (e) {
      _showServerError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showServerError(ApiException e) {
    const byCode = {
      'USERNAME_DUPLICATE': 'username',
      'EMAIL_DUPLICATE': 'email',
      'PASSWORD_POLICY': 'password',
    };
    final fields = e.fieldErrors;
    if (fields.isNotEmpty || byCode.containsKey(e.code)) {
      setState(() {
        for (final error in fields) {
          _serverErrors[error.field] = error.message;
        }
        final field = byCode[e.code];
        if (field != null) _serverErrors[field] = e.message;
      });
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
                  PageHeader(title: 'Nuevo usuario', onBack: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _username,
                    autofocus: true,
                    onChanged: (_) => _changed('username'),
                    decoration: const InputDecoration(labelText: 'Usuario *'),
                    validator: _validateUsername,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _name,
                    onChanged: (_) => _changed('name'),
                    decoration: const InputDecoration(labelText: 'Nombre completo *'),
                    validator: _validateName,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => _changed('email'),
                    decoration: const InputDecoration(labelText: 'Correo electrónico *'),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<UserRole>(
                    key: const ValueKey('rol'),
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Rol *'),
                    items: [
                      for (final role in UserRole.values) DropdownMenuItem(value: role, child: Text(role.label)),
                    ],
                    onChanged: (value) => setState(() {
                      _role = value;
                      _dirty = true;
                    }),
                    validator: (value) => value == null ? 'Selecciona un rol.' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    onChanged: (_) => _changed('password'),
                    decoration: InputDecoration(
                      labelText: 'Contraseña inicial *',
                      helperText: kPasswordPolicyHint,
                      helperMaxLines: 2,
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: _validatePassword,
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
