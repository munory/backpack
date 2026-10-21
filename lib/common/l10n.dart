import 'package:flutter/widgets.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The app's own language preference — [AppLanguage.system] follows the
/// phone (falling back to English for anything but Russian). A
/// [ValueNotifier] for the same reason as `appThemeMode`: [BackpackApp]
/// listens to it and rebuilds with the new locale straight away.
final appLanguage = ValueNotifier<AppLanguage>(AppLanguage.system);

/// Null for [AppLanguage.system] — MaterialApp then resolves the phone's
/// locale against the supported ones itself.
Locale? localeFor(AppLanguage language) => switch (language) {
      AppLanguage.system => null,
      AppLanguage.ru => const Locale('ru'),
      AppLanguage.en => const Locale('en'),
    };

/// Display order for conditions — the add/edit form and the filter sheet
/// both list them in this order.
const conditionOrder = [
  ItemCondition.newItem,
  ItemCondition.wornOut,
  ItemCondition.needsReplacement,
];

String conditionLabel(AppLocalizations l, ItemCondition c) => switch (c) {
      ItemCondition.newItem => l.conditionReady,
      ItemCondition.wornOut => l.conditionNeedsRepair,
      ItemCondition.needsReplacement => l.conditionReplace,
    };

String packTypeLabel(AppLocalizations l, PackType t) => switch (t) {
      PackType.food => l.packFood,
      PackType.gear => l.packGear,
      PackType.water => l.packWater,
    };

/// A trip's name as shown — the draft is always just "Черновик"/"Draft" in
/// the current language, whatever was stored when it was created.
String tripName(AppLocalizations l, Trip t) => t.isDraft ? l.draft : t.name;
