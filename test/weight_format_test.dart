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

  test('a weight and its target share one unit, picked by the bigger', () {
    expect(formatWeightPairIn(0, 20000, unit: WeightUnit.metric, l: ru), ('0 кг', '20 кг'));
    // Light things aren't rounded away to "0,0".
    expect(formatWeightPairIn(40, 23000, unit: WeightUnit.metric, l: ru), ('0,04 кг', '23 кг'));
    expect(formatWeightPairIn(3, 23000, unit: WeightUnit.metric, l: ru), ('0,01 кг', '23 кг'));
    expect(formatWeightPairIn(1540, 20000, unit: WeightUnit.metric, l: ru), ('1,54 кг', '20 кг'));
    // Over the target: the weight decides.
    expect(formatWeightPairIn(1500, 800, unit: WeightUnit.metric, l: ru), ('1,5 кг', '0,8 кг'));
    // Both light: both in grams.
    expect(formatWeightPairIn(340, 900, unit: WeightUnit.metric, l: ru), ('340 г', '900 г'));
    expect(formatWeightPairIn(200, 9000, unit: WeightUnit.imperial, l: en), ('0.44 lb', '19.84 lb'));
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
