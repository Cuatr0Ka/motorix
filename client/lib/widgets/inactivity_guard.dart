import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';

/// Cierra la sesión tras un periodo sin actividad. Observa punteros, clics, desplazamiento y teclas; avisa a los
/// [warnAfter] (28 min) con un diálogo y cuenta regresiva, y cierra a los [logoutAfter] (30 min). Mientras hay actividad
/// consulta `GET /auth/me` como máximo cada [pingEvery] para mantener viva la sesión en el servidor.
class InactivityGuard extends StatefulWidget {
  const InactivityGuard({
    super.key,
    required this.child,
    this.warnAfter = const Duration(minutes: 28),
    this.logoutAfter = const Duration(minutes: 30),
    this.pingEvery = const Duration(minutes: 5),
  });

  final Widget child;
  final Duration warnAfter;
  final Duration logoutAfter;
  final Duration pingEvery;

  @override
  State<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends State<InactivityGuard> {
  Timer? _warnTimer;
  Timer? _logoutTimer;
  Timer? _pingTimer;
  Timer? _moveThrottle;
  bool _pingBlocked = true;
  bool _warningOpen = false;

  @override
  void initState() {
    super.initState();
    _restart();
    _blockPing();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _warnTimer?.cancel();
    _logoutTimer?.cancel();
    _pingTimer?.cancel();
    _moveThrottle?.cancel();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) _activity();
    return false;
  }

  void _blockPing() {
    _pingBlocked = true;
    _pingTimer?.cancel();
    _pingTimer = Timer(widget.pingEvery, () => _pingBlocked = false);
  }

  void _restart() {
    _warnTimer?.cancel();
    _logoutTimer?.cancel();
    _warnTimer = Timer(widget.warnAfter, _showWarning);
    _logoutTimer = Timer(widget.logoutAfter, _expire);
  }

  /// Actividad de la persona: reinicia los temporizadores (salvo mientras el aviso está abierto: ahí hay que pulsar el botón).
  void _activity() {
    if (_warningOpen || !mounted) return;
    _restart();
    if (!_pingBlocked) {
      _blockPing();
      context.read<SessionProvider>().refreshProfile();
    }
  }

  void _onMove() {
    if (_moveThrottle?.isActive ?? false) return;
    _moveThrottle = Timer(const Duration(milliseconds: 500), () {});
    _activity();
  }

  Future<void> _showWarning() async {
    if (!mounted || _warningOpen) return;
    _warningOpen = true;
    final seconds = (widget.logoutAfter - widget.warnAfter).inSeconds;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => _WarningDialog(seconds: seconds),
    );
    _warningOpen = false;
    // Si el diálogo se cerró porque venció el tiempo, la sesión ya se cerró: no hay nada que reiniciar.
    if (!mounted || result != 'stay') return;
    // «Seguir conectado»: se reinicia el temporizador y se avisa al servidor.
    _restart();
    _blockPing();
    context.read<SessionProvider>().refreshProfile();
  }

  void _expire() {
    if (!mounted) return;
    if (_warningOpen) {
      _warningOpen = false;
      Navigator.of(context, rootNavigator: true).pop('expired');
    }
    context.read<SessionProvider>().logoutInactive();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _activity(),
      onPointerSignal: (_) => _activity(),
      onPointerMove: (_) => _onMove(),
      onPointerHover: (_) => _onMove(),
      child: widget.child,
    );
  }
}

/// Aviso previo con cuenta regresiva. Se cierra con «Seguir conectado».
class _WarningDialog extends StatefulWidget {
  const _WarningDialog({required this.seconds});

  final int seconds;

  @override
  State<_WarningDialog> createState() => _WarningDialogState();
}

class _WarningDialogState extends State<_WarningDialog> {
  late int _left = widget.seconds;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left > 0 && mounted) setState(() => _left -= 1);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _clock => '${(_left ~/ 60).toString().padLeft(2, '0')}:${(_left % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tu sesión está por cerrarse'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Por seguridad, la sesión se cierra cuando no hay actividad.'),
          const SizedBox(height: 12),
          Text('Se cerrará en $_clock', key: const ValueKey('inactividad-cuenta')),
        ],
      ),
      actions: [
        FilledButton(
          key: const ValueKey('seguir-conectado'),
          onPressed: () => Navigator.of(context).pop('stay'),
          child: const Text('Seguir conectado'),
        ),
      ],
    );
  }
}
