import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:excel/excel.dart' as xl;
import 'package:flutter/widgets.dart' show Locale;

import '../../common/l10n.dart';
import '../../common/weight_format.dart';
import '../../data/database.dart';

// ---------------------------------------------------------------------------
// Reading a file into a plain table
// ---------------------------------------------------------------------------

/// A spreadsheet reduced to text: the first non-empty row as headers, the
/// rest as rows. Every row is padded to the header width.
class ImportTable {
  ImportTable(this.headers, List<List<String>> rows)
      : rows = [
          for (final r in rows)
            if (r.any((c) => c.trim().isNotEmpty))
              [...r, for (var i = r.length; i < headers.length; i++) ''],
        ];

  final List<String> headers;
  final List<List<String>> rows;
}

/// Reads a .csv or .xlsx file. Throws [FormatException] for anything else
/// or a file with no rows at all.
ImportTable readImportTable(List<int> bytes, String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.xlsx')) return _readXlsx(bytes);
  if (lower.endsWith('.csv') || lower.endsWith('.txt')) {
    return parseCsv(utf8.decode(bytes, allowMalformed: true));
  }
  throw const FormatException('unsupported');
}

ImportTable _readXlsx(List<int> bytes) {
  final book = xl.Excel.decodeBytes(bytes);
  for (final sheet in book.tables.values) {
    final rows = [
      for (final row in sheet.rows) [for (final cell in row) _cellText(cell?.value)],
    ].where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
    if (rows.isNotEmpty) return ImportTable(rows.first, rows.skip(1).toList());
  }
  throw const FormatException('empty');
}

String _cellText(xl.CellValue? value) => switch (value) {
      null => '',
      xl.IntCellValue(:final value) => '$value',
      // Excel stores 120 as 120.0 — drop the needless ".0".
      xl.DoubleCellValue(:final value) =>
        value == value.roundToDouble() ? '${value.round()}' : '$value',
      _ => value.toString(),
    };

/// Parses CSV text: quoted fields with doubled quotes and line breaks
/// inside, a leading byte-order mark, and whichever separator the header
/// line uses — comma, or the semicolon Excel with Russian settings saves
/// with, or a tab.
ImportTable parseCsv(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final separator = _detectSeparator(text);

  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == separator) {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = [];
    } else {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  final nonEmpty = rows.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
  if (nonEmpty.isEmpty) throw const FormatException('empty');
  return ImportTable(nonEmpty.first, nonEmpty.skip(1).toList());
}

/// Semicolon or tab if one appears the same number of times in each of the
/// first lines — checked before the comma, because in a Russian sheet a
/// comma is as likely the decimal mark ("1,5") as a separator. Otherwise
/// whichever is most common in the header, comma by default.
String _detectSeparator(String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .where((l) => l.trim().isNotEmpty)
      .take(5)
      .toList();
  if (lines.isEmpty) return ',';
  for (final candidate in [';', '\t']) {
    final counts = lines.map((l) => _countOutsideQuotes(l, candidate)).toSet();
    if (counts.length == 1 && counts.first > 0) return candidate;
  }
  return [',', ';', '\t'].reduce(
    (a, b) => _countOutsideQuotes(lines.first, b) > _countOutsideQuotes(lines.first, a) ? b : a,
  );
}

int _countOutsideQuotes(String line, String ch) {
  var count = 0;
  var inQuotes = false;
  for (final c in line.split('')) {
    if (c == '"') inQuotes = !inQuotes;
    if (!inQuotes && c == ch) count++;
  }
  return count;
}

// ---------------------------------------------------------------------------
// Which column means what
// ---------------------------------------------------------------------------

/// What a column can hold. Only [name] and [weight] are required.
enum ImportField {
  name, weight, unit, quantity, category, parentCategory, condition, section, consumable, worn,
}

/// Recognizes a unit however it's written: "g", "гр.", "grams", "кг",
/// "oz", "унц.", "lbs", "фнт"…
MassUnit? parseUnit(String text) {
  final t = text.trim().toLowerCase().replaceAll('.', '');
  return switch (t) {
    'g' || 'gr' || 'gram' || 'grams' || 'г' || 'гр' || 'грамм' || 'граммы' => MassUnit.g,
    'kg' || 'kgs' || 'kilogram' || 'kilograms' || 'кг' || 'килограмм' || 'килограммы' => MassUnit.kg,
    'oz' || 'ounce' || 'ounces' || 'унц' || 'унция' || 'унции' => MassUnit.oz,
    'lb' || 'lbs' || 'pound' || 'pounds' || 'фнт' || 'фунт' || 'фунты' => MassUnit.lb,
    _ => null,
  };
}

