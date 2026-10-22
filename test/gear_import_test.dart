import 'dart:convert';

import 'package:backpack/common/weight_format.dart';
import 'package:backpack/data/database.dart';
import 'package:backpack/features/data_transfer/gear_csv.dart';
import 'package:backpack/features/data_transfer/gear_import.dart';
import 'package:backpack/features/data_transfer/gear_xlsx.dart';
import 'package:backpack/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));

  ImportResult importText(String csv, {MassUnit defaultUnit = MassUnit.g}) {
    final table = parseCsv(csv);
    return parseRows(table, guessMapping(table.headers, defaultUnit: defaultUnit));
  }

  group('parseCsv', () {
    test('quotes, doubled quotes, line breaks inside quotes, BOM and CRLF', () {
      final table = parseCsv('﻿Name,Note\r\n"Tent, 2p","say ""hi""\nthere"\r\nStove,x\r\n');
      expect(table.headers, ['Name', 'Note']);
      expect(table.rows, [
        ['Tent, 2p', 'say "hi"\nthere'],
        ['Stove', 'x'],
      ]);
    });

    test('picks up the semicolon Excel with Russian settings saves with', () {
      final table = parseCsv('Название;Вес, кг\nПалатка;1,5\n');
      expect(table.headers, ['Название', 'Вес, кг']);
      expect(table.rows.single, ['Палатка', '1,5']);
    });

    test('blank lines are ignored', () {
      expect(parseCsv('a,b\n\n1,2\n,\n').rows, [
        ['1', '2'],
      ]);
    });
  });

  test('a LighterPack export is recognized and read without asking', () {
    const csv = 'Item Name,Category,desc,qty,weight,unit,url,price,worn,consumable\n'
        'Tent,Shelter,,1,24,oz,,,,\n'
        'Snacks,Food,,3,100,g,,,,Consumable\n'
        'Water bottle,Hydration,,1,1,kg,,,,Consumable\n';
    final table = parseCsv(csv);
    final mapping = guessMapping(table.headers, defaultUnit: MassUnit.g);
    expect(isConfidentGuess(table.headers, mapping), isTrue);

    final items = parseRows(table, mapping).items;
    expect(items[0].name, 'Tent');
    expect(items[0].weightGrams, 680);
    expect(items[0].packType, isNull);
    expect(items[1].quantity, 3);
    expect(items[1].packType, PackType.food);
    expect(items[2].weightGrams, 1000);
    expect(items[2].packType, PackType.water);
  });

  test('a hand-made Russian sheet: unit from the header, weight with a comma', () {
    final result = importText('Наименование;Вес, кг;Кол-во;Категория\nПалатка;1,5;1;Укрытие\n');
    expect(result.items.single.name, 'Палатка');
    expect(result.items.single.weightGrams, 1500);
    expect(result.items.single.categoryName, 'Укрытие');
  });

  test('a unit written in the weight cell wins over the default', () {
    final result = importText('Item,Weight\nTent,1.2 kg\nStakes,60\n');
    expect(result.items.map((i) => i.weightGrams), [1200, 60]);
  });

  test('without any unit in the file the guess is not trusted', () {
    final table = parseCsv('Item,Weight\nTent,1200\n');
    final mapping = guessMapping(table.headers, defaultUnit: MassUnit.g);
    expect(mapping.isComplete, isTrue);
    expect(isConfidentGuess(table.headers, mapping), isFalse);
  });

  test('rows without a name or a usable weight are skipped and counted', () {
    final result = importText('Item,Weight,Unit\nTent,1200,g\n,300,g\nStove,?,g\n');
    expect(result.items.single.name, 'Tent');
    expect(result.skipped, 2);
  });

  group('our own exports come back unchanged', () {
    const sleep = Category(id: 1, name: 'Спальная система', packType: PackType.gear);
    const pads = Category(id: 2, name: 'Коврики', packType: PackType.gear, parentId: 1);
    const food = Category(id: 3, name: 'Еда', packType: PackType.food);
    const original = [
      Item(worn: false, id: 1, name: 'Коврик, NeoAir', weightGrams: 340, categoryId: 2,
          condition: ItemCondition.wornOut, quantity: 1),
      Item(worn: false, id: 2, name: 'Батончик', weightGrams: 50, categoryId: 3,
          condition: ItemCondition.newItem, quantity: 4),
      Item(worn: false, id: 3, name: 'Фляга', weightGrams: 120, condition: ItemCondition.needsReplacement,
          quantity: 2, packType: PackType.water),
    ];

    void expectSame(List<ImportedItem> items) {
      expect(items.map((i) => i.name), ['Коврик, NeoAir', 'Батончик', 'Фляга']);
      expect(items.map((i) => i.weightGrams), [340, 50, 120]);
      expect(items.map((i) => i.quantity), [1, 4, 2]);
      expect(items.map((i) => i.categoryName), ['Коврики', 'Еда', null]);
      expect(items.map((i) => i.parentCategoryName), ['Спальная система', null, null]);
      expect(items.map((i) => i.condition),
          [ItemCondition.wornOut, ItemCondition.newItem, ItemCondition.needsReplacement]);
      expect(items[2].packType, PackType.water);
    }

    test('CSV', () {
      final csv = buildGearCsv(
        items: original,
        categories: const [sleep, pads, food],
        unit: WeightUnit.metric,
        l: ru,
      );
      final table = readImportTable(utf8.encode('﻿$csv'), 'backpack-gear.csv');
      final mapping = guessMapping(table.headers, defaultUnit: MassUnit.oz);
      expect(isConfidentGuess(table.headers, mapping), isTrue);
      expectSame(parseRows(table, mapping).items);
    });

    test('Excel', () {
      final bytes = buildGearXlsx(
        items: original,
        categories: const [sleep, pads, food],
        unit: WeightUnit.metric,
        l: ru,
      );
      final table = readImportTable(bytes, 'backpack-gear.xlsx');
      final mapping = guessMapping(table.headers, defaultUnit: MassUnit.oz);
      expect(isConfidentGuess(table.headers, mapping), isTrue);
      // The workbook is sorted by category — put it back in our order.
      final items = parseRows(table, mapping).items
        ..sort((a, b) => ['Коврик, NeoAir', 'Батончик', 'Фляга']
            .indexOf(a.name)
            .compareTo(['Коврик, NeoAir', 'Батончик', 'Фляга'].indexOf(b.name)));
      expectSame(items);
    });
  });

  test('worn items survive the round trip, and LighterPack\'s "Worn" is understood', () {
    const boots = Item(worn: true, id: 1, name: 'Boots', weightGrams: 900,
        condition: ItemCondition.newItem, quantity: 1, packType: PackType.gear);
    final csv = buildGearCsv(items: const [boots], categories: const [],
        unit: WeightUnit.metric, l: ru);
    final fromCsv = readImportTable(utf8.encode(csv), 'a.csv');
    expect(parseRows(fromCsv, guessMapping(fromCsv.headers, defaultUnit: MassUnit.g))
        .items.single.worn, isTrue);

    final bytes = buildGearXlsx(items: const [boots], categories: const [],
        unit: WeightUnit.metric, l: ru);
    final fromXlsx = readImportTable(bytes, 'a.xlsx');
    expect(parseRows(fromXlsx, guessMapping(fromXlsx.headers, defaultUnit: MassUnit.g))
        .items.single.worn, isTrue);

    final lp = importText('Item Name,Category,desc,qty,weight,unit,url,price,worn,consumable\n'
        'Trail runners,Clothing,,1,600,g,,,Worn,\n'
        'Puffy,Clothing,,1,300,g,,,,\n');
    expect(lp.items.map((i) => i.worn), [true, false]);
  });

  test('a duplicate is the same name in the same category, ignoring case', () {
    const kitchen = Category(id: 1, name: 'Кухня', packType: PackType.gear);
    const existing = [
      Item(worn: false, id: 1, name: 'Горелка', weightGrams: 80, categoryId: 1,
          condition: ItemCondition.newItem, quantity: 1),
    ];
    final dupes = findDuplicates(
      const [
        ImportedItem(name: 'горелка', weightGrams: 80, categoryName: 'КУХНЯ'),
        ImportedItem(name: 'Горелка', weightGrams: 80, categoryName: 'Запас'),
        ImportedItem(name: 'Котелок', weightGrams: 120, categoryName: 'Кухня'),
      ],
      existing: existing,
      categories: const [kitchen],
    );
    expect(dupes, {0});
  });

  test('importing creates missing categories under their parents and reuses existing ones',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final added = await importItems(db, const [
      ImportedItem(name: 'Горелка', weightGrams: 80, categoryName: 'кухня'),
      ImportedItem(name: 'Пластырь', weightGrams: 10, categoryName: 'Аптечка'),
      ImportedItem(name: 'Коврик', weightGrams: 340, categoryName: 'Коврики',
          parentCategoryName: 'Спальная система'),
      ImportedItem(name: 'Батончик', weightGrams: 50, packType: PackType.food, quantity: 4),
    ]);
    expect(added, 4);

    final categories = await db.select(db.categories).get();
    Category named(String n) => categories.singleWhere((c) => c.name == n);
    // "кухня" matched the seeded "Кухня" instead of making a second one.
    expect(categories.where((c) => c.name.toLowerCase() == 'кухня'), hasLength(1));
    expect(named('Аптечка').icon, 'firstAid');
    expect(named('Коврики').parentId, named('Спальная система').id);

    final items = {for (final i in await db.select(db.items).get()) i.name: i};
    expect(items['Горелка']!.categoryId, named('Кухня').id);
    expect(items['Батончик']!.categoryId, isNull);
    expect(items['Батончик']!.packType, PackType.food);
    expect(items['Батончик']!.quantity, 4);
  });
}
