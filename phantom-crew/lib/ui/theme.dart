import 'package:flutter/material.dart';

class PhantomTheme {
  // Brand colours
  static const Color teal = Color(0xFF00E5CC);
  static const Color tealDark = Color(0xFF00B3A1);
  static const Color purple = Color(0xFF7B2FBE);
  static const Color red = Color(0xFFE53935);
  static const Color darkBg = Color(0xFF0A0E1A);
  static const Color panelBg = Color(0xFF121828);
  static const Color cardBg = Color(0xFF1A2235);
  static const Color textPrimary = Color(0xFFE8F0FE);
  static const Color textSecondary = Color(0xFF8899BB);
  static const Color divider = Color(0xFF1E2D45);

  // Player colours
  static const Map<String, Color> playerColors = {
    'cyan':   Color(0xFF00E5CC),
    'red':    Color(0xFFE53935),
    'orange': Color(0xFFFF6D00),
    'purple': Color(0xFF7B2FBE),
    'green':  Color(0xFF00C853),
    'pink':   Color(0xFFE91E8C),
    'white':  Color(0xFFECEFF1),
    'yellow': Color(0xFFFFD600),
  };

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    primaryColor: teal,
    colorScheme: const ColorScheme.dark(
      primary: teal,
      secondary: purple,
      surface: panelBg,
      error: red,
    ),
    fontFamily: 'Exo2',
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Orbitron', color: textPrimary, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(fontFamily: 'Orbitron', color: textPrimary, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(fontFamily: 'Orbitron', color: textPrimary),
      headlineLarge: TextStyle(fontFamily: 'Orbitron', color: textPrimary),
      headlineMedium: TextStyle(fontFamily: 'Orbitron', color: textPrimary),
      bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
      labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: teal,
        foregroundColor: darkBg,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.bold,
          fontSize: 15,
          letterSpacing: 1.5,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: teal,
        side: const BorderSide(color: teal, width: 1.5),
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.bold,
          fontSize: 15,
          letterSpacing: 1.5,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: teal, width: 2),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textSecondary),
    ),
  );
}

// Reusable styled widgets
class PhantomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const PhantomCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PhantomTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PhantomTheme.divider, width: 1),
      ),
      child: child,
    );
  }
}

class GlowText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  const GlowText(this.text, {super.key, this.fontSize = 32, this.color = PhantomTheme.teal});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Orbitron',
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: color,
        shadows: [
          Shadow(color: color.withAlpha(180), blurRadius: 12),
          Shadow(color: color.withAlpha(80), blurRadius: 30),
        ],
      ),
    );
  }
}
