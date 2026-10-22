import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// All categories, live-updating whenever the table changes.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});

/// Every item in the master gear closet, regardless of trip.
final allItemsProvider = StreamProvider<List<Item>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.items).watch();
});

/// The app-wide settings row (currently just which trip is active).
final appSettingsProvider = StreamProvider<AppSetting>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.appSettings).watchSingle();
});

/// The currently active trip, or null if none is selected yet.
final activeTripProvider = StreamProvider<Trip?>((ref) {
  final db = ref.watch(databaseProvider);
  final settingsAsync = ref.watch(appSettingsProvider);
  final tripId = settingsAsync.value?.activeTripId;
  if (tripId == null) return Stream.value(null);
  return (db.select(db.trips)..where((t) => t.id.equals(tripId)))
      .watchSingleOrNull();
});

/// Every trip, newest first.
final tripsProvider = StreamProvider<List<Trip>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.trips)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt), (t) => OrderingTerm.desc(t.id)]))
      .watch();
});

/// How many of [item]'s owned units a trip takes — the trip's own number if
/// it set one, else all of them, and never more than are actually owned
/// (the closet quantity may have been lowered since).
int tripQuantity(TripItem row, Item item) {
  final wanted = row.quantity ?? item.quantity;
  return wanted > item.quantity ? item.quantity : wanted;
}

/// Items belonging to the active trip, live-updating — each with its
/// `quantity` replaced by how many go on *this* trip, so every weight total
/// and "(N шт.)" label downstream reflects the trip without knowing about
/// it. Not the closet row: anything that edits or copies the item itself
/// must look it up in [allItemsProvider] by id instead.
final activeTripItemsProvider = StreamProvider<List<Item>>((ref) {
  final db = ref.watch(databaseProvider);
  final trip = ref.watch(activeTripProvider).value;
  if (trip == null) return Stream.value(const []);
  final query = db.select(db.items).join([
    innerJoin(db.tripItems, db.tripItems.itemId.equalsExp(db.items.id)),
  ])
    ..where(db.tripItems.tripId.equals(trip.id));
  return query.watch().map((rows) => [
        for (final r in rows)
          r.readTable(db.items).copyWith(
                quantity: tripQuantity(r.readTable(db.tripItems), r.readTable(db.items)),
              ),
      ]);
});

/// The active trip's list rows (per-trip quantity, in-bag state), keyed by
/// item id.
final activeTripRowsProvider = StreamProvider<Map<int, TripItem>>((ref) {
  final db = ref.watch(databaseProvider);
  final trip = ref.watch(activeTripProvider).value;
  if (trip == null) return Stream.value(const {});
  return (db.select(db.tripItems)..where((t) => t.tripId.equals(trip.id)))
      .watch()
      .map((rows) => {for (final r in rows) r.itemId: r});
});

/// Per-trip weight and item count for the trips list, from one join over
/// every trip's list. The weight is the pack's — worn items count as items
/// but not toward the weight compared with the trip's target.
typedef TripSummary = ({int grams, int itemCount});

final tripSummariesProvider = StreamProvider<Map<int, TripSummary>>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.tripItems).join([
    innerJoin(db.items, db.items.id.equalsExp(db.tripItems.itemId)),
  ]);
  return query.watch().map((rows) {
    final grams = <int, int>{};
    final counts = <int, int>{};
    for (final r in rows) {
      final row = r.readTable(db.tripItems);
      final item = r.readTable(db.items);
      grams[row.tripId] = (grams[row.tripId] ?? 0) +
          (item.worn ? 0 : item.weightGrams * tripQuantity(row, item));
      counts[row.tripId] = (counts[row.tripId] ?? 0) + 1;
    }
    return {
      for (final id in grams.keys) id: (grams: grams[id]!, itemCount: counts[id]!),
    };
  });
});

/// An item's contribution to any weight total — its per-unit weight times
/// how many identical units it represents.
int itemTotalGrams(Item item) => item.weightGrams * item.quantity;

int _totalWeight(List<Item> items) =>
    items.fold<int>(0, (sum, item) => sum + itemTotalGrams(item));

/// An item's pack type: its category's, if it has one, else whatever it
/// declared for itself (an uncategorized item still needs to count
/// somewhere), falling back to gear if somehow neither is set. Public
/// because the gear list's section filter needs the same resolution the
/// weight totals use.
PackType effectivePackType(Item item, Map<int, Category> categoryById) {
  final category = item.categoryId == null ? null : categoryById[item.categoryId];
  return category?.packType ?? item.packType ?? PackType.gear;
}

