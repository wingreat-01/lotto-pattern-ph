import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  final configured = supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  if (configured) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(LottoApp(supabaseConfigured: configured));
}

class LottoApp extends StatelessWidget {
  const LottoApp({super.key, required this.supabaseConfigured});
  final bool supabaseConfigured;

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
      home: !supabaseConfigured
          ? const _SupabaseSetupRequired()
          : StreamBuilder<AuthState>(
              stream: Supabase.instance.client.auth.onAuthStateChange,
              builder: (context, snapshot) {
                final session = Supabase.instance.client.auth.currentSession;
                return session == null ? const SignInScreen() : const HomeScreen();
              },
            ),
    );
  }
}


class _SupabaseSetupRequired extends StatelessWidget {
  const _SupabaseSetupRequired();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(child: Center(child: Padding(
      padding: EdgeInsets.all(28),
      child: Text(
        'Supabase is not configured yet. Run Flutter with --dart-define=SUPABASE_URL=YOUR_PROJECT_URL and --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY after completing the setup in docs/TRIAL_PROTECTION_SETUP.md.',
        textAlign: TextAlign.center,
      ),
    ))),
  );
}
