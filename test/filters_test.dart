import 'package:backpack/data/database.dart';
import 'package:backpack/features/gear_list/gear_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Item _item({
  required String name,
  int? categoryId,
  ItemCondition condition = ItemCondition.newItem,
  PackType? packType,
}) =>
    Item(uuid: '', updatedAt: 0, worn: false,
      id: 1,
      name: name,
      weightGrams: 100,
      categoryId: categoryId,
      condition: condition,
      packType: packType,
      quantity: 1,
    );

Category _category({required int id, required PackType packType}) => Category(
      uuid: '',
      updatedAt: 0,
      id: id,
      name: 'Cat $id',
      packType: packType,
    );

void main() {
  group('matchesFilters', () {
    final gearCategory = _category(id: 1, packType: PackType.gear);
    final categoryById = {1: gearCategory};

    test('empty query and no filters matches everything', () {
      final item = _item(name: 'Палатка');
      expect(
        matchesFilters(item, categoryById, query: '', condition: null, packType: null),
        isTrue,
      );
    });

    test('query matches case-insensitively on a substring', () {
      final item = _item(name: 'Палатка');
      expect(
        matchesFilters(item, categoryById, query: 'латк', condition: null, packType: null),
        isTrue,
      );
      expect(
        matchesFilters(item, categoryById, query: 'рюкзак', condition: null, packType: null),
        isFalse,
      );
    });

    test('condition filter only matches that exact condition', () {
      final item = _item(name: 'Куртка', condition: ItemCondition.wornOut);
      expect(
        matchesFilters(item, categoryById,
            query: '', condition: ItemCondition.wornOut, packType: null),
        isTrue,
      );
      expect(
        matchesFilters(item, categoryById,
            query: '', condition: ItemCondition.needsReplacement, packType: null),
        isFalse,
      );
    });

    test('packType filter resolves through the category when the item has one', () {
      final item = _item(name: 'Котелок', categoryId: 1);
      expect(
        matchesFilters(item, categoryById, query: '', condition: null, packType: PackType.gear),
        isTrue,
      );
      expect(
        matchesFilters(item, categoryById, query: '', condition: null, packType: PackType.food),
        isFalse,
      );
    });

    test('packType filter falls back to the item\'s own packType when uncategorized', () {
      final item = _item(name: 'Батончик', packType: PackType.food);
      expect(
        matchesFilters(item, categoryById, query: '', condition: null, packType: PackType.food),
        isTrue,
      );
    });

    test('query, condition and packType all combine with AND', () {
      final item = _item(name: 'Дождевик', condition: ItemCondition.wornOut, categoryId: 1);
      expect(
        matchesFilters(item, categoryById,
            query: 'дожд', condition: ItemCondition.wornOut, packType: PackType.gear),
        isTrue,
      );
      expect(
        matchesFilters(item, categoryById,
            query: 'дожд', condition: ItemCondition.needsReplacement, packType: PackType.gear),
        isFalse,
      );
    });
  });
}
