import 'package:backpack/account/api_client.dart';
import 'package:backpack/data/database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_server.dart';
import 'helpers/phone.dart';

void main() {
  late FakeServer server;
  late Phone a;
  late Phone b;

  setUp(() async {
    server = FakeServer();
    a = await Phone(server).empty();
    b = await Phone(server).empty();
  });

  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  test('gear, categories and a trip made on one phone arrive on the other', () async {
    final sleep = await a.addCategory('Сон');
    final bags = await a.addCategory('Спальники', parentId: sleep);
    final bag = await a.addItem('Спальник', categoryId: bags, grams: 900);
    final stakes = await a.addItem('Колышки', grams: 10);
    await a.db.updateItem(
      id: stakes,
      name: 'Колышки',
      weightGrams: 10,
      condition: ItemCondition.newItem,
      packType: PackType.gear,
      quantity: 8,
    );
    final trip = await a.db.createTrip(name: 'Карелия', targetWeightGrams: 9000, startDate: DateTime(2027, 7, 1));
    await a.db.setItemPacked(bag, true);
    await a.db.setItemPacked(stakes, true);
    await a.db.setTripItemQuantity(trip, stakes, 6);
    await a.db.setInBag(trip, bag, true);

    await a.sync();
    expect(await a.queued(), 0, reason: 'everything was sent');
    await b.sync();

    final bBag = await b.item('Спальник');
    final bBags = await b.category('Спальники');
    expect(bBag.uuid, (await a.item('Спальник')).uuid);
    expect(bBag.weightGrams, 900);
    expect(bBag.categoryId, bBags.id);
    expect(bBags.parentId, (await b.category('Сон')).id);
    expect((await b.item('Колышки')).quantity, 8);

    final bTrip = await b.trip('Карелия');
    expect(bTrip.targetWeightGrams, 9000);
    expect(bTrip.startDate, DateTime(2027, 7, 1));
    final rows = {
      for (final r in await (b.db.select(b.db.tripItems)..where((r) => r.tripId.equals(bTrip.id))).get()) r.itemId: r,
    };
    expect(rows[bBag.id]?.inBag, isTrue);
    expect(rows[(await b.item('Колышки')).id]?.quantity, 6);

    // Applying what came from the cloud queues nothing to send back.
    expect(await b.queued(), 0);
    expect(await b.logged(), 0);
  });

  test('an edit goes across, and nothing comes back to the phone that made it', () async {
    await a.addItem('Горелка');
    await a.sync();
    await b.sync();

    await tick();
    await b.rename('Горелка', 'Горелка MSR');
    await b.sync();
    await a.sync();

    expect(await a.itemNames(), ['Горелка MSR']);
    expect(await b.queued(), 0);

    final before = server.sync.requests;
    await b.sync();
    expect(server.sync.requests, before + 1);
    expect(await b.itemNames(), ['Горелка MSR']);
  });

  test('a deletion goes across, the item\'s trip entries with it', () async {
    final stove = await a.addItem('Горелка');
    await a.addItem('Котелок');
    await a.db.createTrip(name: 'Карелия');
    await a.db.setItemPacked(stove, true);
    await a.sync();
    await b.sync();
    expect(await b.db.select(b.db.tripItems).get(), hasLength(1));

    await tick();
    await a.db.deleteItem(stove);
    await a.sync();
    expect(await a.logged(), 0, reason: 'the deletion was sent');
    await b.sync();

    expect(await b.itemNames(), ['Котелок']);
    expect(await b.db.select(b.db.tripItems).get(), isEmpty);
    expect(await b.logged(), 0, reason: 'a deletion from the cloud isn\'t sent back');
  });

  test('when both phones edit the same item, the later edit wins on both', () async {
    await a.addItem('Горелка');
    await a.sync();
    await b.sync();

    await tick();
    await a.rename('Горелка', 'Горелка A');
    await tick();
    await b.rename('Горелка', 'Горелка B');
    // The earlier edit reaches the server last — it still loses.
    await b.sync();
    await a.sync();
    await b.sync();

    expect(await a.itemNames(), ['Горелка B']);
    expect(await b.itemNames(), ['Горелка B']);
  });

  test('an item deleted on one phone but edited later on the other survives', () async {
    await a.addItem('Горелка');
    await a.sync();
    await b.sync();

    await tick();
    await a.db.deleteItem((await a.item('Горелка')).id);
    await tick();
    await b.rename('Горелка', 'Горелка MSR');
    await a.sync();
    await b.sync();
    await a.sync();

    expect(await a.itemNames(), ['Горелка MSR']);
    expect(await b.itemNames(), ['Горелка MSR']);
  });

  test('a category deleted elsewhere leaves its items uncategorized, still counting in its section', () async {
    final food = await a.addCategory('Перекусы', packType: PackType.food);
    await a.addItem('Орехи', categoryId: food);
    await a.sync();
    await b.sync();

    await tick();
    await a.db.deleteCategory(food);
    await a.sync();
    await b.sync();

    final nuts = await b.item('Орехи');
    expect(nuts.categoryId, isNull);
    expect(nuts.packType, PackType.food);
    expect(await b.db.select(b.db.categories).get(), isEmpty);
  });

  test('when the trip shown on Главная is deleted elsewhere, another takes its place', () async {
    await a.db.createTrip(name: 'Карелия');
    await tick();
    await a.db.createTrip(name: 'Алтай');
    await a.sync();
    await b.sync();
    await b.db.setActiveTrip((await b.trip('Алтай')).id);

    await tick();
    await a.db.deleteTrip((await a.trip('Алтай')).id);
    await a.sync();
    await b.sync();

    expect((await b.db.activeTrip())?.name, 'Карелия');
  });

  test('lots of changes go and come in turns', () async {
    final small = await Phone(server, batchSize: 2, pageSize: 2).empty();
    final other = await Phone(server, batchSize: 2, pageSize: 2).empty();
    addTearDown(small.db.close);
    addTearDown(other.db.close);
    final kitchen = await small.addCategory('Кухня');
    for (var n = 1; n <= 5; n++) {
      await small.addItem('Вещь $n', categoryId: kitchen);
    }

    await small.sync();
    expect(await small.queued(), 0);
    await other.sync();

    expect(await other.itemNames(), ['Вещь 1', 'Вещь 2', 'Вещь 3', 'Вещь 4', 'Вещь 5']);
    final kitchenId = (await other.category('Кухня')).id;
    expect((await other.db.select(other.db.items).get()).every((i) => i.categoryId == kitchenId), isTrue);
  });

  test('an edit made while a sync is on its way is sent next time, not lost', () async {
    await a.addItem('Горелка');
    await a.sync();
    server.sync.whileHandling = () async {
      server.sync.whileHandling = null;
      await tick();
      await a.rename('Горелка', 'Горелка MSR');
    };
    await a.sync();
    expect(await a.queued(), 1);

    await a.sync();
    await b.sync();
    expect(await b.itemNames(), ['Горелка MSR']);
  });

  test('syncing again while a sync runs waits for it, then sends what changed', () async {
    await a.addItem('Горелка');
    final first = a.sync();
    await a.addItem('Котелок');
    final second = a.sync();
    await Future.wait([first, second]);

    await b.sync();
    expect(await b.itemNames(), ['Горелка', 'Котелок']);
  });

  test('offline: the queue stays for next time', () async {
    await a.addItem('Горелка');
    server.down = true;
    await expectLater(a.sync(), throwsA(isA<NetworkException>()));
    expect(await a.queued(), 1);

    server.down = false;
    await a.sync();
    expect(await a.queued(), 0);
  });

  test('an edit here always ends up later than the version it changed, even one from a clock running ahead', () async {
    final id = await a.addItem('Горелка');
    final future = nowMs() + const Duration(days: 1).inMilliseconds;
    await (a.db.update(a.db.items)..where((i) => i.id.equals(id))).write(ItemsCompanion(updatedAt: Value(future)));

    await a.rename('Горелка', 'Горелка MSR');
    expect((await a.item('Горелка MSR')).updatedAt, future + 1);
  });
}