Map<PackType, int> _weightByPackType(List<Item> items, List<Category> categories) {
  final categoryById = {for (final c in categories) c.id: c};
  final totals = {for (final t in PackType.values) t: 0};
  for (final item in items) {
    final type = effectivePackType(item, categoryById);
    totals[type] = totals[type]! + itemTotalGrams(item);
  }
  return totals;
}

/// One card's worth of items — either a real category, or the single
/// catch-all "Неразобранное" bucket for every uncategorized item (when
/// [category] is null; [packType] is meaningless in that case). [title] is
/// null for that bucket too — its name comes from the current language.
typedef CategoryGroup = ({Category? category, String? title, PackType packType, int weightGrams});

List<CategoryGroup> _rootCategoryTotals(List<Category> categories, List<Item> items) {
  final childrenOf = <int?, List<Category>>{};
  for (final c in categories) {
    childrenOf.putIfAbsent(c.parentId, () => []).add(c);
  }

  int weightForSubtree(int categoryId) {
    var total = 0;
    for (final item in items) {
      if (item.categoryId == categoryId) total += itemTotalGrams(item);
    }
    for (final child in childrenOf[categoryId] ?? const <Category>[]) {
      total += weightForSubtree(child.id);
    }
    return total;
  }

  final roots = childrenOf[null] ?? const <Category>[];
  final List<CategoryGroup> groups = [
    for (final root in roots)
      (category: root, title: root.name, packType: root.packType, weightGrams: weightForSubtree(root.id)),
  ];

  // Items without a category all fall into one catch-all card instead of a
  // per-section one — it's not a real category (no rename, no add-item-into
  // -it), just a "still needs sorting" pile, and one consistently-named
  // card reads as that; each item tags its own section inline instead.
  var uncategorizedTotal = 0;
  for (final item in items) {
    if (item.categoryId != null) continue;
    uncategorizedTotal += itemTotalGrams(item);
  }
  if (uncategorizedTotal > 0) {
    groups.add((
      category: null,
      title: null,
      packType: PackType.gear,
      weightGrams: uncategorizedTotal,
    ));
  }

  return groups;
}

// --- Active-trip-scoped (Dashboard) ---

/// The pack's weight for the active trip, in grams — everything on the
/// list except what's worn, which isn't in the pack at all (see
/// [wornWeightProvider]). This is what a trip's target is measured against.
final totalWeightProvider = Provider<int>((ref) {
  final items = ref.watch(activeTripItemsProvider).value ?? <Item>[];
  return _totalWeight(items.where((i) => !i.worn).toList());
});

/// What's worn on the active trip (boots, the shell you hike in), in grams.
final wornWeightProvider = Provider<int>((ref) {
  final items = ref.watch(activeTripItemsProvider).value ?? <Item>[];
  return _totalWeight(items.where((i) => i.worn).toList());
});

/// The pack's weight grouped by Food / Gear / Water, for the active trip —
/// worn items left out, so the three add up to [totalWeightProvider].
final weightByPackTypeProvider = Provider<Map<PackType, int>>((ref) {
  final items = ref.watch(activeTripItemsProvider).value ?? <Item>[];
  final categories = ref.watch(categoriesProvider).value ?? <Category>[];
  return _weightByPackType(items.where((i) => !i.worn).toList(), categories);
});

/// Root categories with the combined weight of every item — belonging to
/// the active trip — in them or any nested subcategory.
final rootCategoryTotalsProvider = Provider<List<CategoryGroup>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? <Category>[];
  final items = ref.watch(activeTripItemsProvider).value ?? <Item>[];
  return _rootCategoryTotals(categories, items);
});

/// IDs of items currently packed in the active trip — used by the Gear list
/// screen to render "packed" checkboxes.
final activeTripItemIdsProvider = Provider<Set<int>>((ref) {
  final items = ref.watch(activeTripItemsProvider).value ?? <Item>[];
  return items.map((i) => i.id).toSet();
});

// --- Whole-closet (Gear list) ---

/// Total weight of everything owned, regardless of trip.
final closetTotalWeightProvider = Provider<int>((ref) {
  return _totalWeight(ref.watch(allItemsProvider).value ?? <Item>[]);
});

/// Weight in grams grouped by Food / Gear / Water, for the whole closet.
final closetWeightByPackTypeProvider = Provider<Map<PackType, int>>((ref) {
  final items = ref.watch(allItemsProvider).value ?? <Item>[];
  final categories = ref.watch(categoriesProvider).value ?? <Category>[];
  return _weightByPackType(items, categories);
});

/// Root categories with the combined weight of every owned item in them or
/// any nested subcategory — the whole closet, not scoped to a trip.
final closetRootCategoryTotalsProvider = Provider<List<CategoryGroup>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? <Category>[];
  final items = ref.watch(allItemsProvider).value ?? <Item>[];
  return _rootCategoryTotals(categories, items);
});
