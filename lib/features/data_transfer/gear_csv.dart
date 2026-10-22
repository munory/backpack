import 'dart:convert';

import '../../common/l10n.dart';
import '../../common/weight_format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// LighterPack's own CSV columns, in its order — a file with these first
/// imports straight into LighterPack, which ignores anything after them.
const lighterPackColumns = [
  'Item Name', 'Category', 'desc', 'qty', 'weight', 'unit',
  'url', 'price', 'worn', 'consumable',
];

/// What LighterPack has no place for, appended after its columns so a
/// round trip through our own import loses nothing.
const extraColumns = ['condition', 'section', 'parent category'];

/// The whole closet as CSV text. Weight is per single item (LighterPack's
/// convention, with qty alongside): whole grams in metric, ounces to two
/// decimals in imperial. Condition and section are written in the current
/// language — this file is as much for reading in a spreadsheet as for
/// importing.
String buildGearCsv({
  required List<Item> items,
  required List<Category> categories,
  required WeightUnit unit,
  required AppLocalizations l,
}) {
  final categoryById = {for (final c in categories) c.id: c};
  final rows = <List<String>>[
    [...lighterPackColumns, ...extraColumns],
  ];
  for (final item in items) {
    final category = item.categoryId == null ? null : categoryById[item.categoryId];
    final parent = category?.parentId == null ? null : categoryById[category!.parentId];
    final section = effectivePackType(item, categoryById);
    final weight = unit == WeightUnit.metric
        ? '${item.weightGrams}'
        : (item.weightGrams / gramsPerOunce).toStringAsFixed(2);
    rows.add([
      item.name,
      category?.name ?? '',
      '',
      '${item.quantity}',
      weight,
      unit == WeightUnit.metric ? 'g' : 'oz',
      '',
      '',
      item.worn ? 'Worn' : '',
      section == PackType.gear ? '' : 'Consumable',
      conditionLabel(l, item.condition),
      packTypeLabel(l, section),
      parent?.name ?? '',
    ]);
  }
  // CRLF line endings, as the CSV standard (and Excel) expect.
  return rows.map((r) => r.map(_csvField).join(',')).join('\r\n');
}

/// Quotes a field only when it has to be — a comma, quote or line break
/// inside — doubling any quotes, per the CSV standard.
String _csvField(String value) {
  if (!value.contains(RegExp(r'[",\r\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

/// The CSV as file bytes — UTF-8 with a byte-order mark up front, which
/// makes Excel read Cyrillic correctly instead of as garbage.
List<int> csvFileBytes(String csv) => utf8.encode('﻿$csv');
