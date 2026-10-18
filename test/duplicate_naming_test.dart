import 'package:backpack/data/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('first duplicate gets a plain "(копия)" suffix', () async {
    final original = await db.addItem(
      name: 'Фляга запасная',
      weightGrams: 40,
      condition: ItemCondition.wornOut,
      packType: PackType.water,
    );
    final originalRow =
        await (db.select(db.items)..where((i) => i.id.equals(original))).getSingle();

    final copy = await db.duplicateItem(originalRow);

    expect(copy.name, 'Фляга запасная (копия)');
  });

  test('duplicating a duplicate numbers it instead of stacking suffixes', () async {
    final originalId = await db.addItem(
      name: 'Фляга запасная',
      weightGrams: 40,
      condition: ItemCondition.wornOut,
      packType: PackType.water,
    );
    final original =
        await (db.select(db.items)..where((i) => i.id.equals(originalId))).getSingle();

    final firstCopy = await db.duplicateItem(original);
    final secondCopy = await db.duplicateItem(firstCopy);
    final thirdCopy = await db.duplicateItem(secondCopy);

    expect(firstCopy.name, 'Фляга запасная (копия)');
    expect(secondCopy.name, 'Фляга запасная (копия 2)');
    expect(thirdCopy.name, 'Фляга запасная (копия 3)');
  });

  test('duplicating the original again after copies exist skips used numbers', () async {
    final originalId = await db.addItem(
      name: 'Компас',
      weightGrams: 60,
      condition: ItemCondition.newItem,
      packType: PackType.gear,
    );
    final original =
        await (db.select(db.items)..where((i) => i.id.equals(originalId))).getSingle();

    await db.duplicateItem(original); // "Компас (копия)"
    final another = await db.duplicateItem(original);

    expect(another.name, 'Компас (копия 2)');
  });
}
