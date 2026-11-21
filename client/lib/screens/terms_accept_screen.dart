import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../utils/tokens.dart';
import '../widgets/state_views.dart';

/// Pantalla de aceptación de los términos y condiciones: se muestra tras iniciar sesión (o a mitad de sesión si se publica
/// una versión nueva) y bloquea el resto de la aplicación hasta aceptar o salir.
class TermsAcceptScreen extends StatefulWidget {
  const TermsAcceptScreen({super.key});

  @override
  State<TermsAcceptScreen> createState() => _TermsAcceptScreenState();
}

class _TermsAcceptScreenState extends State<TermsAcceptScreen> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final terms = session.pendingTerms;
    final theme = Theme.of(context);

    Widget content;
    if (terms == null) {
      content = session.termsError != null
          ? ErrorView(message: session.termsError!, onRetry: session.reloadTerms)
          : const LoadingView();
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(terms.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text('Versión ${terms.version}', key: const ValueKey('terms-version'), style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(8)),
              child: Scrollbar(
                child: SingleChildScrollView(
                  key: const ValueKey('terms-body'),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(terms.body, style: theme.textTheme.bodyMedium),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          CheckboxListTile(
            key: const ValueKey('terms-check'),
            value: _checked,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('He leído y acepto los términos y condiciones'),
            onChanged: session.termsBusy ? null : (value) => setState(() => _checked = value ?? false),
          ),
          if (session.termsError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(session.termsError!, key: const ValueKey('terms-error'), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                key: const ValueKey('terms-reject'),
                onPressed: session.termsBusy ? null : session.rejectTerms,
                child: const Text('Rechazar y salir'),
              ),
              const SizedBox(width: AppSpacing.md),
              FilledButton(
                key: const ValueKey('terms-accept'),
                onPressed: (!_checked || session.termsBusy) ? null : session.acceptTerms,
                child: Text(session.termsBusy ? 'Guardando…' : 'Aceptar y continuar'),
              ),
            ],
          ),
        ],
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: content),
        ),
      ),
    );
  }
}
