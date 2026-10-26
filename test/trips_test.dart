import 'package:backpack/common/text_format.dart';
import 'package:backpack/data/database.dart';
import 'package:backpack/data/providers.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addGear(String name, {int quantity = 1}) => db.addItem(
        name: name,
        weightGrams: 100,
        condition: ItemCondition.newItem,
        packType: PackType.gear,
        quantity: quantity,
      );

  Future<List<TripItem>> rowsOf(int tripId) =>
      (db.select(db.tripItems)..where((t) => t.tripId.equals(tripId))).get();

  Future<int?> activeId() async => (await db.select(db.appSettings).getSingle()).activeTripId;

  test('copying a trip carries its list and quantities, but nothing is in the bag', () async {
    final stove = await addGear('Горелка');
    final gas = await addGear('Газ', quantity: 5);
    final source = await db.createTrip(name: 'Карелия');
    await db.setItemPacked(stove, true);
    await db.setItemPacked(gas, true);
    await db.setTripItemQuantity(source, gas, 2);
    await db.setInBag(source, stove, true);

    final copy = await db.createTrip(name: 'Карелия 2', copyFromTripId: source);
    final rows = {for (final r in await rowsOf(copy)) r.itemId: r};

    expect(rows.keys, unorderedEquals([stove, gas]));
    expect(rows[gas]!.quantity, 2);
    expect(rows.values.every((r) => !r.inBag), isTrue);
    expect(await activeId(), copy);
  });

  test('ticking gear with no trip yet starts a draft, which can become a trip', () async {
    final stove = await addGear('Горелка');
    await db.setItemPacked(stove, true);

    final draft = (await db.select(db.trips).get()).single;
    expect(draft.isDraft, isTrue);
    expect(draft.name, 'Черновик');

    await db.updateTrip(id: draft.id, name: 'Карелия', isDraft: false);
    final trip = (await db.select(db.trips).get()).single;
    expect(trip.isDraft, isFalse);
    expect(trip.name, 'Карелия');
    expect(await rowsOf(trip.id), hasLength(1));
  });

  test('deleting the active trip hands "active" to the newest remaining trip', () async {
    final first = await db.createTrip(name: 'Первый');
    final second = await db.createTrip(name: 'Второй');
    final third = await db.createTrip(name: 'Третий');
    await db.setActiveTrip(third);

    await db.deleteTrip(third);
    expect(await activeId(), second);

    await db.deleteTrip(second);
    await db.deleteTrip(first);
    expect(await activeId(), isNull);
  });

  test('deleting a trip removes its list but keeps the items', () async {
    final stove = await addGear('Горелка');
    final trip = await db.createTrip(name: 'Поход');
    await db.setItemPacked(stove, true);

    await db.deleteTrip(trip);

    expect(await rowsOf(trip), isEmpty);
    expect(await db.select(db.items).get(), hasLength(1));
  });

  test('duplicating a trip numbers copies like items do', () async {
    final id = await db.createTrip(name: 'Эльбрус');
    final original = await (db.select(db.trips)..where((t) => t.id.equals(id))).getSingle();
    final first = await db.duplicateTrip(original);
    final second = await db.duplicateTrip(original);
    final names = {for (final t in await db.select(db.trips).get()) t.id: t.name};

    expect(names[first], 'Эльбрус (копия)');
    expect(names[second], 'Эльбрус (копия 2)');
  });

  test('worn items stay out of the pack weight and are counted on their own', () async {
    final pack = await addGear('Рюкзак');
    final boots = await db.addItem(
      name: 'Ботинки',
      weightGrams: 900,
      condition: ItemCondition.newItem,
      packType: PackType.gear,
      worn: true,
    );
    await db.setItemPacked(pack, true);
    await db.setItemPacked(boots, true);

    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    // Riverpod pauses providers nobody listens to — listen, then wait until
    // the active trip's list has actually loaded.
    container.listen(activeTripItemsProvider, (_, _) {});
    container.listen(tripSummariesProvider, (_, _) {});
    while ((container.read(activeTripItemsProvider).value ?? const []).length < 2) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(container.read(totalWeightProvider), 100);
    expect(container.read(wornWeightProvider), 900);
    expect(container.read(weightByPackTypeProvider)[PackType.gear], 100);
    final summary = (await container.read(tripSummariesProvider.future)).values.single;
    expect(summary.grams, 100);
    expect(summary.itemCount, 2);
  });

  test('trip quantity defaults to all owned and never exceeds what is owned', () {
    const item = Item(uuid: '', updatedAt: 0, worn: false,
      id: 1,
      name: 'Газ',
      weightGrams: 100,
      condition: ItemCondition.newItem,
      quantity: 3,
    );
    TripItem row(int? quantity) =>
        TripItem(updatedAt: 0, tripId: 1, itemId: 1, quantity: quantity, inBag: false);

    expect(tripQuantity(row(null), item), 3);
    expect(tripQuantity(row(2), item), 2);
    expect(tripQuantity(row(5), item), 3);
  });

  group('formatTripDates', () {
    final today = DateTime(2026, 10, 18);
    String? ru(DateTime? a, DateTime? b) =>
        formatTripDates(a, b, languageCode: 'ru', today: today);
    String? en(DateTime? a, DateTime? b) =>
        formatTripDates(a, b, languageCode: 'en', today: today);

    test('no dates → null', () {
      expect(ru(null, null), isNull);
      expect(en(null, null), isNull);
    });

    test('same month collapses to one month name', () {
      expect(ru(DateTime(2026, 10, 12), DateTime(2026, 10, 14)), '12–14 окт');
      expect(en(DateTime(2026, 10, 12), DateTime(2026, 10, 14)), 'Oct 12–14');
    });

    test('across months names both', () {
      expect(ru(DateTime(2026, 10, 30), DateTime(2026, 11, 2)), '30 окт – 2 ноя');
      expect(en(DateTime(2026, 10, 30), DateTime(2026, 11, 2)), 'Oct 30 – Nov 2');
    });

    test('a single day, and a year only when it is not this year', () {
      expect(ru(DateTime(2026, 10, 12), null), '12 окт');
      expect(ru(DateTime(2027, 1, 5), DateTime(2027, 1, 5)), '5 янв 2027');
      expect(en(DateTime(2026, 10, 12), null), 'Oct 12');
      expect(en(DateTime(2027, 1, 5), DateTime(2027, 1, 7)), 'Jan 5–7, 2027');
    });
  });

  test('duplicating in English numbers "(copy)", and copying a Russian copy drops "(копия)"',
      () async {
    final id = await db.createTrip(name: 'Rockies');
    final original = await (db.select(db.trips)..where((t) => t.id.equals(id))).getSingle();
    final first = await db.duplicateTrip(original, copyWord: 'copy');
    final second = await db.duplicateTrip(original, copyWord: 'copy');
    final ruCopy = await db.createTrip(name: 'Rockies (копия)');
    final fromRu = await db.duplicateTrip(
      await (db.select(db.trips)..where((t) => t.id.equals(ruCopy))).getSingle(),
      copyWord: 'copy',
    );
    final names = {for (final t in await db.select(db.trips).get()) t.id: t.name};

    expect(names[first], 'Rockies (copy)');
    expect(names[second], 'Rockies (copy 2)');
    expect(names[fromRu], 'Rockies (copy 3)');
  });

  test('clearing all data leaves a fresh install, but keeps the settings', () async {
    final stove = await addGear('Горелка');
    await db.setItemPacked(stove, true);
    await db.updateLanguage(AppLanguage.en);

    await db.clearAllData(language: 'en');

    expect(await db.select(db.items).get(), isEmpty);
    expect(await db.select(db.trips).get(), isEmpty);
    expect(await db.select(db.tripItems).get(), isEmpty);
    expect(await activeId(), isNull);
    final categories = (await db.select(db.categories).get()).map((c) => c.name);
    expect(categories, containsAll(['Packs', 'Kitchen']));
    expect(categories, hasLength(6));
    expect((await db.select(db.appSettings).getSingle()).language, AppLanguage.en);
  });

  test('starter categories are named in the install language', () async {
    // A second, separate in-memory database next to setUp's — on purpose.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final en = AppDatabase.forTesting(NativeDatabase.memory(), seedLanguage: 'en');
    addTearDown(en.close);
    final names = (await en.select(en.categories).get()).map((c) => c.name);
    expect(names, containsAll(['Packs', 'Kitchen', 'Food', 'Water']));
    expect((await db.select(db.categories).get()).map((c) => c.name), contains('Кухня'));
  });
}
