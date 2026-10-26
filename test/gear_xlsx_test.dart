import 'package:backpack/data/database.dart';
import 'package:backpack/features/data_transfer/gear_xlsx.dart';
import 'package:backpack/l10n/app_localizations.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));

  const kitchen = Category(uuid: '', updatedAt: 0, id: 1, name: 'Кухня', packType: PackType.gear);
  Item item(int id, String name, int grams, {int? categoryId, int quantity = 1}) => Item(uuid: '', updatedAt: 0, worn: false,
        id: id,
        name: name,
        weightGrams: grams,
        categoryId: categoryId,
        condition: ItemCondition.newItem,
        quantity: quantity,
        packType: categoryId == null ? PackType.gear : null,
      );

  /// Builds a workbook and reads it back the way Excel would.
  List<List<xl.CellValue?>> roundTrip(List<Item> items, WeightUnit unit) {
    final bytes = buildGearXlsx(
      items: items,
      categories: const [kitchen],
      unit: unit,
      l: ru,
    );
    final book = xl.Excel.decodeBytes(bytes);
    final sheet = book.tables['Инвентарь']!;
    return [for (final row in sheet.rows) [for (final c in row) c?.value]];
  }

  test('headers in the current language, weights as real numbers', () {
    final rows = roundTrip(
      [item(1, 'Котелок', 120, categoryId: 1, quantity: 2)],
      WeightUnit.metric,
    );
    expect(rows[0].map((c) => c.toString()), [
      'Название', 'Категория', 'Родительская категория', 'Раздел',
      'Состояние', 'Количество', 'Вес за шт., г', 'Вес всего, г', 'Надето',
    ]);
    expect(rows[1][0].toString(), 'Котелок');
    expect(rows[1][5], isA<xl.IntCellValue>());
    expect((rows[1][6] as xl.IntCellValue).value, 120);
    expect((rows[1][7] as xl.IntCellValue).value, 240);
  });

  test('sorted by category, uncategorized last', () {
    final rows = roundTrip(
      [item(1, 'Компас', 30), item(2, 'Ложка', 20, categoryId: 1), item(3, 'Горелка', 80, categoryId: 1)],
      WeightUnit.metric,
    );
    expect([for (final r in rows.skip(1)) r[0].toString()], ['Горелка', 'Ложка', 'Компас']);
  });

  test('imperial writes ounces to two decimals', () {
    final rows = roundTrip([item(1, 'Котелок', 200, categoryId: 1)], WeightUnit.imperial);
    expect(rows[0][6].toString(), 'Вес за шт., унц.');
    expect((rows[1][6] as xl.DoubleCellValue).value, 7.05);
  });
}
