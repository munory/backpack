import 'package:backpack/account/api_client.dart';
import 'package:backpack/account/token_store.dart';
import 'package:backpack/data/database.dart';
import 'package:backpack/sync/sync_engine.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'fake_server.dart';

/// One phone signed in to the shared pretend server.
class Phone {
  Phone(FakeServer server, {AppDatabase? db, this.accountId = 'u1', int batchSize = 500, int pageSize = 500})
      : db = db ?? AppDatabase.forTesting(NativeDatabase.memory()) {
    final api = ApiClient(
      tokens: MemoryTokenStore(Tokens(access: server.validAccess, refresh: server.validRefresh)),
      httpClient: server.client,
      baseUrl: 'http://server',
    );
    engine = SyncEngine(db: this.db, api: api, batchSize: batchSize, pageSize: pageSize);
  }

  final AppDatabase db;
  final String accountId;
  late final SyncEngine engine;

  Future<void> sync() => engine.sync(accountId: accountId);

  /// Without the starter categories — every phone seeds its own, and
  /// matching those up is the first sign-in's job (stage 13.2), not this.
  Future<Phone> empty() async {
    await db.delete(db.categories).go();
    await db.delete(db.syncOutbox).go();
    await db.delete(db.syncDeletions).go();
    return this;
  }

  Future<int> addCategory(String name, {int? parentId, PackType packType = PackType.gear}) => db
      .into(db.categories)
      .insert(CategoriesCompanion.insert(name: name, packType: packType, parentId: Value(parentId)));

  Future<int> addItem(String name, {int? categoryId, int grams = 100}) => db.addItem(
        name: name,
        weightGrams: grams,
        categoryId: categoryId,
        condition: ItemCondition.newItem,
        packType: categoryId == null ? PackType.gear : null,
      );

  Future<Item> item(String name) => (db.select(db.items)..where((i) => i.name.equals(name))).getSingle();
  Future<Item?> maybeItem(String name) =>
      (db.select(db.items)..where((i) => i.name.equals(name))).getSingleOrNull();
  Future<Category> category(String name) =>
      (db.select(db.categories)..where((c) => c.name.equals(name))).getSingle();
  Future<Trip> trip(String name) => (db.select(db.trips)..where((t) => t.name.equals(name))).getSingle();
  Future<List<String>> itemNames() async => [for (final i in await db.select(db.items).get()) i.name]..sort();

  Future<void> rename(String from, String to) async {
    final i = await item(from);
    await (db.update(db.items)..where((x) => x.id.equals(i.id))).write(ItemsCompanion(name: Value(to)));
  }

  Future<int> queued() async => (await db.select(db.syncOutbox).get()).length;
  Future<int> logged() async => (await db.select(db.syncDeletions).get()).length;
}

/// Lets the clock move on, so the next edit is measurably later.
Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 5));
