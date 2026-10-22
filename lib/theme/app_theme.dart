import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Colors that the screens used to hard-code, now available in light and dark.
/// Read them anywhere with `context.lc.muted`, `context.lc.surface`, etc.
@immutable
class LottoColors extends ThemeExtension<LottoColors> {
  const LottoColors({
    required this.surface,
    required this.tint,
    required this.neutralFill,
    required this.ballFill,
    required this.border,
    required this.hairline,
    required this.muted,
    required this.strongText,
    required this.accent,
    required this.outlineAccent,
    required this.iconDim,
    required this.drawerIcon,
    required this.navIndicator,
  });

  final Color surface;
  final Color tint;
  final Color neutralFill;
  final Color ballFill;
  final Color border;
  final Color hairline;
  final Color muted;
  final Color strongText;
  final Color accent;
  final Color outlineAccent;
  final Color iconDim;
  final Color drawerIcon;
  final Color navIndicator;

  static const light = LottoColors(
    surface: Colors.white,
    tint: Color(0xFFF0EEFF),
    neutralFill: Color(0xFFEFEFF7),
    ballFill: Color(0xFFE6E5EE),
    border: Color(0xFFEAE9F3),
    hairline: Color(0xFFF0EFF6),
    muted: Color(0xFF858399),
    strongText: Color(0xFF343249),
    accent: Color(0xFF6254DF),
    outlineAccent: Color(0xFFD9D4FF),
    iconDim: Color(0xFFAAA8BC),
    drawerIcon: Color(0xFF0A48C7),
    navIndicator: Color(0xFFFFE88A),
  );

  static const dark = LottoColors(
    surface: Color(0xFF1B1A2B),
    tint: Color(0xFF2A2750),
    neutralFill: Color(0xFF26253A),
    ballFill: Color(0xFF33324A),
    border: Color(0xFF2E2D45),
    hairline: Color(0xFF2A2940),
    muted: Color(0xFFA09EB8),
    strongText: Color(0xFFE9E7F7),
    accent: Color(0xFFA79DFF),
    outlineAccent: Color(0xFF4A4590),
    iconDim: Color(0xFF55546E),
    drawerIcon: Color(0xFF8FB2FF),
    navIndicator: Color(0xFF37336B),
  );

  @override
  LottoColors copyWith({
    Color? surface,
    Color? tint,
    Color? neutralFill,
    Color? ballFill,
    Color? border,
    Color? hairline,
    Color? muted,
    Color? strongText,
    Color? accent,
    Color? outlineAccent,
    Color? iconDim,
    Color? drawerIcon,
    Color? navIndicator,
  }) {
    return LottoColors(
      surface: surface ?? this.surface,
      tint: tint ?? this.tint,
      neutralFill: neutralFill ?? this.neutralFill,
      ballFill: ballFill ?? this.ballFill,
      border: border ?? this.border,
      hairline: hairline ?? this.hairline,
      muted: muted ?? this.muted,
      strongText: strongText ?? this.strongText,
      accent: accent ?? this.accent,
      outlineAccent: outlineAccent ?? this.outlineAccent,
      iconDim: iconDim ?? this.iconDim,
      drawerIcon: drawerIcon ?? this.drawerIcon,
      navIndicator: navIndicator ?? this.navIndicator,
    );
  }

  @override
  LottoColors lerp(ThemeExtension<LottoColors>? other, double t) {
    if (other is! LottoColors) return this;
    return LottoColors(
      surface: Color.lerp(surface, other.surface, t)!,
      tint: Color.lerp(tint, other.tint, t)!,
      neutralFill: Color.lerp(neutralFill, other.neutralFill, t)!,
      ballFill: Color.lerp(ballFill, other.ballFill, t)!,
      border: Color.lerp(border, other.border, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      strongText: Color.lerp(strongText, other.strongText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      outlineAccent: Color.lerp(outlineAccent, other.outlineAccent, t)!,
      iconDim: Color.lerp(iconDim, other.iconDim, t)!,
      drawerIcon: Color.lerp(drawerIcon, other.drawerIcon, t)!,
      navIndicator: Color.lerp(navIndicator, other.navIndicator, t)!,
    );
  }
}

extension LottoColorsContext on BuildContext {
  /// Falls back to the light palette if the extension is ever missing, so a
  /// lookup can never crash the app.
  LottoColors get lc => Theme.of(this).extension<LottoColors>() ?? LottoColors.light;
}

const _seed = Color(0xFF6657E8);

ThemeData buildLottoTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final lc = isDark ? LottoColors.dark : LottoColors.light;
  final background = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF7F7FC);
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
    surface: background,
  );
  final appBarForeground = isDark ? const Color(0xFFF1F0FB) : const Color(0xFF19182B);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    extensions: <ThemeExtension<dynamic>>[lc],
    appBarTheme: AppBarTheme(
      surfaceTintColor: Colors.transparent,
      backgroundColor: background,
      foregroundColor: appBarForeground,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    drawerTheme: DrawerThemeData(backgroundColor: lc.surface),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lc.surface,
      indicatorColor: lc.navIndicator,
    ),
    cardTheme: CardThemeData(
      color: lc.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: lc.border),
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
      fillColor: lc.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: lc.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: lc.border)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: isDark ? lc.accent : _seed,
      thumbColor: isDark ? lc.accent : _seed,
      overlayColor: (isDark ? lc.accent : _seed).withValues(alpha: 0.12),
    ),
  );
}

/// Holds the chosen theme mode and remembers it between launches.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'theme_mode';
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      final saved = prefs.getString(_prefsKey);
      _mode = switch (saved) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Storage unavailable: keep following the system setting.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {}
  }

  /// Switches to whichever theme is not currently showing.
  Future<void> toggle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
