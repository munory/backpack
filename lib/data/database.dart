import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';

part 'database.g.dart';

/// Which section of the dashboard a category's weight is counted under.
enum PackType { food, gear, water }

/// Rough condition of a gear item, set when adding it.
enum ItemCondition { newItem, needsReplacement, wornOut }

/// The app's own light/dark preference — independent of the system
/// setting, since someone may want this app dark while the rest of their
/// phone stays light (or vice versa). [system] defers to the phone.
enum AppThemeMode { system, light, dark }

/// The app's own language — [system] follows the phone.
enum AppLanguage { system, ru, en }

/// How weights are shown and typed in — always stored in grams regardless.
enum WeightUnit { metric, imperial }

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

  /// Both optional — a trip can be planned before dates are known. A trip
  /// whose [endDate] has passed is shown in the "Архив" group.
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();

  /// The scratch list for sizing up gear without a planned trip — created
  /// automatically the first time something is ticked in Инвентарь with no
  /// trip yet. Can later be turned into a real trip ("Превратить в поход").
  BoolColumn get isDraft => boolean().withDefault(const Constant(false))();
}

/// Which items from the master closet are packed for a given trip.
class TripItems extends Table {
  IntColumn get tripId => integer().references(Trips, #id)();
  IntColumn get itemId => integer().references(Items, #id)();

  /// How many of the item's owned units go on this trip (5 gas cans owned,
  /// 2 taken). Null means "all of them" — so raising the item's own
  /// quantity later carries through without touching every trip.
  IntColumn get quantity => integer().nullable()();

  /// Physically put in the bag while packing — a separate state from being
  /// on the trip's list at all (planning vs. the night-before packing run).
  BoolColumn get inBag => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {tripId, itemId};
}

/// Single-row table holding app-wide state: which trip is the active one
/// shown on the dashboard, and the user's own light/dark preference.
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get activeTripId =>
      integer().nullable().references(Trips, #id)();
  IntColumn get themeMode =>
      intEnum<AppThemeMode>().withDefault(const Constant(0))();
  IntColumn get language =>
      intEnum<AppLanguage>().withDefault(const Constant(0))();

  /// Null until picked in Профиль — then the language decides (kilograms
  /// for Russian, pounds for English).
  IntColumn get weightUnit => intEnum<WeightUnit>().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Categories, Items, Trips, TripItems, AppSettings])
class AppDatabase extends _$AppDatabase {
  /// [seedLanguage] names the starter categories on a brand-new install —
  /// the phone's language, since nobody has picked one in the app yet.
  AppDatabase({this.seedLanguage = 'en'}) : super(_openConnection());

  /// For tests only — takes an executor directly (an in-memory database)
  /// instead of opening the real file on disk via [_openConnection].
  AppDatabase.forTesting(super.executor, {this.seedLanguage = 'ru'});

  final String seedLanguage;

