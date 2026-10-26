import 'package:backpack/data/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addGear(String name) => db.addItem(
        name: name,
        weightGrams: 100,
        condition: ItemCondition.newItem,
        packType: PackType.gear,
      );

  Future<Item> itemById(int id) =>
      (db.select(db.items)..where((i) => i.id.equals(id))).getSingle();

  Future<List<(String, String)>> deletions() async => [
        for (final d in await db.select(db.syncDeletions).get()) (d.entity, d.entityKey),
      ];

  test('every row gets its own uuid — seeded categories too', () async {
    await addGear('Горелка');
    await addGear('Котелок');
    await db.createTrip(name: 'Карелия');
    final uuids = [
      for (final c in await db.select(db.categories).get()) c.uuid,
      for (final i in await db.select(db.items).get()) i.uuid,
      for (final t in await db.select(db.trips).get()) t.uuid,
    ];
    expect(uuids.every((u) => u.length == 36), isTrue);
    expect(uuids.toSet(), hasLength(uuids.length));
  });

  test('any edit bumps updatedAt by itself; one that sets it keeps its value', () async {
    final id = await addGear('Горелка');
    // As if it was last changed long ago.
    await (db.update(db.items)..where((i) => i.id.equals(id)))
        .write(const ItemsCompanion(updatedAt: Value(1)));
    expect((await itemById(id)).updatedAt, 1);

    final before = nowMs();
    await db.updateItem(
      id: id,
      name: 'Горелка MSR',
      weightGrams: 80,
      condition: ItemCondition.newItem,
      packType: PackType.gear,
    );
    expect((await itemById(id)).updatedAt, greaterThanOrEqualTo(before - 5));

    // Trip rows too — e.g. ticking an item into the bag.
    final trip = await db.createTrip(name: 'Карелия');
    await db.setItemPacked(id, true);
    final row = await db.select(db.tripItems).getSingle();
    await (db.update(db.tripItems)..where((t) => t.tripId.equals(trip)))
        .write(const TripItemsCompanion(updatedAt: Value(1)));
    await db.setInBag(trip, id, true);
    expect((await db.select(db.tripItems).getSingle()).updatedAt, greaterThan(row.updatedAt - 5));
  });

  test('deletes are logged for the cloud, a trip list entry by both uuids', () async {
    final stove = await addGear('Горелка');
    final trip = await db.createTrip(name: 'Карелия');
    await db.setItemPacked(stove, true);
    final stoveUuid = (await itemById(stove)).uuid;
    final tripUuid = (await db.select(db.trips).getSingle()).uuid;

    await db.setItemPacked(stove, false);
    expect(await deletions(), [('trip_items', '$tripUuid/$stoveUuid')]);

    await db.deleteItem(stove);
    await db.deleteTrip(trip);
    expect(await deletions(), [
      ('trip_items', '$tripUuid/$stoveUuid'),
      ('items', stoveUuid),
      ('trips', tripUuid),
    ]);
  });

  test('updating a schema 19 install keeps everything and gives each row a uuid', () async {
    final old = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      raw.execute('''
        CREATE TABLE categories (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL, parent_id INTEGER NULL, pack_type INTEGER NOT NULL,
          icon TEXT NULL, color TEXT NULL);
        CREATE TABLE items (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL, weight_grams INTEGER NOT NULL, category_id INTEGER NULL,
          condition INTEGER NOT NULL, pack_type INTEGER NULL,
          quantity INTEGER NOT NULL DEFAULT 1, worn INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE trips (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL, target_weight_grams INTEGER NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          start_date INTEGER NULL, end_date INTEGER NULL,
          is_draft INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE trip_items (trip_id INTEGER NOT NULL, item_id INTEGER NOT NULL,
          quantity INTEGER NULL, in_bag INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (trip_id, item_id));
        CREATE TABLE app_settings (id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
          active_trip_id INTEGER NULL, theme_mode INTEGER NOT NULL DEFAULT 0,
          language INTEGER NOT NULL DEFAULT 0, weight_unit INTEGER NULL);
        INSERT INTO app_settings (id, active_trip_id) VALUES (1, 1);
        INSERT INTO categories (name, pack_type) VALUES ('Кухня', 1);
        INSERT INTO items (name, weight_grams, category_id, condition) VALUES
          ('Горелка', 80, 1, 0), ('Котелок', 120, 1, 2);
        INSERT INTO trips (name) VALUES ('Карелия');
        INSERT INTO trip_items (trip_id, item_id, in_bag) VALUES (1, 1, 1);
        PRAGMA user_version = 19;
      ''');
    }));
    addTearDown(old.close);

    final items = await old.select(old.items).get();
    expect(items.map((i) => i.name), ['Горелка', 'Котелок']);
    expect(items.map((i) => i.condition), [ItemCondition.newItem, ItemCondition.wornOut]);
    expect(items.every((i) => i.uuid.length == 36 && i.updatedAt > 0), isTrue);
    expect(items.map((i) => i.uuid).toSet(), hasLength(2));
    expect((await old.select(old.categories).getSingle()).uuid, hasLength(36));
    final trip = await old.select(old.trips).getSingle();
    expect(trip.uuid, hasLength(36));
    expect((await old.select(old.tripItems).getSingle()).inBag, isTrue);
    expect((await old.select(old.appSettings).getSingle()).activeTripId, trip.id);

    // And the new bookkeeping works on the updated database.
    await old.deleteTrip(trip.id);
    expect(
      [for (final d in await old.select(old.syncDeletions).get()) d.entity],
      ['trip_items', 'trips'],
    );
  });
}
