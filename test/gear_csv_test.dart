import 'package:backpack/data/database.dart';
import 'package:backpack/features/data_transfer/gear_csv.dart';
import 'package:backpack/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  const sleep = Category(uuid: '', updatedAt: 0, id: 1, name: 'Спальная система', packType: PackType.gear);
  const pads = Category(uuid: '', updatedAt: 0, id: 2, name: 'Коврики', packType: PackType.gear, parentId: 1);
  const food = Category(uuid: '', updatedAt: 0, id: 3, name: 'Еда', packType: PackType.food);

  Item item(int id, String name, int grams,
          {int? categoryId, int quantity = 1, ItemCondition c = ItemCondition.newItem}) =>
      Item(uuid: '', updatedAt: 0, worn: false,
        id: id,
        name: name,
        weightGrams: grams,
        categoryId: categoryId,
        condition: c,
        quantity: quantity,
      );

  List<String> lines(String csv) => csv.split('\r\n');

  test('starts with LighterPack\'s own columns, then ours', () {
    final csv = buildGearCsv(items: const [], categories: const [], unit: WeightUnit.metric, l: ru);
    expect(
      lines(csv).single,
      'Item Name,Category,desc,qty,weight,unit,url,price,worn,consumable,'
      'condition,section,parent category',
    );
  });

  test('metric: per-item grams, quantity, section, condition and parent', () {
    final csv = buildGearCsv(
      items: [
        item(1, 'Коврик NeoAir', 340, categoryId: 2, c: ItemCondition.wornOut),
        item(2, 'Батончик', 50, categoryId: 3, quantity: 4),
      ],
      categories: const [sleep, pads, food],
      unit: WeightUnit.metric,
      l: ru,
    );
    expect(lines(csv)[1],
        'Коврик NeoAir,Коврики,,1,340,g,,,,,Требует ремонта,Снаряжение,Спальная система');
    expect(lines(csv)[2], 'Батончик,Еда,,4,50,g,,,,Consumable,Готово к походу,Еда,');
  });

  test('imperial writes ounces; uncategorized items keep their own section', () {
    const water = Item(uuid: '', updatedAt: 0, worn: false,
      id: 1,
      name: 'Bottle',
      weightGrams: 200,
      condition: ItemCondition.newItem,
      quantity: 1,
      packType: PackType.water,
    );
    final csv = buildGearCsv(
      items: [water],
      categories: const [],
      unit: WeightUnit.imperial,
      l: en,
    );
    expect(lines(csv)[1], 'Bottle,,,1,7.05,oz,,,,Consumable,Trail-ready,Water,');
  });

  test('names with commas or quotes are quoted', () {
    final csv = buildGearCsv(
      items: [item(1, 'Tent, 2p "Duplex"', 540)],
      categories: const [],
      unit: WeightUnit.metric,
      l: en,
    );
    expect(lines(csv)[1], startsWith('"Tent, 2p ""Duplex""",,'));
  });
}
