import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/monetization_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read the saved theme first so the app never flashes the wrong colors.
  await ThemeController.instance.load();
  runApp(const LottoApp());
  // Initialize ads and Play Billing after the first frame so app startup stays responsive.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    MonetizationService.instance.initialize();
  });
}

class LottoApp extends StatelessWidget {
  const LottoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'LottoPattern PH',
        debugShowCheckedModeBanner: false,
        theme: buildLottoTheme(Brightness.light),
        darkTheme: buildLottoTheme(Brightness.dark),
        themeMode: ThemeController.instance.mode,
        home: const HomeScreen(),
      ),
    );
  }
}
