import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() => runApp(const LottoApp());

class LottoApp extends StatelessWidget {
  const LottoApp({super.key});

  static const _seed = Color(0xFF6657E8);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
      surface: const Color(0xFFF7F7FC),
    );
    return MaterialApp(
      title: 'LottoPattern PH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF7F7FC),
        appBarTheme: const AppBarTheme(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Color(0xFFF7F7FC),
          foregroundColor: Color(0xFF19182B),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFEAE9F3)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEAE9F3))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEAE9F3))),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: _seed,
          thumbColor: _seed,
          overlayColor: _seed.withValues(alpha: 0.12),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
