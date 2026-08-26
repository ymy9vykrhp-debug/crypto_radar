import 'package:flutter/material.dart';

@immutable
class RadarSemanticColors extends ThemeExtension<RadarSemanticColors> {
  const RadarSemanticColors({
    required this.bullish,
    required this.bearish,
    required this.warning,
    required this.neutral,
  });

  final Color bullish;
  final Color bearish;
  final Color warning;
  final Color neutral;

  @override
  RadarSemanticColors copyWith({
    Color? bullish,
    Color? bearish,
    Color? warning,
    Color? neutral,
  }) {
    return RadarSemanticColors(
      bullish: bullish ?? this.bullish,
      bearish: bearish ?? this.bearish,
      warning: warning ?? this.warning,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  RadarSemanticColors lerp(RadarSemanticColors? other, double t) {
    if (other == null) return this;
    return RadarSemanticColors(
      bullish: Color.lerp(bullish, other.bullish, t)!,
      bearish: Color.lerp(bearish, other.bearish, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}

class AppTheme {
  static const Color seed = Color(0xFF52C99B);

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final ColorScheme colors = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: dark ? const Color(0xFF111827) : const Color(0xFFF7F9FC),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF080D16)
          : const Color(0xFFF1F4F8),
      dividerColor: colors.outlineVariant.withValues(alpha: 0.55),
      cardTheme: CardThemeData(
        color: colors.surface,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLow,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryContainer,
        labelType: NavigationRailLabelType.none,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
        dividerThickness: 0.6,
      ),
      extensions: const <ThemeExtension<dynamic>>[
        RadarSemanticColors(
          bullish: Color(0xFF39C994),
          bearish: Color(0xFFE85B75),
          warning: Color(0xFFE6A83C),
          neutral: Color(0xFF8B95A7),
        ),
      ],
    );
  }
}
