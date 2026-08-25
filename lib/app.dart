import 'package:flutter/material.dart';

import 'screens/radar_screen.dart';

class CryptoRadarApp extends StatelessWidget {
  const CryptoRadarApp({super.key, this.autoStart = true});

  final bool autoStart;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF62E6A7),
      brightness: Brightness.dark,
      surface: const Color(0xFF111827),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Crypto Radar',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: const Color(0xFF080D16),
        dividerColor: Colors.white12,
        cardTheme: const CardThemeData(
          color: Color(0xFF111827),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF111827),
          border: OutlineInputBorder(),
        ),
      ),
      home: CryptoRadarHome(autoStart: autoStart),
    );
  }
}
