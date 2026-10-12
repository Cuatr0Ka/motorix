import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../utils/tokens.dart';

/// Pantalla de acceso: un único campo para usuario o correo electrónico.
/// En pantallas anchas muestra un panel de marca junto al formulario.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const double _splitBreakpoint = 900;

  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await context.read<SessionProvider>().login(_identifier.text, _password.text);
  }

  /// Campo con ícono de prefijo y relleno vertical suficiente para que la
  /// etiqueta flotante no quede recortada por el borde.
  InputDecoration _fieldDecoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
      );

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final theme = Theme.of(context);

    final form = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Bienvenido', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Inicia sesión para continuar',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (session.notice != null) ...[
            _Message(text: session.notice!, color: AppColors.warning),
            const SizedBox(height: AppSpacing.lg),
          ],
          TextFormField(
            controller: _identifier,
            enabled: !session.isLoading,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration('Usuario o correo', Icons.person_outline),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Escribe tu usuario o correo.' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _password,
            enabled: !session.isLoading,
            obscureText: _obscure,
            onFieldSubmitted: (_) => _submit(),
            decoration: _fieldDecoration('Contraseña', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (value) => (value == null || value.isEmpty) ? 'Escribe tu contraseña.' : null,
          ),
          AnimatedSize(
            duration: AppDurations.appear,
            curve: AppCurves.enter,
            child: session.error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: _Message(text: session.error!, color: AppColors.danger),
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: session.isLoading ? null : _submit,
            child: session.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Iniciar sesión'),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '¿Problemas para ingresar? Contacta al administrador.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _splitBreakpoint;
          final formArea = Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: wide
                    ? form
                    : Container(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.panel),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(child: _Logo(size: 64)),
                            const SizedBox(height: AppSpacing.xl),
                            form,
                          ],
                        ),
                      ),
              ),
            ),
          );

          if (!wide) return formArea;
          return ColoredBox(
            color: AppColors.surface,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: FractionallySizedBox(widthFactor: 0.44, heightFactor: 1, child: formArea),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.58,
                    heightFactor: 1,
                    child: ClipPath(clipper: _DiagonalClipper(), child: const _BrandPanel()),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Logo de Motorix (PNG recortado, con fondo transparente).
/// Con [light] se tiñe de crema para usarlo sobre fondos oscuros.
class _Logo extends StatelessWidget {
  const _Logo({required this.size, this.light = false});

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Logo de Motorix',
    );
    if (!light) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(AppColors.onSidebar, BlendMode.srcIn),
      child: image,
    );
  }
}

/// Recorta el panel de marca con un borde derecho en diagonal
/// (más ancho arriba, más angosto abajo).
class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(size.width, 0)
    ..lineTo(size.width * 0.86, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Panel de marca visible en pantallas anchas.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.sidebar, AppColors.sidebarActive],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(right: 40, top: -160, child: _Ring(size: 420)),
          const Positioned(left: -140, bottom: -180, child: _Ring(size: 460)),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl * 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const _Logo(size: 104, light: true),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Motorix',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.onSidebar,
                    fontSize: 40,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: 48,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Text(
                    'La gestión de tu taller, en un solo lugar.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.onSidebar.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '© 2026 Motorix',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.onSidebarMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Círculo de contorno tenue usado como adorno del panel de marca.
class _Ring extends StatelessWidget {
  const _Ring({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 2),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color)),
    );
  }
}
