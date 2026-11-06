import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_server.dart';
import 'helpers/phone.dart';

/// The first sync with an account: the phone's data and the account's
/// meet, and what's the same thing by name becomes one.
void main() {
  late FakeServer server;
  late Phone a;
  late Phone b;

  // Both start as fresh installs, starter categories and all.
  setUp(() {
    server = FakeServer();
    a = Phone(server);
    b = Phone(server);
  });

  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  Future<List<String>> categoryNames(Phone p) async =>
      [for (final c in await p.db.select(p.db.categories).get()) c.name]..sort();

  test('the starter categories don\'t double', () async {
    await a.sync();
    await b.sync();
    await a.sync();

    expect(await categoryNames(b), await categoryNames(a));
    expect(await categoryNames(b), hasLength(6));
    expect(server.sync.stored('categories'), hasLength(6));
  });

  test('the same item on both phones becomes one — the newer version of it', () async {
    final kitchen = (await a.category('Кухня')).id;
    await a.addItem('Горелка', categoryId: kitchen, grams: 90);
    await a.sync();

    await tick();
    // Typed in on the second phone too, later, a bit differently.
    await b.addItem('  горелка ', categoryId: (await b.category('Кухня')).id, grams: 85);
    await b.sync();
    await a.sync();

    for (final p in [a, b]) {
      final items = await p.db.select(p.db.items).get();
      expect(items, hasLength(1));
      expect(items.single.weightGrams, 85);
      expect(items.single.categoryId, (await p.category('Кухня')).id);
    }
  });

  test('when the account\'s version is newer, it replaces the phone\'s', () async {
    await b.addItem('Горелка', grams: 85);
    await tick();
    await a.addItem('Горелка', grams: 90);
    await a.sync();
    await b.sync();

    expect((await b.item('Горелка')).weightGrams, 90);
    expect(server.sync.stored('items').single['weightGrams'], 90);
  });

  test('same-named items pair up one to one', () async {
    for (var n = 0; n < 2; n++) {
      await a.addItem('Колышек');
    }
    for (var n = 0; n < 3; n++) {
      await b.addItem('Колышек');
    }
    await a.sync();
    await b.sync();
    await a.sync();

    expect((await a.itemNames()).length, 3);
    expect((await b.itemNames()).length, 3);
  });

  test('items in different categories, or only on one side, are all kept', () async {
    await a.addItem('Нож', categoryId: (await a.category('Кухня')).id);
    await a.addItem('Только у A');
    await b.addItem('Нож', categoryId: (await b.category('Одежда')).id);
    await b.addItem('Только у B');
    await a.sync();
    await b.sync();
    await a.sync();

    final expected = ['Нож', 'Нож', 'Только у A', 'Только у B'];
    expect(await a.itemNames(), expected);
    expect(await b.itemNames(), expected);
  });

  test('nested categories match level by level', () async {
    final sleepA = (await a.category('Спальная система')).id;
    await a.addCategory('Коврики', parentId: sleepA);
    final sleepB = (await b.category('Спальная система')).id;
    await b.addCategory('Коврики', parentId: sleepB);
    // Same name, but under another parent: a different category.
    await b.addCategory('Коврики', parentId: (await b.category('Одежда')).id);
    await a.sync();
    await b.sync();

    final mats = await (b.db.select(b.db.categories)..where((c) => c.name.equals('Коврики'))).get();
    expect(mats, hasLength(2));
    expect(server.sync.stored('categories'), hasLength(8));
  });

  test('a trip with the same name merges, and so do the lists of gear in it', () async {
    final stoveA = await a.addItem('Горелка');
    await a.db.createTrip(name: 'Карелия');
    await a.db.setItemPacked(stoveA, true);

    final stoveB = await b.addItem('Горелка');
    final potB = await b.addItem('Котелок');
    await b.db.createTrip(name: 'карелия');
    await b.db.setItemPacked(stoveB, true);
    await b.db.setItemPacked(potB, true);
    // Ticked without a trip first — a draft on each phone.
    await a.db.createTrip(name: 'Черновик', isDraft: true);
    await b.db.createTrip(name: 'Draft', isDraft: true);

    await a.sync();
    await b.sync();
    await a.sync();

    for (final p in [a, b]) {
      final trips = await p.db.select(p.db.trips).get();
      expect(trips, hasLength(2), reason: 'one Карелия, one draft');
      final karelia = trips.singleWhere((t) => !t.isDraft);
      final list = await (p.db.select(p.db.tripItems)..where((r) => r.tripId.equals(karelia.id))).get();
      expect(list, hasLength(2));
    }
  });

  test('deletions made before signing in aren\'t sent: the account never had those rows', () async {
    await a.sync();
    // "Кухня" deleted on the second phone while it was never signed in.
    await b.db.deleteCategory((await b.category('Кухня')).id);
    expect(await b.logged(), 1);
    await b.sync();
    await a.sync();

    expect(await b.logged(), 0);
    expect(server.sync.tombstones, isEmpty);
    expect(await categoryNames(a), contains('Кухня'));
    expect(await categoryNames(b), contains('Кухня'), reason: 'the account had it, so it comes back');
  });

  test('after the first sync, the next one is an ordinary one', () async {
    await a.sync();
    await b.sync();
    await b.addItem('Горелка');
    await b.sync();
    await a.sync();
    await a.addItem('Горелка');
    await a.sync();
    await b.sync();

    expect(await b.itemNames(), ['Горелка', 'Горелка'], reason: 'no more matching by name');
  });

  test('another account signing in on the phone gets the phone\'s data too', () async {
    await a.addItem('Горелка');
    await a.sync();

    final other = FakeServer();
    final secondAccount = Phone(other, db: a.db, accountId: 'u2');
    await secondAccount.sync();

    expect(other.sync.stored('items').map((r) => r['name']), ['Горелка']);
    expect(other.sync.stored('categories'), hasLength(6));
    final state = await a.db.select(a.db.syncState).getSingle();
    expect(state.accountId, 'u2');
  });
}
