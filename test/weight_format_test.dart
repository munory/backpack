import 'package:backpack/common/weight_format.dart';
import 'package:backpack/data/database.dart';
import 'package:backpack/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('kilograms, with a decimal comma in Russian', () {
    expect(formatWeightIn(1440, unit: WeightUnit.metric, l: en), '1.4 kg');
    expect(formatWeightIn(1500, unit: WeightUnit.metric, l: ru), '1,5 кг');
    expect(formatWeightIn(1000, unit: WeightUnit.metric, l: ru), '1,0 кг');
  });

  test('under a kilo in whole grams', () {
    expect(formatWeightIn(15, unit: WeightUnit.metric, l: ru), '15 г');
    expect(formatWeightIn(999, unit: WeightUnit.metric, l: en), '999 g');
    expect(formatWeightIn(0, unit: WeightUnit.metric, l: ru), '0 г');
  });

  test('pounds, with anything under a pound in ounces', () {
    expect(formatWeightIn(200, unit: WeightUnit.imperial, l: en), '7.1 oz');
    expect(formatWeightIn(453,unit: WeightUnit.imperial, l: en), '1.0 lb');
    expect(formatWeightIn(450, unit: WeightUnit.imperial, l: en), '15.9 oz');
    expect(formatWeightIn(454, unit: WeightUnit.imperial, l: en), '1.0 lb');
    expect(formatWeightIn(6000, unit: WeightUnit.imperial, l: en), '13.2 lb');
    expect(formatWeightIn(6000, unit: WeightUnit.imperial, l: ru), '13,2 фнт');
  });

  test('the language picks the unit until the user does', () {
    expect(defaultWeightUnit('ru'), WeightUnit.metric);
    expect(defaultWeightUnit('en'), WeightUnit.imperial);
  });

  test('typed numbers accept a comma and round-trip through pounds', () {
    expect(parseInputNumber('1,5'), 1.5);
    expect(parseInputNumber(' 2.25 '), 2.25);
    expect(parseInputNumber(''), isNull);
    final grams = (parseInputNumber('20')! * gramsPerBigUnit(WeightUnit.imperial)).round();
    expect(formatInputNumber(grams / gramsPerBigUnit(WeightUnit.imperial)), '20');
  });
}
