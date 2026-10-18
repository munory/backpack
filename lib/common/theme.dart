import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/database.dart';

/// One full set of named colors — see [AppColors] for what each one means.
/// Kept as a private data class so light/dark are two plain instances
/// instead of a pile of ternaries scattered through [AppColors]'s getters.
class _Palette {
  const _Palette({
    required this.background,
    required this.card,
    required this.surfaceElevated,
    required this.menuSurface,
    required this.menuSurfaceOnElevated,
    required this.textPrimary,
    required this.accent,
    required this.food,
    required this.gear,
    required this.gearLight,
    required this.water,
    required this.overWeight,
    required this.trackBackground,
    required this.warning,
    required this.good,
  });

  final Color background;
  final Color card;
  final Color surfaceElevated;
  final Color menuSurface;
  final Color menuSurfaceOnElevated;
  final Color textPrimary;
  final Color accent;
  final Color food;
  final Color gear;
  final Color gearLight;
  final Color water;
  final Color overWeight;
  final Color trackBackground;
  final Color warning;
  final Color good;
}

/// Exact palette from the Figma mockups.
const _light = _Palette(
  background: Color(0xFFE9E0C9),
  card: Color(0xFFE9E0C9),
  surfaceElevated: Color(0xFFF4F1E8),
  menuSurface: Color(0xFFECE5D1),
  menuSurfaceOnElevated: Color(0xFFF3F1EB),
  textPrimary: Color(0xFF423A2A),
  accent: Color(0xFFC86848),
  food: Color(0xFFC96E4F),
  gear: Color(0xFF61795C),
  gearLight: Color(0xFF8BA078),
  water: Color(0xFF88A29E),
  overWeight: Color(0xFFC62828),
  trackBackground: Color(0xFFDCD3C0),
  warning: Color(0xFFC98A2E),
  good: Color(0xFF5A9B4B),
);

/// The light theme's vintage-paper mood, at dusk — warm cocoa / coffee
/// with milk, not near-black and not cold. Text is the light theme's own
/// cream, so the two read as one product. Depth comes from lightness steps
/// (background → card → elevated) rather than shadows, which vanish on a
/// dark page. Status/accent tones are lifted a step so they still read as
/// small dots and text.
const _dark = _Palette(
  background: Color(0xFF2B241F),
  card: Color(0xFF3E312C),
  surfaceElevated: Color(0xFF41382F),
  menuSurface: Color(0xFF3D342D),
  menuSurfaceOnElevated: Color(0xFF4A4037),
  textPrimary: Color(0xFFEFE5CF),
  accent: Color(0xFFE38A63),
  food: Color(0xFFE6946F),
  gear: Color(0xFFA6B88F),
  gearLight: Color(0xFF8A9C74),
  water: Color(0xFFA3C0B8),
  overWeight: Color(0xFFEC7466),
  trackBackground: Color(0xFF4A4037),
  warning: Color(0xFFE8B566),
  good: Color(0xFF9CC77E),
);

/// The user's own choice from Профиль — [AppThemeMode.system] (the
/// default) defers to the phone. A [ValueNotifier] so [BackpackApp] can
/// listen and force a rebuild when it changes, the same way it already
/// does for a system brightness change; loaded from [AppSettings] at
/// startup in `main()`, before `runApp`.
final appThemeMode = ValueNotifier<AppThemeMode>(AppThemeMode.system);

bool get _isDark => switch (appThemeMode.value) {
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
      AppThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
    };

/// Named colors for the whole app — reads live off [appThemeMode] (which
/// itself defers to the system setting unless overridden) via [_isDark], so
/// callers just read `AppColors.foo` as always; nothing at any of these call
/// sites needs to know or care which mode is active. Backed by [_Palette]
/// instances, not separate literal colors per field, so light and dark
/// can never drift out
/// of having the same set of names.
class AppColors {
  static _Palette get _current => _isDark ? _dark : _light;

  static bool get isDark => _isDark;

  static Color get background => _current.background;

  /// Same as [background] in light mode (cards separate via shadow there);
  /// a step lighter in dark mode, where a shadow can't show.
  static Color get card => _current.card;

  /// Lighter than [background]/[card] on purpose — dialogs and bottom
  /// sheets use this so they visibly pop against the dimmed page behind
  /// them instead of blending into it.
  static Color get surfaceElevated => _current.surfaceElevated;

  /// For small inline popup menus (selects, unit picker) — these open right
  /// next to plain page content with no dimmed backdrop behind them, so
  /// [surfaceElevated] (tuned for dialogs over a scrim) reads as a stark
  /// patch. This is a tone closer to [card] instead.
  static Color get menuSurface => _current.menuSurface;

