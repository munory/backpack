import 'package:backpack/common/text_format.dart';
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

  group('pluralizeRu / itemWord', () {
    test('1, 21, 31... use the singular form', () {
      expect(itemWord(1), 'вещь');
      expect(itemWord(21), 'вещь');
      expect(itemWord(31), 'вещь');
    });

    test('2-4, 22-24... use the few form', () {
      expect(itemWord(2), 'вещи');
      expect(itemWord(3), 'вещи');
      expect(itemWord(4), 'вещи');
      expect(itemWord(22), 'вещи');
    });

    test('0, 5-20, 25... use the many form', () {
      expect(itemWord(0), 'вещей');
      expect(itemWord(5), 'вещей');
      expect(itemWord(11), 'вещей');
      expect(itemWord(12), 'вещей');
      expect(itemWord(14), 'вещей');
      expect(itemWord(25), 'вещей');
    });
  });

  group('categoryWord', () {
    test('follows the same rules with its own word forms', () {
      expect(categoryWord(1), 'категория');
      expect(categoryWord(2), 'категории');
      expect(categoryWord(11), 'категорий');
      expect(categoryWord(25), 'категорий');
    });
  });
}
