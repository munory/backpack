/// Capitalizes just the first letter — typing "кухня" still saves as
/// "Кухня" without forcing the rest of the string to change case (acronyms,
/// intentional casing in the middle of a name, etc. survive untouched).
String capitalizeFirst(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

/// Russian plural forms depend on the last one/two digits, not just "1 vs
/// many" — 21 вещь, 22 вещи, 25 вещей.
String pluralizeRu(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return few;
  return many;
}

String itemWord(int n) => pluralizeRu(n, 'вещь', 'вещи', 'вещей');
String categoryWord(int n) => pluralizeRu(n, 'категория', 'категории', 'категорий');

const _monthsShort = [
  'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
  'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
];

/// A trip's dates as people write them: "12 окт", "12–14 окт",
/// "30 окт – 2 ноя", with the year only when it isn't the current one.
/// Null when there are no dates at all.
String? formatTripDates(DateTime? start, DateTime? end, {DateTime? today}) {
  if (start == null && end == null) return null;
  final now = today ?? DateTime.now();
  final from = start ?? end!;
  final to = end ?? start!;
  String day(DateTime d) {
    final base = '${d.day} ${_monthsShort[d.month - 1]}';
    return d.year != now.year ? '$base ${d.year}' : base;
  }

  if (from.year == to.year && from.month == to.month) {
    if (from.day == to.day) return day(from);
    return '${from.day}–${day(to)}';
  }
  return '${day(from)} – ${day(to)}';
}
