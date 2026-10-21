import 'package:excel/excel.dart' as xl;

import '../../common/l10n.dart';
import '../../common/weight_format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// The whole closet as a real Excel workbook — for people, not for another
/// app: headers in the current language, weights as numbers (so sums and
/// sorting just work), a per-item and a total weight column, sorted by
/// category. Unlike CSV it opens correctly in any Excel, whatever its
/// regional settings.
List<int> buildGearXlsx({
  required List<Item> items,
  required List<Category> categories,
  required WeightUnit unit,
  required AppLocalizations l,
}) {
  final categoryById = {for (final c in categories) c.id: c};
  String categoryName(Item i) => i.categoryId == null ? '' : categoryById[i.categoryId]?.name ?? '';
  final sorted = [...items]..sort((a, b) {
      final ca = categoryName(a), cb = categoryName(b);
      // Uncategorized last, then by name within a category.
      if (ca.isEmpty != cb.isEmpty) return ca.isEmpty ? 1 : -1;
      final byCategory = ca.compareTo(cb);
      return byCategory != 0 ? byCategory : a.name.compareTo(b.name);
    });

  final metric = unit == WeightUnit.metric;
  final smallUnit = metric ? l.unitG : l.unitOz;
  xl.CellValue weight(int grams) => metric
      ? xl.IntCellValue(grams)
      : xl.DoubleCellValue(double.parse((grams / gramsPerOunce).toStringAsFixed(2)));

  final excel = xl.Excel.createExcel();
  final sheetName = l.navInventory;
  excel.rename(excel.getDefaultSheet()!, sheetName);
  final sheet = excel[sheetName];

  final headers = [
    l.name, l.category, l.parentCategory, l.section, l.condition, l.quantity,
    l.colWeightEach(smallUnit), l.colWeightTotal(smallUnit),
  ];
  sheet.appendRow([for (final h in headers) xl.TextCellValue(h)]);
  for (var c = 0; c < headers.length; c++) {
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle =
        xl.CellStyle(bold: true);
  }

  for (final item in sorted) {
    final category = item.categoryId == null ? null : categoryById[item.categoryId];
    final parent = category?.parentId == null ? null : categoryById[category!.parentId];
    sheet.appendRow([
      xl.TextCellValue(item.name),
      xl.TextCellValue(category?.name ?? ''),
      xl.TextCellValue(parent?.name ?? ''),
      xl.TextCellValue(packTypeLabel(l, effectivePackType(item, categoryById))),
      xl.TextCellValue(conditionLabel(l, item.condition)),
      xl.IntCellValue(item.quantity),
      weight(item.weightGrams),
      weight(item.weightGrams * item.quantity),
    ]);
  }

  const widths = [34.0, 20.0, 22.0, 14.0, 18.0, 10.0, 16.0, 16.0];
  for (var c = 0; c < widths.length; c++) {
    sheet.setColumnWidth(c, widths[c]);
  }
  return excel.encode()!;
}
