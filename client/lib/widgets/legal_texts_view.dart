import 'package:flutter/material.dart';

import '../models/terms.dart';
import '../utils/tokens.dart';

/// Documento legal que se muestra: términos y condiciones o aviso de privacidad.
enum LegalText { terms, privacy }

/// Muestra los términos y condiciones y el aviso de privacidad como dos textos separados, con un selector arriba.
/// Si la versión no trae aviso aparte (versiones anteriores a la 2.0), muestra solo los términos, sin selector.
class LegalTextsView extends StatefulWidget {
  const LegalTextsView({super.key, required this.document, this.expand = false});

  final TermsDocument document;

  /// `true`: el texto ocupa el espacio disponible y se desplaza dentro de su recuadro (pantalla de aceptación).
  /// `false`: el texto se muestra completo, para usarlo dentro de una lista que ya se desplaza.
  final bool expand;

  @override
  State<LegalTextsView> createState() => _LegalTextsViewState();
}

class _LegalTextsViewState extends State<LegalTextsView> {
  LegalText _selected = LegalText.terms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final privacy = widget.document.privacyNotice;
    final hasPrivacy = privacy != null && privacy.trim().isNotEmpty;
    final showing = hasPrivacy ? _selected : LegalText.terms;
    final text = showing == LegalText.privacy ? privacy! : widget.document.body;
    final bodyKey = ValueKey(showing == LegalText.privacy ? 'privacy-body' : 'terms-body');

    final textWidget = Text(text, style: theme.textTheme.bodyMedium);
    final box = DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(8)),
      child: widget.expand
          ? Scrollbar(
              child: SingleChildScrollView(
                key: bodyKey,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(width: double.infinity, child: textWidget),
              ),
            )
          : Padding(
              key: bodyKey,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(width: double.infinity, child: textWidget),
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (hasPrivacy) ...[
          SegmentedButton<LegalText>(
            key: const ValueKey('legal-selector'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: LegalText.terms, icon: Icon(Icons.gavel_outlined), label: Text('Términos y condiciones')),
              ButtonSegment(value: LegalText.privacy, icon: Icon(Icons.privacy_tip_outlined), label: Text('Aviso de privacidad')),
            ],
            selected: {showing},
            onSelectionChanged: (value) => setState(() => _selected = value.first),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (widget.expand) Expanded(child: box) else box,
      ],
    );
  }
}