  @override
  int get schemaVersion => 18;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(appSettings).insert(const AppSettingsCompanion());
          await _seedDefaultCategories();
        },
        onUpgrade: (m, from, to) async {
          if (from < 13) {
            // Nothing below schema 13 was ever a real install — only test
            // data on dev emulators — so this old dev-only path (wipe +
            // recreate + reseed) stays as a safety net for it. Every real
            // migration from here on must be additive; see below.
            for (final table in allTables) {
              await m.deleteTable(table.actualTableName);
            }
            await m.createAll();
            await into(appSettings).insert(const AppSettingsCompanion());
            await _seedDefaultCategories();
            return;
          }

          // from >= 13: real installs may exist — never wipe. Add one
          // `if (from < N) ...` step per schema bump from here on, each
          // doing only the additive change that version introduced (new
          // column/table/etc.), and nothing here may re-seed defaults or
          // re-insert the AppSettings row — both already exist for a real
          // install.
          if (from < 14) {
            await m.addColumn(appSettings, appSettings.themeMode);
          }
          if (from < 15) {
            await m.addColumn(trips, trips.startDate);
            await m.addColumn(trips, trips.endDate);
            await m.addColumn(tripItems, tripItems.quantity);
            await m.addColumn(tripItems, tripItems.inBag);
          }
          if (from < 16) {
            await m.addColumn(trips, trips.isDraft);
            // The old auto-created list was named "Мои сборы" — it is
            // exactly what a draft is now, so it becomes one.
            await (update(trips)..where((t) => t.name.equals('Мои сборы'))).write(
              const TripsCompanion(isDraft: Value(true), name: Value('Черновик')),
            );
          }
          if (from < 17) {
            await m.addColumn(appSettings, appSettings.language);
          }
          if (from < 18) {
            await m.addColumn(appSettings, appSettings.weightUnit);
          }
        },
      );

  /// A starter closet structure so a brand-new user isn't staring at a
  /// totally empty app — every one of these is a perfectly ordinary,
  /// renameable/deletable category. "Рюкзаки" is just like any other —
  /// a backpack is simply a piece of gear, same as a stove or a jacket.
  Future<void> _seedDefaultCategories([String? language]) async {
    final code = language ?? seedLanguage;
    final l = lookupAppLocalizations(Locale(code == 'ru' ? 'ru' : 'en'));
    final starters = [
      (l.seedPacks, PackType.gear, 'backpack', 'terracotta'),
      (l.seedSleep, PackType.gear, 'sleep', 'plum'),
      (l.seedKitchen, PackType.gear, 'kitchen', 'mustard'),
      (l.seedClothing, PackType.gear, 'clothing', 'sage'),
      (l.packFood, PackType.food, 'food', 'terracotta'),
      (l.packWater, PackType.water, 'water', 'teal'),
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

  /// Creates a trip and makes it the active one. With [copyFromTripId], the
  /// new trip starts with that trip's whole list (and per-trip quantities) —
  /// most trips reuse most of the last one's gear — but nothing is marked
  /// as already in the bag.
  Future<int> createTrip({
    required String name,
    int? targetWeightGrams,
    DateTime? startDate,
    DateTime? endDate,
    int? copyFromTripId,
    bool isDraft = false,
  }) {
    return transaction(() async {
      final tripId = await into(trips).insert(
        TripsCompanion.insert(
          name: name,
          targetWeightGrams: Value(targetWeightGrams),
          startDate: Value(startDate),
          endDate: Value(endDate),
          isDraft: Value(isDraft),
        ),
      );
      if (copyFromTripId != null) {
        final rows = await (select(tripItems)
              ..where((t) => t.tripId.equals(copyFromTripId)))
            .get();
        for (final row in rows) {
          await into(tripItems).insert(
            TripItemsCompanion.insert(
              tripId: tripId,
              itemId: row.itemId,
              quantity: Value(row.quantity),
            ),
          );
        }
      }
      await setActiveTrip(tripId);
      return tripId;
    });
  }

  Future<void> updateTrip({
    required int id,
    required String name,
    int? targetWeightGrams,
    DateTime? startDate,
    DateTime? endDate,
    bool? isDraft,
  }) {
    return (update(trips)..where((t) => t.id.equals(id))).write(
      TripsCompanion(
        name: Value(name),
        targetWeightGrams: Value(targetWeightGrams),
        startDate: Value(startDate),
        endDate: Value(endDate),
        // Passing false is "Превратить в поход"; null leaves it as is.
        isDraft: isDraft == null ? const Value.absent() : Value(isDraft),
      ),
    );
  }

  /// A copy of [trip] with the same list, named "X (копия)"/"(копия N)" the
  /// same way duplicated items are. Becomes the active trip.
  Future<int> duplicateTrip(Trip trip, {String copyWord = 'копия'}) async {
    final all = await select(trips).get();
    return createTrip(
      name: _nextCopyName(trip.name, all.map((t) => t.name), copyWord),
      targetWeightGrams: trip.targetWeightGrams,
      startDate: trip.startDate,
      endDate: trip.endDate,
      copyFromTripId: trip.id,
    );
  }

  /// Deletes a trip and its list. If it was the active one, the most
  /// recently created remaining trip takes over (or none, if it was last).
  Future<void> deleteTrip(int id) {
    return transaction(() async {
      await (delete(tripItems)..where((t) => t.tripId.equals(id))).go();
      await (delete(trips)..where((t) => t.id.equals(id))).go();
      final settings = await select(appSettings).getSingle();
      if (settings.activeTripId == id) {
        final next = await (select(trips)
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt), (t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingleOrNull();
        await setActiveTrip(next?.id);
      }
    });
  }

  Future<void> setActiveTrip(int? tripId) {
    return update(appSettings).write(AppSettingsCompanion(activeTripId: Value(tripId)));
  }

  /// [quantity] null means "all owned units".
  Future<void> setTripItemQuantity(int tripId, int itemId, int? quantity) {
    return (update(tripItems)
          ..where((t) => t.tripId.equals(tripId) & t.itemId.equals(itemId)))
        .write(TripItemsCompanion(quantity: Value(quantity)));
  }

  Future<void> setInBag(int tripId, int itemId, bool inBag) {
    return (update(tripItems)
          ..where((t) => t.tripId.equals(tripId) & t.itemId.equals(itemId)))
        .write(TripItemsCompanion(inBag: Value(inBag)));
  }

  /// "Начать заново" in packing mode — unchecks everything, keeps the list.
  Future<void> resetInBag(int tripId) {
    return (update(tripItems)..where((t) => t.tripId.equals(tripId)))
        .write(const TripItemsCompanion(inBag: Value(false)));
  }

  /// Returns the active trip, silently creating an unnamed/untargeted one
  /// first if none exists yet — so packing gear never requires filling out
  /// a form first.
  Future<int> ensureActiveTrip() async {
    final settings = await select(appSettings).getSingle();
    if (settings.activeTripId != null) return settings.activeTripId!;
    return createTrip(name: 'Черновик', isDraft: true);
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

  Future<void> updateThemeMode(AppThemeMode mode) {
    return update(appSettings).write(AppSettingsCompanion(themeMode: Value(mode)));
  }

  Future<void> updateLanguage(AppLanguage language) {
    return update(appSettings).write(AppSettingsCompanion(language: Value(language)));
  }

  /// "Очистить все данные": every item, category and trip goes, and the app
  /// is back to a fresh install — starter categories in [language] — while
  /// the user's own settings (theme, language, units) stay.
  Future<void> clearAllData({required String language}) {
    return transaction(() async {
      await setActiveTrip(null);
      await delete(tripItems).go();
      await delete(trips).go();
      await delete(items).go();
      await delete(categories).go();
      await _seedDefaultCategories(language);
    });
  }

  Future<void> updateWeightUnit(WeightUnit unit) {
    return update(appSettings).write(AppSettingsCompanion(weightUnit: Value(unit)));
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
  Future<Item> duplicateItem(Item item, {String copyWord = 'копия'}) async {
    final siblings = await select(items).get();
    final newName = _nextCopyName(item.name, siblings.map((s) => s.name), copyWord);

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
/// The name for a new copy of [name]: "X (копия)", then "X (копия 2)", and
/// so on, numbered past every copy of the same base name in [existing].
/// Strips a "(копия N)" the source already carries first, so copying a
/// copy doesn't pile up into "(копия) (копия)". Shared by items and trips.
/// [copyWord] is the current language's "копия"/"copy".
String _nextCopyName(String name, Iterable<String> existing, String copyWord) {
  final baseName = _stripCopySuffix(name);
  final copyPattern = RegExp(
    '^${RegExp.escape(baseName)} \\(${RegExp.escape(copyWord)}(?: (\\d+))?\\)\$',
  );
  var highest = 0;
  for (final other in existing) {
    final match = copyPattern.firstMatch(other);
    if (match == null) continue;
    final number = match.group(1) == null ? 1 : int.parse(match.group(1)!);
    if (number > highest) highest = number;
  }
  final next = highest + 1;
  return next == 1 ? '$baseName ($copyWord)' : '$baseName ($copyWord $next)';
}

/// Either language's suffix — a copy made in Russian is still a copy after
/// switching to English.
String _stripCopySuffix(String name) {
  final pattern = RegExp(r'\s*\((?:копия|copy)(?: \d+)?\)$');
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