/// What the user (or the guess) decided: a column per field, and the unit
/// to assume when neither a unit column nor the weight cell says.
class ColumnMapping {
  ColumnMapping(this.columns, {required this.defaultUnit});

  final Map<ImportField, int> columns;
  MassUnit defaultUnit;

  ColumnMapping copy() => ColumnMapping({...columns}, defaultUnit: defaultUnit);

  bool get isComplete =>
      columns.containsKey(ImportField.name) && columns.containsKey(ImportField.weight);
}

String _norm(String s) =>
    s.replaceAll('﻿', '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Header spellings for each field, in both languages — LighterPack's,
/// our own exports', and what people tend to type in their own sheets.
const _synonyms = {
  ImportField.name: ['item name', 'name', 'item', 'название', 'наименование', 'вещь', 'предмет'],
  ImportField.quantity: ['qty', 'quantity', 'count', 'количество', 'кол-во', 'кол', 'шт'],
  ImportField.unit: ['unit', 'units', 'единица', 'единицы', 'ед', 'ед изм'],
  ImportField.category: ['category', 'категория'],
  ImportField.parentCategory: ['parent category', 'родительская категория'],
  ImportField.condition: ['condition', 'состояние'],
  ImportField.section: ['section', 'раздел'],
  ImportField.consumable: ['consumable', 'расходник'],
  ImportField.worn: ['worn', 'надето', 'надето на мне'],
};

/// The header without a trailing unit — "Вес за шт., г" → "вес за шт",
/// "Weight (kg)" → "weight" — plus that unit if there was one.
(String, MassUnit?) _splitHeaderUnit(String header) {
  final h = _norm(header);
  final match = RegExp(r'^(.*?)[\s,(]+([a-zа-я.]+)\)?$').firstMatch(h);
  if (match != null) {
    final unit = parseUnit(match.group(2)!);
    if (unit != null) return (match.group(1)!.trim(), unit);
  }
  return (h.replaceAll('.', '').trim(), null);
}

/// The best guess at a mapping from the headers alone. For a weight
/// column, "per item" beats "total": totals already include the quantity.
ColumnMapping guessMapping(List<String> headers, {required MassUnit defaultUnit}) {
  final columns = <ImportField, int>{};
  MassUnit? headerUnit;
  for (var i = 0; i < headers.length; i++) {
    final (base, unit) = _splitHeaderUnit(headers[i]);
    final isTotal = base.contains('total') || base.contains('всего');
    final isWeight = !isTotal &&
        (base == 'weight' || base == 'вес' || base == 'масса' ||
            base.startsWith('weight each') || base.startsWith('вес за'));
    if (isWeight && !columns.containsKey(ImportField.weight)) {
      columns[ImportField.weight] = i;
      headerUnit = unit;
      continue;
    }
    for (final MapEntry(key: field, value: names) in _synonyms.entries) {
      if (!columns.containsKey(field) && names.contains(base.replaceAll('.', ''))) {
        columns[field] = i;
        break;
      }
    }
  }
  return ColumnMapping(columns, defaultUnit: headerUnit ?? defaultUnit);
}

/// True when the guess needs no confirming: a name, a weight, and a unit
/// that comes from the file itself (a unit column, or one in the weight
/// header) — LighterPack's files and our own exports.
bool isConfidentGuess(List<String> headers, ColumnMapping mapping) {
  if (!mapping.isComplete) return false;
  if (mapping.columns.containsKey(ImportField.unit)) return true;
  return _splitHeaderUnit(headers[mapping.columns[ImportField.weight]!]).$2 != null;
}

// ---------------------------------------------------------------------------
// Rows into items
// ---------------------------------------------------------------------------

/// One row, read and cleaned up — ready to become a closet item.
class ImportedItem {
  const ImportedItem({
    required this.name,
    required this.weightGrams,
    this.quantity = 1,
    this.categoryName,
    this.parentCategoryName,
    this.condition = ItemCondition.newItem,
    this.packType,
    this.worn = false,
  });

  final String name;

  /// For one item — quantity is separate, as everywhere else in the app.
  final int weightGrams;
  final int quantity;
  final String? categoryName;
  final String? parentCategoryName;
  final ItemCondition condition;

  /// From a section/consumable column; null leaves it to the category.
  final PackType? packType;
  final bool worn;
}

class ImportResult {
  const ImportResult(this.items, {required this.skipped});

  final List<ImportedItem> items;

  /// Rows that had something in them but no usable name or weight.
  final int skipped;
}

/// A number with an optional unit right after it: "120", "1,5 кг",
/// "7.05oz". Null if there's no number.
(double, MassUnit?)? parseWeightCell(String text) {
  final match =
      RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*([a-zA-Zа-яА-Я.]*)\s*$').firstMatch(text);
  if (match == null) return null;
  final value = double.parse(match.group(1)!.replaceAll(',', '.'));
  final unitText = match.group(2)!;
  return (value, unitText.isEmpty ? null : parseUnit(unitText));
}

/// Every label a condition or section has ever had in either language, so
/// a file exported in Russian imports into the English app and back.
final _ru = lookupAppLocalizations(const Locale('ru'));
final _en = lookupAppLocalizations(const Locale('en'));

ItemCondition? _parseCondition(String text) {
  final t = _norm(text);
  for (final c in ItemCondition.values) {
    if (t == c.name.toLowerCase() ||
        t == _norm(conditionLabel(_ru, c)) ||
        t == _norm(conditionLabel(_en, c))) {
      return c;
    }
  }
  return null;
}

PackType? _parseSection(String text) {
  final t = _norm(text);
  for (final p in PackType.values) {
    if (t == p.name || t == _norm(packTypeLabel(_ru, p)) || t == _norm(packTypeLabel(_en, p))) {
      return p;
    }
  }
  return null;
}

/// A yes/no column: LighterPack writes the column's own name ("Worn",
/// "Consumable") for yes; our Excel writes "да"/"yes". Anything but blank
/// or an explicit no counts.
bool _isMarked(String text) =>
    text.isNotEmpty && !const {'false', '0', 'no', 'нет'}.contains(_norm(text));

bool _isWater(String text) => RegExp(r'water|вод').hasMatch(text.toLowerCase());

ImportResult parseRows(ImportTable table, ColumnMapping mapping) {
  String cell(List<String> row, ImportField field) {
    final i = mapping.columns[field];
    return i == null || i >= row.length ? '' : row[i].trim();
  }

  final items = <ImportedItem>[];
  var skipped = 0;
  for (final row in table.rows) {
    final name = cell(row, ImportField.name);
    final weight = parseWeightCell(cell(row, ImportField.weight));
    if (name.isEmpty || weight == null) {
      skipped++;
      continue;
    }
    final (value, cellUnit) = weight;
    final unit = cellUnit ?? parseUnit(cell(row, ImportField.unit)) ?? mapping.defaultUnit;
    final quantity = int.tryParse(cell(row, ImportField.quantity).split(RegExp(r'[.,]')).first);
    final category = cell(row, ImportField.category);
    final parent = cell(row, ImportField.parentCategory);
    final isConsumable = _isMarked(cell(row, ImportField.consumable));

    items.add(ImportedItem(
      name: name,
      weightGrams: (value * unit.grams).round(),
      quantity: quantity == null || quantity < 1 ? 1 : quantity,
      categoryName: category.isEmpty ? null : category,
      parentCategoryName: parent.isEmpty ? null : parent,
      condition: _parseCondition(cell(row, ImportField.condition)) ?? ItemCondition.newItem,
      packType: _parseSection(cell(row, ImportField.section)) ??
          // LighterPack only says "consumable" — food or water, then, by
          // whether the item or its category mentions water.
          (isConsumable
              ? (_isWater(name) || _isWater(category) ? PackType.water : PackType.food)
              : null),
      worn: _isMarked(cell(row, ImportField.worn)),
    ));
  }
  return ImportResult(items, skipped: skipped);
}

/// Items already in the closet — same name and same category, ignoring
/// case. Matching on name alone would call two different "Мешок"s in two
/// categories duplicates.
Set<int> findDuplicates(
  List<ImportedItem> incoming, {
  required List<Item> existing,
  required List<Category> categories,
}) {
  final categoryById = {for (final c in categories) c.id: c};
  String key(String name, String? category) =>
      '${_norm(name)}\u0000${_norm(category ?? '')}';
  final have = {
    for (final i in existing) key(i.name, categoryById[i.categoryId]?.name),
  };
  return {
    for (var i = 0; i < incoming.length; i++)
      if (have.contains(key(incoming[i].name, incoming[i].categoryName))) i,
  };
}

/// How many categories the import would add that don't exist yet.
int countNewCategories(List<ImportedItem> incoming, List<Category> categories) {
  final have = {for (final c in categories) _norm(c.name)};
  final names = <String>{
    for (final i in incoming) ...[
      if (i.categoryName != null) _norm(i.categoryName!),
      if (i.parentCategoryName != null) _norm(i.parentCategoryName!),
    ],
  };
  return names.difference(have).length;
}

// ---------------------------------------------------------------------------
// Writing to the database
// ---------------------------------------------------------------------------

/// Icon keys guessed from a new category's name, in both languages — a
/// "Аптечка" gets the first-aid icon instead of a generic one.
const _iconKeywords = {
  'backpack': ['рюкзак', 'backpack', 'pack'],
  'tent': ['палат', 'tent', 'shelter', 'укрыт', 'тент'],
  'sleep': ['спал', 'sleep', 'quilt'],
  'kitchen': ['кух', 'kitchen', 'cook', 'посуд', 'stove', 'горел'],
  'clothing': ['одежд', 'cloth', 'wear', 'apparel'],
  'food': ['еда', 'food', 'питан', 'snack', 'meal'],
  'water': ['вод', 'water', 'hydrat'],
  'firstAid': ['аптеч', 'first aid', 'medic', 'мед'],
  'navigation': ['навиг', 'navig', 'map', 'карт'],
  'electronics': ['электр', 'electr', 'gadget', 'power'],
  'hygiene': ['гигиен', 'hygien', 'toilet', 'туалет'],
  'tools': ['инструм', 'tool', 'repair', 'ремонт'],
  'footwear': ['обув', 'foot', 'shoe', 'boot'],
};

String _guessIcon(String name, PackType packType) {
  final n = name.toLowerCase();
  for (final MapEntry(key: icon, value: words) in _iconKeywords.entries) {
    if (words.any(n.contains)) return icon;
  }
  return switch (packType) {
    PackType.food => 'food',
    PackType.water => 'water',
    PackType.gear => 'misc',
  };
}

const _newCategoryColors = ['terracotta', 'sage', 'teal', 'mustard', 'plum', 'slate'];

/// Adds [items] to the closet in one transaction, creating any category
/// (and parent category) that doesn't exist yet — matched by name,
/// ignoring case — with a guessed icon and the next color in turn.
/// Returns how many items were added.
Future<int> importItems(AppDatabase db, List<ImportedItem> items) {
  return db.transaction(() async {
    final categories = await db.select(db.categories).get();
    var colorIndex = 0;

    Future<Category> findOrCreate(String name, {Category? parent, PackType? packType}) async {
      for (final c in categories) {
        if (_norm(c.name) == _norm(name) && (parent == null || c.parentId == parent.id)) return c;
      }
      // A subcategory always shares its root's section, as everywhere else.
      final type = parent?.packType ?? packType ?? PackType.gear;
      final id = await db.into(db.categories).insert(CategoriesCompanion.insert(
            name: name,
            parentId: Value(parent?.id),
            packType: type,
            icon: Value(_guessIcon(name, type)),
            color: Value(_newCategoryColors[colorIndex++ % _newCategoryColors.length]),
          ));
      final created = await (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle();
      categories.add(created);
      return created;
    }

    for (final item in items) {
      Category? category;
      if (item.categoryName != null) {
        final parent = item.parentCategoryName == null
            ? null
            : await findOrCreate(item.parentCategoryName!, packType: item.packType);
        category = await findOrCreate(item.categoryName!, parent: parent, packType: item.packType);
      }
      await db.addItem(
        name: item.name,
        weightGrams: item.weightGrams,
        categoryId: category?.id,
        condition: item.condition,
        packType: category == null ? item.packType ?? PackType.gear : null,
        quantity: item.quantity,
        worn: item.worn,
      );
    }
    return items.length;
  });
}
