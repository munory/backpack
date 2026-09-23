import 'package:flutter/material.dart';

import '../data/database.dart';
import 'theme.dart';

/// One choice in the category icon picker. [key] is what's actually stored
/// on the [Category] row — the [IconData] itself can't be persisted, so a
/// stable string key is what survives a rename of this list later.
class CategoryIconOption {
  const CategoryIconOption(this.key, this.icon);
  final String key;
  final IconData icon;
}

/// Enough to cover the obvious backpacking categories without the list
/// turning into a wall of near-duplicate icons. "misc" is the catch-all for
/// everything else.
const categoryIconOptions = [
  CategoryIconOption('backpack', Icons.backpack),
  CategoryIconOption('tent', Icons.cabin),
  CategoryIconOption('sleep', Icons.bed),
  CategoryIconOption('kitchen', Icons.outdoor_grill),
  CategoryIconOption('clothing', Icons.checkroom),
  CategoryIconOption('food', Icons.restaurant),
  CategoryIconOption('water', Icons.water_drop),
  CategoryIconOption('firstAid', Icons.medical_services),
  CategoryIconOption('navigation', Icons.explore),
  CategoryIconOption('electronics', Icons.battery_charging_full),
  CategoryIconOption('hygiene', Icons.clean_hands),
  CategoryIconOption('tools', Icons.build),
  CategoryIconOption('footwear', Icons.hiking),
  CategoryIconOption('misc', Icons.category),
];

final _iconByKey = {for (final o in categoryIconOptions) o.key: o.icon};

/// One choice in the category color picker. Deliberately a short, curated
/// list in the same muted/earthy family as the rest of the palette — a free
/// color picker would let a category clash with the app's tuned look.
class CategoryColorOption {
  const CategoryColorOption(this.key, this.color);
  final String key;
  final Color color;
}

const categoryColorOptions = [
  CategoryColorOption('terracotta', Color(0xFFC86848)),
  CategoryColorOption('sage', Color(0xFF7C8F6E)),
  CategoryColorOption('teal', Color(0xFF6E97A0)),
  CategoryColorOption('mustard', Color(0xFFBF8B3D)),
  CategoryColorOption('plum', Color(0xFF8B6A8C)),
  CategoryColorOption('slate', Color(0xFF5F7A8A)),
];

final _colorByKey = {for (final o in categoryColorOptions) o.key: o.color};

/// A category's icon — its own choice if it made one, else the old
/// per-section default (also what the synthetic "uncategorized" cards use,
/// since those have no [Category] row to store a choice on).
IconData iconForCategory(Category category) =>
    _iconByKey[category.icon] ?? iconForPackType(category.packType);

/// A category's color — same fallback logic as [iconForCategory].
Color colorForCategoryValue(Category category) =>
    _colorByKey[category.color] ?? colorForPackType(category.packType);

/// Lighter tint of [colorForCategoryValue], for the icon badge background.
Color lightColorForCategoryValue(Category category) {
  final key = category.color;
  if (key == null) return lightColorForPackType(category.packType);
  return colorForCategoryValue(category).withValues(alpha: 0.22);
}
