import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// Which section of the dashboard a category's weight is counted under.
enum PackType { food, gear, water }

/// Rough condition of a gear item, set when adding it.
enum ItemCondition { newItem, needsReplacement, wornOut }

/// Display labels for [ItemCondition] — the single source of truth so the
/// add/edit form and the item list always agree on wording.
const conditionLabels = {
  ItemCondition.newItem: 'Готово к походу',
  ItemCondition.wornOut: 'Требует ремонта',
  ItemCondition.needsReplacement: 'Под замену',
};

/// Display labels for [PackType] — used to tag an uncategorized item with
/// its section inline, since it has no category name to show instead.
const packTypeLabels = {
  PackType.food: 'Еда',
  PackType.gear: 'Снаряжение',
  PackType.water: 'Вода',
};

/// The master, trip-independent organizational tree (e.g. Sleep System >
/// Base layers). Shared across every trip.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get parentId =>
      integer().nullable().references(Categories, #id)();

  /// Denormalized on every row (inherited from the root category at creation
  /// time) so dashboard totals can be a plain GROUP BY instead of a
  /// recursive tree walk.
  IntColumn get packType =>
      intEnum<PackType>()();

  /// Key into `categoryIconOptions`/`categoryColorOptions` (lib/common/
  /// category_style.dart) — null means "use the old per-section default",
  /// so existing categories don't suddenly need a choice made for them.
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
}

/// The master gear closet — every item the user owns, regardless of which
/// trip(s) it has been packed for.
class Items extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get weightGrams => integer()();

  /// Optional — an item can be saved before you've figured out (or created)
  /// a category for it. Organize it later; it still counts toward the
  /// total in the meantime via [packType] below.
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get condition => intEnum<ItemCondition>()();

  /// Only meaningful when [categoryId] is null — an uncategorized item
  /// still needs to know whether it's Food/Gear/Water to count correctly.
  /// Once it has a category, the category's packType wins instead.
  IntColumn get packType => intEnum<PackType>().nullable()();

  /// How many identical units this row represents (5 tent stakes, 3 spare
  /// batteries) — [weightGrams] is the weight of ONE, multiplied by this
  /// everywhere weight gets totaled. An alternative to duplicating the item
  /// N times for something you own several identical copies of.
  IntColumn get quantity => integer().withDefault(const Constant(1))();
}

/// A single trip/hike — or, before the user has bothered to name one, just
/// "the pack currently being put together". Target weight is optional and
/// set explicitly by the user whenever they choose to — never defaulted.
class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get targetWeightGrams => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Which items from the master closet are packed for a given trip.
class TripItems extends Table {
  IntColumn get tripId => integer().references(Trips, #id)();
  IntColumn get itemId => integer().references(Items, #id)();

  @override
  Set<Column> get primaryKey => {tripId, itemId};
}

/// Single-row table holding app-wide state, currently just which trip is
/// the active one shown on the dashboard.
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get activeTripId =>
      integer().nullable().references(Trips, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Categories, Items, Trips, TripItems, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(appSettings).insert(const AppSettingsCompanion());
          await _seedDefaultCategories();
        },
        // Dev-only project, no real user data to preserve yet: wipe and
        // recreate on any schema bump instead of writing real migrations.
        onUpgrade: (m, from, to) async {
          for (final table in allTables) {
            await m.deleteTable(table.actualTableName);
          }
          await m.createAll();
          await into(appSettings).insert(const AppSettingsCompanion());
          await _seedDefaultCategories();
        },
      );

