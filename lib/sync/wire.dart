import '../data/database.dart';

/// How the phone's rows travel in POST /sync — the same shapes as the
/// server's `src/sync/wire.ts`. References between rows go as uuids: the
/// local integer ids mean nothing on another device. Times are ms since the
/// epoch, enums their index.
///
/// Values are kept inside the server's limits on the way out: one row the
/// server refused would make the whole request fail, every time.
abstract final class Wire {
  static Map<String, Object?> category(Category c, Map<int, String> categoryUuids) => {
        'uuid': c.uuid,
        'name': _name(c.name),
        'parentUuid': c.parentId == null ? null : categoryUuids[c.parentId],
        'packType': c.packType.index,
        'icon': _short(c.icon),
        'color': _short(c.color),
        'updatedAt': c.updatedAt,
      };

  static Map<String, Object?> item(Item i, Map<int, String> categoryUuids) => {
        'uuid': i.uuid,
        'name': _name(i.name),
        'weightGrams': _grams(i.weightGrams),
        'categoryUuid': i.categoryId == null ? null : categoryUuids[i.categoryId],
        'condition': i.condition.index,
        'packType': i.packType?.index,
        'quantity': _count(i.quantity),
        'worn': i.worn,
        'updatedAt': i.updatedAt,
      };

  static Map<String, Object?> trip(Trip t) => {
        'uuid': t.uuid,
        'name': _name(t.name),
        'targetWeightGrams': t.targetWeightGrams == null ? null : _grams(t.targetWeightGrams!),
        'createdAtMs': _ms(t.createdAt),
        'startDate': t.startDate == null ? null : _ms(t.startDate!),
        'endDate': t.endDate == null ? null : _ms(t.endDate!),
        'isDraft': t.isDraft,
        'updatedAt': t.updatedAt,
      };

  static Map<String, Object?> tripItem(TripItem r, String tripUuid, String itemUuid) => {
        'tripUuid': tripUuid,
        'itemUuid': itemUuid,
        'quantity': r.quantity == null ? null : _count(r.quantity!),
        'inBag': r.inBag,
        'updatedAt': r.updatedAt,
      };

  /// An enum from its index; [fallback] if this app version doesn't know it.
  static T enumOf<T>(List<T> values, Object? index, T fallback) =>
      index is int && index >= 0 && index < values.length ? values[index] : fallback;

  static DateTime? date(Object? ms) => ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;

  static int _ms(DateTime d) => d.millisecondsSinceEpoch < 0 ? 0 : d.millisecondsSinceEpoch;
  static String _name(String s) => s.length > 500 ? s.substring(0, 500) : s;
  static String? _short(String? s) => s == null || s.length <= 50 ? s : s.substring(0, 50);
  static int _grams(int g) => g.clamp(0, 1000000000);
  static int _count(int n) => n.clamp(1, 100000);
}
