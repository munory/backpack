import 'package:flutter/widgets.dart';

import '../data/database.dart';
import 'l10n.dart';

const gramsPerOunce = 28.349523125;
const gramsPerPound = 453.59237;

/// Units a weight can be typed or imported in, with how many grams one of
/// each is.
enum MassUnit {
  g(1),
  kg(1000),
  oz(gramsPerOunce),
  lb(gramsPerPound);

  const MassUnit(this.grams);
  final double grams;

  String label(AppLocalizations l) => switch (this) {
        MassUnit.g => l.unitG,
        MassUnit.kg => l.unitKg,
        MassUnit.oz => l.unitOz,
        MassUnit.lb => l.unitLb,
      };
}

/// The user's explicit choice from Профиль, or null to let the language
/// decide (see [defaultWeightUnit]). A [ValueNotifier] like `appThemeMode`,
/// so [BackpackApp] rebuilds everything on change.
final appWeightUnit = ValueNotifier<WeightUnit?>(null);

/// Kilograms for Russian, pounds for English — what each audience expects
/// before they've picked anything.
WeightUnit defaultWeightUnit(String languageCode) =>
    languageCode == 'ru' ? WeightUnit.metric : WeightUnit.imperial;

WeightUnit weightUnitOf(BuildContext context) =>
    appWeightUnit.value ?? defaultWeightUnit(context.l10n.localeName);

/// A weight for display in the current unit and language. Light things in
/// the small unit, heavier ones in the big one, the way gear lists are
/// written: "340 г" but "1,4 кг"; "7.1 oz" but "13.2 lb".
String formatWeight(BuildContext context, int grams) =>
    formatWeightIn(grams, unit: weightUnitOf(context), l: context.l10n);

String formatWeightIn(int grams, {required WeightUnit unit, required AppLocalizations l}) {
  String n(double v) => formatDecimal(v, l.localeName);
  if (unit == WeightUnit.metric) {
    // Under a kilo in whole grams — "0,0 кг" for a 15 g lighter told
    // nothing.
    if (grams < 1000) return '$grams ${l.unitG}';
    return '${n(grams / 1000)} ${l.unitKg}';
  }
  final ounces = grams / gramsPerOunce;
  // Compared after rounding, so 15.98 oz reads "1.0 lb", not "16.0 oz".
  if ((ounces * 10).round() < 160) return '${n(ounces)} ${l.unitOz}';
  return '${n(grams / gramsPerPound)} ${l.unitLb}';
}

/// One decimal place, with a decimal comma in Russian.
String formatDecimal(double value, String languageCode) {
  final s = value.toStringAsFixed(1);
  return languageCode == 'ru' ? s.replaceFirst('.', ',') : s;
}

/// The "big" unit target weights are typed in — kilograms or pounds.
double gramsPerBigUnit(WeightUnit unit) => unit == WeightUnit.metric ? 1000 : gramsPerPound;

String bigUnitLabel(AppLocalizations l, WeightUnit unit) =>
    unit == WeightUnit.metric ? l.unitKg : l.unitLb;

/// A number as someone would type it into a field: whole if it rounds
/// cleanly, otherwise up to 2 decimals without a trailing zero — with a
/// decimal comma in Russian, matching how weights are shown.
String formatInputNumber(double value, {String languageCode = 'en'}) {
  final s = value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return languageCode == 'ru' ? s.replaceFirst('.', ',') : s;
}

/// Parses a typed number, accepting a decimal comma as well as a point.
double? parseInputNumber(String text) => double.tryParse(text.trim().replaceAll(',', '.'));