  /// A starter closet structure so a brand-new user isn't staring at a
  /// totally empty app — every one of these is a perfectly ordinary,
  /// renameable/deletable category. "Рюкзаки" is just like any other —
  /// a backpack is simply a piece of gear, same as a stove or a jacket.
  Future<void> _seedDefaultCategories() async {
    const starters = [
      ('Рюкзаки', PackType.gear, 'backpack', 'terracotta'),
      ('Спальная система', PackType.gear, 'sleep', 'plum'),
      ('Кухня', PackType.gear, 'kitchen', 'mustard'),
      ('Одежда', PackType.gear, 'clothing', 'sage'),
      ('Еда', PackType.food, 'food', 'terracotta'),
      ('Вода', PackType.water, 'water', 'teal'),
    ];
    for (final (name, packType, icon, color) in starters) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: name,
          packType: packType,
          icon: Value(icon),
          color: Value(color),
        ),
      );
    }
  }

  Future<Trip?> activeTrip() async {
    final settings = await select(appSettings).getSingle();
    if (settings.activeTripId == null) return null;
    return (select(trips)..where((t) => t.id.equals(settings.activeTripId!)))
        .getSingleOrNull();
  }

  Future<int> createTrip(String name, int? targetWeightGrams) async {
    final tripId = await into(trips).insert(
      TripsCompanion.insert(
        name: name,
        targetWeightGrams: Value(targetWeightGrams),
      ),
    );
    await update(appSettings).write(
      AppSettingsCompanion(activeTripId: Value(tripId)),
    );
    return tripId;
  }

  /// Returns the active trip, silently creating an unnamed/untargeted one
  /// first if none exists yet — so packing gear never requires filling out
  /// a form first.
  Future<int> ensureActiveTrip() async {
    final settings = await select(appSettings).getSingle();
    if (settings.activeTripId != null) return settings.activeTripId!;
    return createTrip('Мои сборы', null);
  }

  /// Adds or removes an item from the active trip's pack (creating the
  /// active trip on first use, per [ensureActiveTrip]). A backpack is just
  /// gear — no special casing here for it or any other category.
  Future<void> setItemPacked(int itemId, bool packed) async {
    final tripId = await ensureActiveTrip();
    if (packed) {
      await into(tripItems).insert(
        TripItemsCompanion.insert(tripId: tripId, itemId: itemId),
        mode: InsertMode.insertOrIgnore,
      );
    } else {
      await (delete(tripItems)
            ..where((t) => t.tripId.equals(tripId) & t.itemId.equals(itemId)))
          .go();
    }
  }

  Future<void> updateTripTarget(int tripId, int? targetWeightGrams) {
    return (update(trips)..where((t) => t.id.equals(tripId))).write(
      TripsCompanion(targetWeightGrams: Value(targetWeightGrams)),
    );
  }

  /// Adds an item to the master gear closet. Not tied to any trip — packing
  /// it for a specific trip is a separate, later action. [categoryId] is
  /// optional; when omitted, [packType] is what makes it count correctly.
  Future<int> addItem({
    required String name,
    required int weightGrams,
    int? categoryId,
    required ItemCondition condition,
    PackType? packType,
    int quantity = 1,
  }) {
    return into(items).insert(
      ItemsCompanion.insert(
        name: name,
        weightGrams: weightGrams,
        categoryId: Value(categoryId),
        condition: condition,
        packType: Value(packType),
        quantity: Value(quantity),
      ),
    );
  }

  Future<void> updateItem({
    required int id,
    required String name,
    required int weightGrams,
    int? categoryId,
    required ItemCondition condition,
    PackType? packType,
    int quantity = 1,
  }) {
    return (update(items)..where((i) => i.id.equals(id))).write(
      ItemsCompanion(
        name: Value(name),
        weightGrams: Value(weightGrams),
        categoryId: Value(categoryId),
        condition: Value(condition),
        packType: Value(packType),
        quantity: Value(quantity),
      ),
    );
  }

  /// Copies an item as a new, separate closet entry — starts unpacked even
  /// if the original is currently packed, so weight doesn't silently double
  /// on the active trip. Returns the new row itself (not just its id): a
  /// duplicate is almost always made because the copy needs to end up
  /// *slightly* different from the original (a second thermos in a
  /// different color, a spare with different wear) — an exact copy has
  /// quantity for that instead — so callers open it straight into editing.
  Future<Item> duplicateItem(Item item) async {
    // Strip any "(копия)"/"(копия N)" the source already carries before
    // adding a new one — otherwise duplicating a duplicate piles up into
    // "(копия) (копия)". Numbered from how many copies of this same base
    // name already exist, so a second duplicate reads "(копия 2)" instead
    // of a second identical "(копия)".
    final baseName = _stripCopySuffix(item.name);
    final copyPattern = RegExp('^${RegExp.escape(baseName)} \\(копия(?: (\\d+))?\\)\$');
    final siblings = await select(items).get();
    var highestCopyNumber = 0;
    for (final sibling in siblings) {
      final match = copyPattern.firstMatch(sibling.name);
      if (match == null) continue;
      final number = match.group(1) == null ? 1 : int.parse(match.group(1)!);
      if (number > highestCopyNumber) highestCopyNumber = number;
    }
    final nextCopyNumber = highestCopyNumber + 1;
    final newName = nextCopyNumber == 1 ? '$baseName (копия)' : '$baseName (копия $nextCopyNumber)';

    final id = await into(items).insert(
      ItemsCompanion.insert(
        name: newName,
        weightGrams: item.weightGrams,
        categoryId: Value(item.categoryId),
        condition: item.condition,
        packType: Value(item.packType),
        quantity: Value(item.quantity),
      ),
    );
    return (select(items)..where((i) => i.id.equals(id))).getSingle();
  }

  /// Deletes an item from the closet entirely, unpacking it from every trip
  /// it was part of first (there's no cascade at the schema level).
  Future<void> deleteItem(int id) async {
    await (delete(tripItems)..where((t) => t.itemId.equals(id))).go();
    await (delete(items)..where((i) => i.id.equals(id))).go();
  }

  Future<void> updateCategory({
    required int id,
    required String name,
    required int? parentId,
    required PackType packType,
    String? icon,
    String? color,
  }) {
    return (update(categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(name),
        parentId: Value(parentId),
        packType: Value(packType),
        icon: Value(icon),
        color: Value(color),
      ),
    );
  }

  /// Deletes a category. Refuses (returns false, nothing changed) if it has
  /// subcategories — move or delete those first, rather than silently
  /// cascading a whole subtree. Items directly in it aren't deleted: they
  /// fall back to uncategorized, keeping the deleted category's packType so
  /// they still count in the right section.
  Future<bool> deleteCategory(int id) async {
    final hasChildren =
        await (select(categories)..where((c) => c.parentId.equals(id))).get();
    if (hasChildren.isNotEmpty) return false;

    final category = await (select(categories)..where((c) => c.id.equals(id))).getSingle();
    await (update(items)..where((i) => i.categoryId.equals(id))).write(
      ItemsCompanion(categoryId: const Value(null), packType: Value(category.packType)),
    );
    await (delete(categories)..where((c) => c.id.equals(id))).go();
    return true;
  }
}

/// Removes a trailing "(копия)"/"(копия N)" from a name — repeatedly, so a
/// name that already carries more than one (from before this was fixed)
/// still resolves back to its real base name in one pass.
String _stripCopySuffix(String name) {
  final pattern = RegExp(r'\s*\(копия(?: \d+)?\)$');
  var result = name;
  while (pattern.hasMatch(result)) {
    result = result.replaceFirst(pattern, '');
  }
  return result;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'backpack.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
