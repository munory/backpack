import 'package:backpack/common/text_format.dart';
import 'package:backpack/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('capitalizeFirst', () {
    test('capitalizes a lowercase first letter', () {
      expect(capitalizeFirst('кухня'), 'Кухня');
    });

    test('leaves an already-capitalized string alone', () {
      expect(capitalizeFirst('Прочее'), 'Прочее');
    });

    test('leaves the rest of the string untouched', () {
      expect(capitalizeFirst('камера GoPro'), 'Камера GoPro');
    });

    test('empty string stays empty', () {
      expect(capitalizeFirst(''), '');
    });
  });

  group('Russian item count', () {
    final ru = lookupAppLocalizations(const Locale('ru'));

    test('1, 21, 31... use the singular form', () {
      expect(ru.itemCount(1), '1 вещь');
      expect(ru.itemCount(21), '21 вещь');
      expect(ru.itemCount(31), '31 вещь');
    });

    test('2-4, 22-24... use the few form', () {
      expect(ru.itemCount(2), '2 вещи');
      expect(ru.itemCount(3), '3 вещи');
      expect(ru.itemCount(4), '4 вещи');
      expect(ru.itemCount(22), '22 вещи');
    });

    test('0, 5-20, 25... use the many form', () {
      expect(ru.itemCount(0), '0 вещей');
      expect(ru.itemCount(5), '5 вещей');
      expect(ru.itemCount(11), '11 вещей');
      expect(ru.itemCount(12), '12 вещей');
      expect(ru.itemCount(14), '14 вещей');
      expect(ru.itemCount(25), '25 вещей');
    });

    test('categories follow the same rules with their own word forms', () {
      expect(ru.categoryCount(1), '1 категория');
      expect(ru.categoryCount(2), '2 категории');
      expect(ru.categoryCount(11), '11 категорий');
      expect(ru.categoryCount(25), '25 категорий');
    });
  });

  test('English counts are just one vs. the rest', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.itemCount(1), '1 item');
    expect(en.itemCount(0), '0 items');
    expect(en.itemCount(21), '21 items');
    expect(en.categoryCount(1), '1 category');
    expect(en.categoryCount(3), '3 categories');
  });
}
