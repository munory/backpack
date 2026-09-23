import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/database.dart';

/// Exact palette from the Figma mockups.
class AppColors {
  static const background = Color(0xFFE9E0C9);
  static const card = Color(0xFFE9E0C9);

  /// Lighter than [background]/[card] on purpose — dialogs and bottom
  /// sheets use this so they visibly pop against the dimmed page behind
  /// them instead of blending into it.
  static const surfaceElevated = Color(0xFFF4F1E8);

  /// For small inline popup menus (selects, unit picker) — these open right
  /// next to plain page content with no dimmed backdrop behind them, so
  /// [surfaceElevated] (tuned for dialogs over a scrim) reads as a stark
  /// white patch. This is a warmer, closer-to-card cream instead.
  static const menuSurface = Color(0xFFECE5D1);

  /// Same idea as [menuSurface], but for a menu opening on top of an
  /// already-elevated surface (e.g. the Parent Category picker inside the
  /// Create Category sheet) — there [menuSurface]'s warm beige blends into
  /// the sheet behind it instead of reading as another layer on top, so a
  /// lighter, cooler tone is used instead.
  static const menuSurfaceOnElevated = Color(0xFFF3F1EB);
  static const textPrimary = Color(0xFF423A2A);
  static const textSecondary = Color(0xFF423A2A);
  static const accent = Color(0xFFC86848);

  static const food = Color(0xFFC96E4F);
  static const gear = Color(0xFF61795C);
  static const gearLight = Color(0xFF8BA078);
  static const water = Color(0xFF88A29E);

  static const overWeight = Color(0xFFC62828);
  static const trackBackground = Color(0xFFDCD3C0);

  /// For "Требует ремонта" — a step below [overWeight]'s red (that means
  /// "needs replacing", this means "still fine, just fix it").
  static const warning = Color(0xFFC98A2E);

  /// For "Готово к походу" — deliberately its own, more vivid green rather
  /// than reusing [gear]'s muted tone: that one's tuned to sit quietly as
  /// an icon/category color, but a status dot needs to actually read as
  /// "good" at a glance.
  static const good = Color(0xFF5A9B4B);

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.08),
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
Color lightColorForPackType(PackType type) => switch (type) {
      PackType.food => AppColors.food.withValues(alpha: 0.18),
      PackType.gear => AppColors.gearLight.withValues(alpha: 0.35),
      PackType.water => AppColors.water.withValues(alpha: 0.25),
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
  final interRegular = GoogleFonts.interTextTheme();
  final textTheme = interRegular.copyWith(
    titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 22),
    titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16),
    titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
    labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
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
      // based on elevation — killing it keeps the actual cream tone.
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
