import 'package:backpack/data/database.dart';
import 'package:backpack/data/providers.dart';
import 'package:flutter_test/flutter_test.dart';

Item _item({int weightGrams = 100, int quantity = 1}) => Item(
      id: 1,
      name: 'Test',
      weightGrams: weightGrams,
      condition: ItemCondition.newItem,
      quantity: quantity,
    );

void main() {
  group('itemTotalGrams', () {
    test('single unit is just its own weight', () {
      expect(itemTotalGrams(_item(weightGrams: 250, quantity: 1)), 250);
    });

    test('multiplies per-unit weight by quantity', () {
      expect(itemTotalGrams(_item(weightGrams: 40, quantity: 3)), 120);
    });

    test('zero weight stays zero regardless of quantity', () {
      expect(itemTotalGrams(_item(weightGrams: 0, quantity: 5)), 0);
    });
  });
}
