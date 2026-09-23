/// Capitalizes just the first letter — typing "кухня" still saves as
/// "Кухня" without forcing the rest of the string to change case (acronyms,
/// intentional casing in the middle of a name, etc. survive untouched).
String capitalizeFirst(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
