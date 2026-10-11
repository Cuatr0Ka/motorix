import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Transición discreta entre pantallas: desvanecimiento con un deslizamiento leve.
class _SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SoftPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: AppCurves.enter);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

/// Construye el `ThemeData` propio de Motorix (Material 3, tema claro).
/// Con [useGoogleFonts] en falso se usa la fuente del sistema (útil en pruebas sin red).
ThemeData buildAppTheme({bool useGoogleFonts = true}) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    surfaceContainerLowest: AppColors.background,
    outlineVariant: AppColors.outline,
    onSurface: AppColors.textPrimary,
    error: AppColors.danger,
  );

  TextStyle style(double size, FontWeight weight, {Color color = AppColors.textPrimary}) {
    final base = TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.4);
    return useGoogleFonts ? GoogleFonts.ibmPlexSans(textStyle: base) : base;
  }

  final textTheme = TextTheme(
    // Indicador grande / título de página
    headlineMedium: style(AppFontSize.title, FontWeight.w600),
    // Título de sección
    titleMedium: style(AppFontSize.section, FontWeight.w600),
    // Cuerpo
    bodyMedium: style(AppFontSize.body, FontWeight.w400),
    bodyLarge: style(AppFontSize.body, FontWeight.w500),
    labelLarge: style(AppFontSize.body, FontWeight.w500),
    // Caption / etiquetas
    bodySmall: style(AppFontSize.caption, FontWeight.w400, color: AppColors.textSecondary),
    labelMedium: style(AppFontSize.caption, FontWeight.w400, color: AppColors.textSecondary),
  );

  final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control));
  final panelShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.panel),
    side: const BorderSide(color: AppColors.outline),
  );

  OutlineInputBorder border(Color color, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    textTheme: textTheme,
    dividerTheme: const DividerThemeData(color: AppColors.outline, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      border: border(AppColors.outline),
      enabledBorder: border(AppColors.outline),
      focusedBorder: border(AppColors.primary, width: 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, width: 1.5),
      labelStyle: style(AppFontSize.body, FontWeight.w400, color: AppColors.textSecondary),
      helperStyle: style(AppFontSize.caption, FontWeight.w400, color: AppColors.textSecondary),
      errorStyle: style(AppFontSize.caption, FontWeight.w400, color: AppColors.danger),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: controlShape,
        textStyle: style(AppFontSize.body, FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        animationDuration: AppDurations.state,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.outline),
        shape: controlShape,
        textStyle: style(AppFontSize.body, FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        animationDuration: AppDurations.state,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: controlShape,
        textStyle: style(AppFontSize.body, FontWeight.w500),
        animationDuration: AppDurations.state,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: panelShape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: panelShape,
      titleTextStyle: style(AppFontSize.section, FontWeight.w600),
      contentTextStyle: style(AppFontSize.body, FontWeight.w400),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.sidebar,
      contentTextStyle: style(AppFontSize.body, FontWeight.w400, color: AppColors.onSidebar),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.panel)),
      width: 420,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.background,
      side: const BorderSide(color: AppColors.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      labelStyle: style(AppFontSize.caption, FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: const WidgetStatePropertyAll(AppColors.background),
      headingTextStyle: style(AppFontSize.caption, FontWeight.w600, color: AppColors.textSecondary),
      dataTextStyle: style(AppFontSize.body, FontWeight.w400),
      dividerThickness: 1,
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) return AppColors.background;
        return AppColors.surface;
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.sidebar,
      indicatorColor: AppColors.sidebarActive,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      selectedIconTheme: const IconThemeData(color: AppColors.onSidebar),
      unselectedIconTheme: const IconThemeData(color: AppColors.onSidebarMuted),
      selectedLabelTextStyle: style(AppFontSize.body, FontWeight.w500, color: AppColors.onSidebar),
      unselectedLabelTextStyle:
          style(AppFontSize.body, FontWeight.w400, color: AppColors.onSidebarMuted),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      textStyle: style(AppFontSize.caption, FontWeight.w400, color: AppColors.onSidebar),
      waitDuration: const Duration(milliseconds: 400),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.windows: _SoftPageTransitionsBuilder(),
        TargetPlatform.linux: _SoftPageTransitionsBuilder(),
        TargetPlatform.macOS: _SoftPageTransitionsBuilder(),
        TargetPlatform.android: _SoftPageTransitionsBuilder(),
        TargetPlatform.iOS: _SoftPageTransitionsBuilder(),
      },
    ),
  );
}
