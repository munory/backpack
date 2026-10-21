/// Capitalizes just the first letter — typing "кухня" still saves as
/// "Кухня" without forcing the rest of the string to change case (acronyms,
/// intentional casing in the middle of a name, etc. survive untouched).
String capitalizeFirst(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

const _monthsRu = [
  'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
  'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
];
const _monthsEn = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// A trip's dates as people write them, with the year only when it isn't
/// the current one. Null when there are no dates at all.
/// Russian: "12 окт", "12–14 окт", "30 окт – 2 ноя", "5 янв 2027".
/// English (any [languageCode] but "ru"): "Oct 12", "Oct 12–14",
/// "Oct 30 – Nov 2", "Jan 5, 2027".
String? formatTripDates(
  DateTime? start,
  DateTime? end, {
  required String languageCode,
  DateTime? today,
}) {
  if (start == null && end == null) return null;
  final now = today ?? DateTime.now();
  final from = start ?? end!;
  final to = end ?? start!;
  final sameMonth = from.year == to.year && from.month == to.month;
  final sameDay = sameMonth && from.day == to.day;
  String? year(DateTime d) => d.year != now.year ? '${d.year}' : null;

  if (languageCode == 'ru') {
    String day(DateTime d) => [d.day, _monthsRu[d.month - 1], ?year(d)].join(' ');
    if (sameDay) return day(from);
    if (sameMonth) return '${from.day}–${day(to)}';
    return '${day(from)} – ${day(to)}';
  }

  String withYear(String s, DateTime d) => year(d) == null ? s : '$s, ${year(d)}';
  String day(DateTime d) => withYear('${_monthsEn[d.month - 1]} ${d.day}', d);
  if (sameDay) return day(from);
  if (sameMonth) return withYear('${_monthsEn[from.month - 1]} ${from.day}–${to.day}', to);
  return '${day(from)} – ${day(to)}';
}
