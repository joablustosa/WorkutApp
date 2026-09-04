import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta do Workut, tirada do logo da marca (halter vermelho +
/// "WORKUT · SOCIAL GYMNETWORK" em ink escuro).
///
/// Espelha `src/styles/_workut-tokens.scss` no workutFront: mudou aqui,
/// mude lá também. Detalhes em DESIGN.md.
class WorkutColors {
  /// Vermelho do halter: ações, curtidas, seleção.
  static const Color brand = Color(0xFFED1C24);
  static const Color brandDark = Color(0xFFB3121A);
  static const Color brandSoft = Color(0xFFFFE9EA);

  /// Ink do logo: títulos, texto e superfícies escuras.
  static const Color ink = Color(0xFF1B2430);
  static const Color inkSoft = Color(0xFF2A3746);

  static const Color muted = Color(0xFF6B7280);
  static const Color line = Color(0xFFE6E8EE);
  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Colors.white;

  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFE3F6E9);

  /// Recorde pessoal, ranking e conquistas.
  static const Color gold = Color(0xFFF5A524);
  static const Color goldSoft = Color(0xFFFFF3DC);

  static const Color danger = Color(0xFFB3121A);
}

class WorkutTheme {
  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: WorkutColors.brand,
        primary: WorkutColors.brand,
        secondary: WorkutColors.ink,
        surface: WorkutColors.surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: WorkutColors.background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: WorkutColors.ink,
        displayColor: WorkutColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: WorkutColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: WorkutColors.ink,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: WorkutColors.ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: WorkutColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: WorkutColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: WorkutColors.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WorkutColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: WorkutColors.muted),
        labelStyle: const TextStyle(color: WorkutColors.muted),
        border: _inputBorder(WorkutColors.line),
        enabledBorder: _inputBorder(WorkutColors.line),
        focusedBorder: _inputBorder(WorkutColors.brand, width: 1.6),
        errorBorder: _inputBorder(WorkutColors.danger),
        focusedErrorBorder: _inputBorder(WorkutColors.danger, width: 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: WorkutColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WorkutColors.brand,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: WorkutColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WorkutColors.brand,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: WorkutColors.brandSoft,
        side: BorderSide.none,
        labelStyle: const TextStyle(
          color: WorkutColors.brandDark,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: WorkutColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: WorkutColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