  /// Same idea as [menuSurface], but for a menu opening on top of an
  /// already-elevated surface (e.g. the Parent Category picker inside the
  /// Create Category sheet) — there [menuSurface] blends into the sheet
  /// behind it instead of reading as another layer on top, so a distinct
  /// tone is used instead.
  static Color get menuSurfaceOnElevated => _current.menuSurfaceOnElevated;

  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textPrimary;
  static Color get accent => _current.accent;

  static Color get food => _current.food;
  static Color get gear => _current.gear;
  static Color get gearLight => _current.gearLight;
  static Color get water => _current.water;

  static Color get overWeight => _current.overWeight;
  static Color get trackBackground => _current.trackBackground;

  /// For "Требует ремонта" — a step below [overWeight]'s red (that means
  /// "needs replacing", this means "still fine, just fix it").
  static Color get warning => _current.warning;

  /// For "Готово к походу" — deliberately its own, more vivid green rather
  /// than reusing [gear]'s muted tone: that one's tuned to sit quietly as
  /// an icon/category color, but a status dot needs to actually read as
  /// "good" at a glance.
  static Color get good => _current.good;

  // A getter, not a field assigned once — a field would freeze at whichever
  // brightness was active the first time this class was touched, instead of
  // following the system setting like every other color here.
  //
  // In dark mode a drop shadow is invisible, so this becomes a hairline
  // light ring instead (zero blur + 1px spread acts as a border) — every
  // card picks it up through this one getter, no call site changes.
  static List<BoxShadow> get cardShadow => _isDark
      ? [
          BoxShadow(
            color: _dark.textPrimary.withValues(alpha: 0.07),
            spreadRadius: 1,
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];
}

Color colorForPackType(PackType type) => switch (type) {
      PackType.food => AppColors.food,
      PackType.gear => AppColors.gear,
      PackType.water => AppColors.water,
    };

/// Lighter tint of a pack type's color, used for icon badge backgrounds.
/// Stronger in dark mode — a faint tint over a dark card reads as a muddy
/// blob rather than a color.
Color lightColorForPackType(PackType type) => switch (type) {
      PackType.food => AppColors.food.withValues(alpha: AppColors.isDark ? 0.24 : 0.18),
      PackType.gear => AppColors.gearLight.withValues(alpha: AppColors.isDark ? 0.4 : 0.35),
      PackType.water => AppColors.water.withValues(alpha: AppColors.isDark ? 0.3 : 0.25),
    };

IconData iconForPackType(PackType type) => switch (type) {
      PackType.food => Icons.restaurant,
      PackType.gear => Icons.terrain,
      PackType.water => Icons.water_drop,
    };

/// A status dot color for a condition — green/amber/red, all the way
/// through, so the three states read at a glance.
Color colorForCondition(ItemCondition condition) => switch (condition) {
      ItemCondition.newItem => AppColors.good,
      ItemCondition.wornOut => AppColors.warning,
      ItemCondition.needsReplacement => AppColors.overWeight,
    };

/// The accent display style for the hero pack-weight number.
TextStyle weightDisplayStyle({required bool isOverweight}) {
  return GoogleFonts.lora(
    fontSize: 34,
    fontWeight: FontWeight.w500,
    color: isOverweight ? AppColors.overWeight : AppColors.textPrimary,
  );
}

ThemeData buildAppTheme() {
  final brightness = _isDark ? Brightness.dark : Brightness.light;
  final interRegular = GoogleFonts.interTextTheme();
  final textTheme = interRegular.copyWith(
    titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 22),
    titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16),
    titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
    labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
      surface: AppColors.background,
    ),
    // Default Material press/selected-row highlight is grey — replace with
    // the same warm tone used for progress-bar tracks so it reads as part
    // of the palette instead of a generic grey wash.
    highlightColor: AppColors.trackBackground,
    textTheme: textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      titleTextStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        fontSize: 18,
        color: AppColors.textPrimary,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // Visible darkening on press/hover instead of the default faint
        // Material ripple, which barely showed up against the accent color.
        overlayColor: Colors.black.withValues(alpha: 0.15),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.menuSurface,
      // Material 3 otherwise washes the color out with a tinted overlay
      // based on elevation — killing it keeps the actual tone.
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: AppColors.textPrimary.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.2)),
      ),
      textStyle: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.background,
      // No pill/background behind the selected item — just the icon and
      // label switching to the accent color.
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: selected ? AppColors.accent : AppColors.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? AppColors.accent : AppColors.textSecondary);
      }),
    ),
  );
}
