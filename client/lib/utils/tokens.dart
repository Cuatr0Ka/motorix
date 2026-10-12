import 'package:flutter/material.dart';

/// Tokens del sistema de diseño de Motorix (`docs/design-system.md`).
/// Las pantallas NO escriben valores sueltos: todo sale de aquí o del tema.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF9B4F55);
  static const Color sidebar = Color(0xFF2B2325);
  static const Color sidebarActive = Color(0xFF43353A);
  static const Color background = Color(0xFFF5F2F1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFDDD5D4);
  static const Color textPrimary = Color(0xFF231F20);
  static const Color textSecondary = Color(0xFF574D4E);
  static const Color warning = Color(0xFFC9892B);
  static const Color success = Color(0xFF3F6B4A);
  static const Color danger = Color(0xFFC0392B);
  static const Color info = Color(0xFF3A6B94);

  /// Texto e íconos claros sobre el sidebar oscuro.
  static const Color onSidebar = Color(0xFFF5F2F1);
  static const Color onSidebarMuted = Color(0xFFBDB2B3);
}

/// Escala de espaciado base 4 px.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Radios de borde.
class AppRadius {
  AppRadius._();

  static const double control = 6; // botones e inputs
  static const double panel = 8; // paneles, tarjetas, chips, diálogos
  static const double pill = 12;
}

/// Escala tipográfica fija de 4 tamaños.
class AppFontSize {
  AppFontSize._();

  static const double caption = 13;
  static const double body = 15;
  static const double section = 18;
  static const double title = 28;
}

/// Duraciones de las transiciones (siempre suaves, sin rebotes).
class AppDurations {
  AppDurations._();

  static const Duration state = Duration(milliseconds: 150);
  static const Duration appear = Duration(milliseconds: 200);
  static const Duration navigation = Duration(milliseconds: 250);
  static const Duration sidebar = Duration(milliseconds: 200);
}

class AppCurves {
  AppCurves._();

  static const Curve standard = Curves.easeInOut;
  static const Curve enter = Curves.easeOutCubic;
}

/// Medidas del sidebar.
class AppLayout {
  AppLayout._();

  static const double sidebarExpanded = 260;
  static const double sidebarCollapsed = 72;
  static const double collapseBreakpoint = 1000;
}
