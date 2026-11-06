import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/account_provider.dart';
import '../account/api_client.dart';
import '../data/database.dart';
import '../data/providers.dart';
import 'wire.dart';

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(db: ref.watch(databaseProvider), api: ref.watch(apiClientProvider)),
);

/// Keeps this phone and the cloud copy the same. One [sync] is one
/// conversation with the server: "here's what changed on this phone — what
/// changed elsewhere?". The phone stays the source of truth; when two
/// devices changed the same row, the later edit wins (the server's rule,
/// applied the same way here).
///
/// Throws what [ApiClient] throws ([NetworkException] when offline, …) —
/// nothing is lost then: the queue stays and the next sync sends it.
class SyncEngine {
  SyncEngine({required this._db, required this._api, this.batchSize = 500, this.pageSize = 500});

  final AppDatabase _db;
  final ApiClient _api;

  /// Rows sent per request, at most (of each kind); more go in turns.
  final int batchSize;

  /// Rows asked for per request.
  final int pageSize;

  Future<void>? _running;
  bool _again = false;
  String? _accountId;

  /// Syncs now with the account [accountId] is signed in to. Asked again
  /// while already syncing, it runs once more right after — whatever
  /// changed in the meantime is sent too — and both callers wait for that.
  Future<void> sync({required String accountId}) {
    _accountId = accountId;
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<void> _loop() async {
    do {
      _again = false;
      await _syncOnce(_accountId!);
    } while (_again);
  }

  Future<void> _syncOnce(String accountId) async {
    final state = await _db.select(_db.syncState).getSingle();
    if (state.accountId != accountId) await _firstSync(accountId);
    while (true) {
      final batch = await _collect();
      final cursor = (await _db.select(_db.syncState).getSingle()).cursor;
      final pages = await _fetch(cursor, batch);
      await _apply(pages, batch);
      if (!batch.full) return;
    }
  }

  /// Sends [batch] and fetches everything changed since [cursor] — all of
  /// it before any is applied: an item can come a page before its category.
  Future<List<_Page>> _fetch(int cursor, _Batch? batch) async {
    var page = await _exchange(cursor, batch);
    final pages = [page];
    while (page.hasMore) {
      page = await _exchange(page.cursor, null);
      pages.add(page);
    }
    return pages;
  }

  // --- The first sync with an account -----------------------------------------

  /// The phone's data meets the account's for the first time: on this
  /// phone's first sign-in, or when someone else signs in on it. The phone
  /// may already hold the same things under its own uuids — the starter
  /// categories, gear typed in on both devices — so before anything is
  /// sent, rows that are the same thing by name take the account's uuid.
  /// From then on each pair is one row, and the newer version wins as in
  /// any sync. Nothing is lost: what has no match is simply added.
  Future<void> _firstSync(String accountId) async {
    final pages = await _fetch(0, null);
    await _db.transaction(() async {
      await _adoptMatches(pages);
      // Deletions made before signing in are of rows this account never
      // had; and all of the phone's data goes to the account, not just
      // recent edits.
      await _db.delete(_db.syncDeletions).go();
      await _db.delete(_db.syncOutbox).go();
      for (final table in const ['categories', 'items', 'trips']) {
        await _db.customStatement(
            "INSERT INTO sync_outbox (entity, row_key) SELECT '$table', CAST(id AS TEXT) FROM $table");
      }
      await _db.customStatement("INSERT INTO sync_outbox (entity, row_key) "
          "SELECT 'trip_items', trip_id || '/' || item_id FROM trip_items");
      // Where the account's copy is newer, it replaces the phone's (and
      // isn't sent back); everything else stays queued.
      await _apply(pages, null);
      await _db.update(_db.syncState).write(SyncStateCompanion(accountId: Value(accountId)));
    });
  }

  /// Matches the phone's rows to the account's by name, case and spaces
  /// aside: a category by name within its (matched) parent, an item by name
  /// within its (matched) category, a trip by name — drafts with drafts.
  /// Same-named rows pair up one to one: two "Колышки" here and three there
  /// are three in the end.
  Future<void> _adoptMatches(List<_Page> pages) async {
    // Categories move down the tree: "Сон > Спальники" here meets
    // "Сон > Спальники" there only once both "Сон" have met.
    final localCategories = await _db.select(_db.categories).get();
    final uuidOf = {for (final c in localCategories) c.id: c.uuid};
    final categoryPool = _pool(
      _newest(pages, (p) => p.categories, (r) => r['uuid'] as String),
      except: uuidOf.values.toSet(),
      key: (r) => '${r['parentUuid']}|${_norm(r['name'])}',
    );
    var level = localCategories.where((c) => c.parentId == null).toList();
    while (level.isNotEmpty) {
      for (final c in level) {
        final parent = c.parentId == null ? null : uuidOf[c.parentId];
        if (_take(categoryPool, '$parent|${_norm(c.name)}') case final uuid?) {
          await _adoptUuid('categories', c.id, c.updatedAt, uuid);
          uuidOf[c.id] = uuid;
        }
      }
      final ids = {for (final c in level) c.id};
      level = localCategories.where((c) => ids.contains(c.parentId)).toList();
    }

    final localItems = await _db.select(_db.items).get();
    final itemPool = _pool(
      _newest(pages, (p) => p.items, (r) => r['uuid'] as String),
      except: {for (final i in localItems) i.uuid},
      key: (r) => '${r['categoryUuid']}|${_norm(r['name'])}',
    );
    for (final i in localItems) {
      final category = i.categoryId == null ? null : uuidOf[i.categoryId];
      if (_take(itemPool, '$category|${_norm(i.name)}') case final uuid?) {
        await _adoptUuid('items', i.id, i.updatedAt, uuid);
      }
    }

    String tripKey(Object? isDraft, Object? name) => isDraft == true ? 'draft' : 'trip|${_norm(name)}';
    final localTrips = await _db.select(_db.trips).get();
    final tripPool = _pool(
      _newest(pages, (p) => p.trips, (r) => r['uuid'] as String),
      except: {for (final t in localTrips) t.uuid},
      key: (r) => tripKey(r['isDraft'], r['name']),
    );
    for (final t in localTrips) {
      if (_take(tripPool, tripKey(t.isDraft, t.name)) case final uuid?) {
        await _adoptUuid('trips', t.id, t.updatedAt, uuid);
      }
    }
  }

  static String _norm(Object? name) => (name as String? ?? '').trim().toLowerCase();

  /// The account's rows by match key, minus the ones the phone already has.
  static Map<String, List<String>> _pool(
    List<Map<String, dynamic>> rows, {
    required Set<String> except,
    required String Function(Map<String, dynamic>) key,
  }) {
    final pool = <String, List<String>>{};
    for (final r in rows) {
      if (except.contains(r['uuid'])) continue;
      pool.putIfAbsent(key(r), () => []).add(r['uuid'] as String);
    }
    return pool;
  }

  /// The next unmatched uuid under [key] — each pairs up only once.
  static String? _take(Map<String, List<String>> pool, String key) {
    final candidates = pool[key];
    return candidates == null || candidates.isEmpty ? null : candidates.removeAt(0);
  }

  /// Gives a row the account's uuid without making it look newly edited —
  /// its own edit time is what decides against the account's version. (A
  /// placeholder time set first keeps the touch trigger out of it.)
  Future<void> _adoptUuid(String table, int id, int updatedAt, String uuid) async {
    await _db.customUpdate('UPDATE $table SET uuid = ?, updated_at = -1 WHERE id = ?',
        variables: [Variable(uuid), Variable(id)]);
    await _db.customUpdate('UPDATE $table SET updated_at = ? WHERE id = ?',
        variables: [Variable(updatedAt), Variable(id)]);
  }

  Future<_Page> _exchange(int cursor, _Batch? batch) async {
    final json = await _api.signedIn('POST', '/sync', body: {
      'cursor': cursor,
      'limit': pageSize,
      if (batch != null) ...{
        'changes': {
          'categories': batch.categories,
          'items': batch.items,
          'trips': batch.trips,
          'tripItems': batch.tripItems,
        },
        'deletions': batch.deletions,
      },
    });
    return _Page(json);
  }

  // --- Sending ----------------------------------------------------------------

  /// The next rows from the queue and the deletion log, ready to send.
  Future<_Batch> _collect() async {
    final queued = await (_db.select(_db.syncOutbox)
          ..orderBy([(o) => OrderingTerm.asc(o.id)])
          ..limit(batchSize))
        .get();
    final deleted = await (_db.select(_db.syncDeletions)
          ..orderBy([(d) => OrderingTerm.asc(d.id)])
          ..limit(batchSize))
        .get();
    final batch = _Batch(
      lastQueued: queued.lastOrNull?.id,
      lastDeleted: deleted.lastOrNull?.id,
      full: queued.length == batchSize || deleted.length == batchSize,
      deletions: [
        for (final d in deleted) {'entity': d.entity, 'key': d.entityKey.toLowerCase(), 'deletedAt': d.deletedAt},
      ],
    );
    if (queued.isEmpty) return batch;

    final categories = {for (final c in await _db.select(_db.categories).get()) c.id: c};
    final items = {for (final i in await _db.select(_db.items).get()) i.id: i};
    final trips = {for (final t in await _db.select(_db.trips).get()) t.id: t};
    final categoryUuids = categories.map((id, c) => MapEntry(id, c.uuid));

    for (final entry in queued) {
      // A row deleted since it was queued is skipped — its deletion goes
      // instead.
      switch (entry.entity) {
        case 'categories':
          if (categories[int.tryParse(entry.rowKey)] case final c?) {
            batch.categories.add(Wire.category(c, categoryUuids));
          }
        case 'items':
          if (items[int.tryParse(entry.rowKey)] case final i?) batch.items.add(Wire.item(i, categoryUuids));
        case 'trips':
          if (trips[int.tryParse(entry.rowKey)] case final t?) batch.trips.add(Wire.trip(t));
        case 'trip_items':
          final [tripId, itemId] = entry.rowKey.split('/').map(int.parse).toList();
          final trip = trips[tripId];
          final item = items[itemId];
          final row = await (_db.select(_db.tripItems)
                ..where((r) => r.tripId.equals(tripId) & r.itemId.equals(itemId)))
              .getSingleOrNull();
          if (trip != null && item != null && row != null) {
            batch.tripItems.add(Wire.tripItem(row, trip.uuid, item.uuid));
          }
      }
    }
    return batch;
  }

  // --- Receiving --------------------------------------------------------------

  /// Writes what the server sent into the phone's database, all at once —
  /// so the screens never show half of it — and moves the bookmark on.
  Future<void> _apply(List<_Page> pages, _Batch? sent) {
    return _db.transaction(() async {
      // These writes come *from* the cloud: the triggers queue them for
      // sending and log their deletions like any other write, so whatever
      // they add past this point is taken back out below.
      final queuedBefore = await _maxId(_db.syncOutbox, _db.syncOutbox.id);
      final loggedBefore = await _maxId(_db.syncDeletions, _db.syncDeletions.id);

      await _applyCategories(_newest(pages, (p) => p.categories, (r) => r['uuid'] as String));
      await _applyItems(_newest(pages, (p) => p.items, (r) => r['uuid'] as String));
      await _applyTrips(_newest(pages, (p) => p.trips, (r) => r['uuid'] as String));
      await _applyTripItems(_newest(pages, (p) => p.tripItems, (r) => '${r['tripUuid']}/${r['itemUuid']}'));
      final removedCategories = await _applyDeletions(pages);

      await (_db.delete(_db.syncOutbox)..where((o) => o.id.isBiggerThanValue(queuedBefore))).go();
      await (_db.delete(_db.syncDeletions)..where((d) => d.id.isBiggerThanValue(loggedBefore))).go();

      // What was sent is in the cloud now. A row changed again while the
      // request was on its way was queued anew, under a later number, and
      // stays for next time.
      if (sent?.lastQueued case final last?) {
        await (_db.delete(_db.syncOutbox)..where((o) => o.id.isSmallerOrEqualValue(last))).go();
      }
      if (sent?.lastDeleted case final last?) {
        await (_db.delete(_db.syncDeletions)..where((d) => d.id.isSmallerOrEqualValue(last))).go();
      }

      await _tidyAfter(removedCategories);
      await _db.update(_db.syncState).write(SyncStateCompanion(cursor: Value(pages.last.cursor)));
    });
  }

  Future<void> _applyCategories(List<Map<String, dynamic>> incoming) async {
    final local = {for (final c in await _db.select(_db.categories).get()) c.uuid: c};
    final changed = [
      for (final w in incoming)
        if (_isNewer(w, local[w['uuid']]?.updatedAt)) w,
    ];
    // New ones first, so a parent that arrived in the same batch exists by
    // the time its children point at it.
    for (final w in changed) {
      if (local.containsKey(w['uuid'])) continue;
      await _db.into(_db.categories).insert(CategoriesCompanion.insert(
            uuid: Value(w['uuid'] as String),
            name: w['name'] as String,
            packType: PackType.gear,
            updatedAt: const Value(0),
          ));
    }
    final ids = await _categoryIds();
    for (final w in changed) {
      await (_db.update(_db.categories)..where((c) => c.uuid.equals(w['uuid'] as String))).write(CategoriesCompanion(
        name: Value(w['name'] as String),
        parentId: Value(ids[w['parentUuid']]),
        packType: Value(Wire.enumOf(PackType.values, w['packType'], PackType.gear)),
        icon: Value(w['icon'] as String?),
        color: Value(w['color'] as String?),
        updatedAt: Value(w['updatedAt'] as int),
      ));
    }
  }

  Future<void> _applyItems(List<Map<String, dynamic>> incoming) async {
    final local = {for (final i in await _db.select(_db.items).get()) i.uuid: i};
    final categoryIds = await _categoryIds();
    for (final w in incoming) {
      if (!_isNewer(w, local[w['uuid']]?.updatedAt)) continue;
      final categoryId = categoryIds[w['categoryUuid']];
      var packType = Wire.enumOf<PackType?>(PackType.values, w['packType'], null);
      // Its category isn't here (deleted meanwhile): it's uncategorized now,
      // and an uncategorized item needs its own section to count in.
      if (categoryId == null) packType ??= PackType.gear;
      final row = ItemsCompanion(
        uuid: Value(w['uuid'] as String),
        name: Value(w['name'] as String),
        weightGrams: Value(w['weightGrams'] as int),
        categoryId: Value(categoryId),
        condition: Value(Wire.enumOf(ItemCondition.values, w['condition'], ItemCondition.newItem)),
        packType: Value(packType),
        quantity: Value(w['quantity'] as int),
        worn: Value(w['worn'] as bool),
        updatedAt: Value(w['updatedAt'] as int),
      );
      if (local.containsKey(w['uuid'])) {
        await (_db.update(_db.items)..where((i) => i.uuid.equals(w['uuid'] as String))).write(row);
      } else {
        await _db.into(_db.items).insert(row);
      }
    }
  }

  Future<void> _applyTrips(List<Map<String, dynamic>> incoming) async {
    final local = {for (final t in await _db.select(_db.trips).get()) t.uuid: t};
    for (final w in incoming) {
      if (!_isNewer(w, local[w['uuid']]?.updatedAt)) continue;
      final row = TripsCompanion(
        uuid: Value(w['uuid'] as String),
        name: Value(w['name'] as String),
        targetWeightGrams: Value(w['targetWeightGrams'] as int?),
        createdAt: Value(Wire.date(w['createdAtMs']) ?? DateTime.now()),
        startDate: Value(Wire.date(w['startDate'])),
        endDate: Value(Wire.date(w['endDate'])),
        isDraft: Value(w['isDraft'] as bool),
        updatedAt: Value(w['updatedAt'] as int),
      );
      if (local.containsKey(w['uuid'])) {
        await (_db.update(_db.trips)..where((t) => t.uuid.equals(w['uuid'] as String))).write(row);
      } else {
        await _db.into(_db.trips).insert(row);
      }
    }
  }

  Future<void> _applyTripItems(List<Map<String, dynamic>> incoming) async {
    final tripIds = {for (final t in await _db.select(_db.trips).get()) t.uuid: t.id};
    final itemIds = {for (final i in await _db.select(_db.items).get()) i.uuid: i.id};
    final local = {for (final r in await _db.select(_db.tripItems).get()) (r.tripId, r.itemId): r};
    for (final w in incoming) {
      final tripId = tripIds[w['tripUuid']];
      final itemId = itemIds[w['itemUuid']];
      // The trip or the item is gone here — its deletion took the list
      // entry with it.
      if (tripId == null || itemId == null) continue;
      final existing = local[(tripId, itemId)];
      if (!_isNewer(w, existing?.updatedAt)) continue;
      final row = TripItemsCompanion(
        tripId: Value(tripId),
        itemId: Value(itemId),
        quantity: Value(w['quantity'] as int?),
        inBag: Value(w['inBag'] as bool),
        updatedAt: Value(w['updatedAt'] as int),
      );
      if (existing != null) {
        await (_db.update(_db.tripItems)..where((r) => r.tripId.equals(tripId) & r.itemId.equals(itemId)))
            .write(row);
      } else {
        await _db.into(_db.tripItems).insert(row);
      }
    }
  }

  /// Deletes what was deleted elsewhere — unless it was changed here after
  /// that (then the change wins and is sent, bringing it back there too).
  /// Returns the deleted categories' sections, by local id.
  Future<Map<int, PackType>> _applyDeletions(List<_Page> pages) async {
    final newest = <String, Map<String, dynamic>>{};
    for (final d in pages.expand((p) => p.deletions)) {
      final key = '${d['entity']}:${d['key']}';
      if ((newest[key]?['deletedAt'] as int? ?? -1) < (d['deletedAt'] as int)) newest[key] = d;
    }
    final removedCategories = <int, PackType>{};
    for (final d in newest.values) {
      final key = d['key'] as String;
      final deletedAt = d['deletedAt'] as int;
      switch (d['entity']) {
        case 'categories':
          final c = await (_db.select(_db.categories)..where((c) => c.uuid.equals(key))).getSingleOrNull();
          if (c == null || c.updatedAt > deletedAt) continue;
          removedCategories[c.id] = c.packType;
          await (_db.delete(_db.categories)..where((x) => x.id.equals(c.id))).go();
        case 'items':
          final i = await (_db.select(_db.items)..where((i) => i.uuid.equals(key))).getSingleOrNull();
          if (i == null || i.updatedAt > deletedAt) continue;
          await (_db.delete(_db.tripItems)..where((r) => r.itemId.equals(i.id))).go();
          await (_db.delete(_db.items)..where((x) => x.id.equals(i.id))).go();
        case 'trips':
          final t = await (_db.select(_db.trips)..where((t) => t.uuid.equals(key))).getSingleOrNull();
          if (t == null || t.updatedAt > deletedAt) continue;
          await (_db.delete(_db.tripItems)..where((r) => r.tripId.equals(t.id))).go();
          await (_db.delete(_db.trips)..where((x) => x.id.equals(t.id))).go();
        case 'trip_items':
          final [tripUuid, itemUuid] = key.split('/');
          final trip = await (_db.select(_db.trips)..where((t) => t.uuid.equals(tripUuid))).getSingleOrNull();
          final item = await (_db.select(_db.items)..where((i) => i.uuid.equals(itemUuid))).getSingleOrNull();
          if (trip == null || item == null) continue;
          final where = _db.tripItems.tripId.equals(trip.id) & _db.tripItems.itemId.equals(item.id);
          final row = await (_db.select(_db.tripItems)..where((_) => where)).getSingleOrNull();
          if (row == null || row.updatedAt > deletedAt) continue;
          await (_db.delete(_db.tripItems)..where((_) => where)).go();
      }
    }
    return removedCategories;
  }

  /// What a deletion from elsewhere leaves behind, put right the way the
  /// app does it itself. These are ordinary edits, sent like any other.
  Future<void> _tidyAfter(Map<int, PackType> removedCategories) async {
    for (final MapEntry(key: id, value: packType) in removedCategories.entries) {
      // Its items become uncategorized but keep counting in its section.
      await (_db.update(_db.items)..where((i) => i.categoryId.equals(id)))
          .write(ItemsCompanion(categoryId: const Value(null), packType: Value(packType)));
      await (_db.update(_db.categories)..where((c) => c.parentId.equals(id)))
          .write(const CategoriesCompanion(parentId: Value(null)));
    }

    // The trip shown on Главная was deleted elsewhere: the newest one left
    // takes over, as when it's deleted here.
    final settings = await _db.select(_db.appSettings).getSingle();
    if (settings.activeTripId case final active?) {
      final exists = await (_db.select(_db.trips)..where((t) => t.id.equals(active))).getSingleOrNull();
      if (exists == null) {
        final next = await (_db.select(_db.trips)
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt), (t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingleOrNull();
        await _db.setActiveTrip(next?.id);
      }
    }
  }

  // --- Helpers ----------------------------------------------------------------

  /// Later edits win; an equal time is the same version already here.
  static bool _isNewer(Map<String, dynamic> incoming, int? localUpdatedAt) =>
      localUpdatedAt == null || (incoming['updatedAt'] as int) > localUpdatedAt;

  /// Each row once, its latest version, across all pages.
  static List<Map<String, dynamic>> _newest(
    List<_Page> pages,
    List<Map<String, dynamic>> Function(_Page) rows,
    String Function(Map<String, dynamic>) key,
  ) {
    final newest = <String, Map<String, dynamic>>{};
    for (final row in pages.expand(rows)) {
      final k = key(row);
      if ((newest[k]?['updatedAt'] as int? ?? -1) < (row['updatedAt'] as int)) newest[k] = row;
    }
    return [...newest.values];
  }

  Future<Map<String?, int>> _categoryIds() async =>
      {for (final c in await _db.select(_db.categories).get()) c.uuid: c.id};

  Future<int> _maxId<T extends Table, D>(TableInfo<T, D> table, Column<int> id) async {
    final max = id.max();
    final row = await (_db.selectOnly(table)..addColumns([max])).getSingle();
    return row.read(max) ?? 0;
  }
}

/// What one sync sends.
class _Batch {
  _Batch({required this.lastQueued, required this.lastDeleted, required this.full, required this.deletions});

  /// The last queue entry and deletion-log entry included — everything up
  /// to them is done once the server has it.
  final int? lastQueued;
  final int? lastDeleted;

  /// More was waiting than fit; another round follows.
  final bool full;

  final categories = <Map<String, Object?>>[];
  final items = <Map<String, Object?>>[];
  final trips = <Map<String, Object?>>[];
  final tripItems = <Map<String, Object?>>[];
  final List<Map<String, Object?>> deletions;
}

/// One answer from the server.
class _Page {
  _Page(Map<String, dynamic> json)
      : cursor = json['cursor'] as int,
        hasMore = json['hasMore'] as bool? ?? false,
        categories = _list(json['changes']?['categories']),
        items = _list(json['changes']?['items']),
        trips = _list(json['changes']?['trips']),
        tripItems = _list(json['changes']?['tripItems']),
        deletions = _list(json['deletions']);

  final int cursor;
  final bool hasMore;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> tripItems;
  final List<Map<String, dynamic>> deletions;

  static List<Map<String, dynamic>> _list(Object? json) =>
      json is List ? json.whereType<Map<String, dynamic>>().toList() : const [];
}
