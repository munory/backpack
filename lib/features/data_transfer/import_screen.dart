import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/input_decoration.dart';
import '../../common/item_name.dart';
import '../../common/l10n.dart';
import '../../common/navigation.dart';
import '../../common/primary_button.dart';
import '../../common/theme.dart';
import '../../common/weight_format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'gear_import.dart';

/// "Импорт из файла": pick a .csv/.xlsx, read it, and open [ImportScreen] —
/// straight on the preview when the file explains itself (LighterPack, our
/// own exports), on the column step otherwise.
Future<void> startImport(BuildContext context) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final unit = weightUnitOf(context) == WeightUnit.metric ? MassUnit.g : MassUnit.oz;

  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['csv', 'xlsx'],
  );
  if (picked.isEmpty) return;
  final file = picked.first;

  final ImportTable table;
  try {
    table = readImportTable(await file.readAsBytes(), file.name);
    if (table.rows.isEmpty) throw const FormatException('empty');
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.importReadError)));
    return;
  }
  final mapping = guessMapping(table.headers, defaultUnit: unit);
  navigator.push(MaterialPageRoute(
    builder: (_) => ImportScreen(
      table: table,
      fileName: file.name,
      initialMapping: mapping,
      startOnPreview: isConfidentGuess(table.headers, mapping),
    ),
  ));
}

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({
    super.key,
    required this.table,
    required this.fileName,
    required this.initialMapping,
    required this.startOnPreview,
  });

  final ImportTable table;
  final String fileName;
  final ColumnMapping initialMapping;
  final bool startOnPreview;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  late final ColumnMapping _mapping = widget.initialMapping.copy();
  late bool _preview = widget.startOnPreview;

  /// What to do with items already in the closet — asked once for the
  /// whole file. Skipping is the default, so importing the same file twice
  /// doesn't double everything.
  bool _skipDuplicates = true;
  bool _importing = false;

  Future<void> _import(List<ImportedItem> items) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importing = true);
    final added = await importItems(ref.read(databaseProvider), items);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(currentTabProvider.notifier).state = 1;
    messenger.showSnackBar(SnackBar(content: Text(l.importDone(l.itemCount(added)))));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.importTitle)),
      body: _preview ? _buildPreview(context) : _buildMapping(context),
    );
  }

  // --- Step 1: which column is what -----------------------------------------

  Widget _buildMapping(BuildContext context) {
    final l = context.l10n;
    final headers = widget.table.headers;
    final columnOptions = <SelectOption<int?>>[
      SelectOption(null, l.columnNone),
      for (var i = 0; i < headers.length; i++)
        SelectOption(i, headers[i].trim().isEmpty ? l.columnN(i + 1) : headers[i].trim()),
    ];
    final labels = {
      ImportField.name: '${l.name} *',
      ImportField.weight: '${l.weight} *',
      ImportField.unit: l.fieldUnit,
      ImportField.quantity: l.quantity,
      ImportField.category: l.category,
      ImportField.parentCategory: l.parentCategory,
      ImportField.condition: l.condition,
      ImportField.section: l.section,
      ImportField.consumable: l.fieldConsumable,
      ImportField.worn: l.wornLabel,
    };
    final sample = _mapping.isComplete
        ? parseRows(widget.table, _mapping).items.take(3).toList()
        : const <ImportedItem>[];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l.importMappingTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(widget.fileName, style: _mutedStyle),
        const SizedBox(height: 8),
        Text(l.importMappingHint, style: _mutedStyle.copyWith(height: 1.4)),
        const SizedBox(height: 20),
        for (final MapEntry(key: field, value: label) in labels.entries) ...[
          FieldLabel(label),
          AppSelectField<int?>(
            value: _mapping.columns[field],
            options: columnOptions,
            onChanged: (v) => setState(() {
              if (v == null) {
                _mapping.columns.remove(field);
              } else {
                _mapping.columns[field] = v;
              }
            }),
          ),
          const SizedBox(height: 14),
          // Right after the weight: the unit to assume when the file
          // doesn't say — only asked when there's no unit column.
          if (field == ImportField.unit && !_mapping.columns.containsKey(ImportField.unit)) ...[
            FieldLabel(l.defaultUnit),
            AppSelectField<MassUnit>(
              value: _mapping.defaultUnit,
              options: [for (final u in MassUnit.values) SelectOption(u, u.label(l))],
              onChanged: (v) => setState(() => _mapping.defaultUnit = v),
            ),
            const SizedBox(height: 14),
          ],
        ],
        if (sample.isNotEmpty) ...[
          const SizedBox(height: 6),
          FieldLabel(l.importExample),
          for (final item in sample) _ItemLine(item: item),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          label: l.next,
          onPressed: _mapping.isComplete ? () => setState(() => _preview = true) : null,
        ),
      ],
    );
  }

  // --- Step 2: what will be added ------------------------------------------

  Widget _buildPreview(BuildContext context) {
    final l = context.l10n;
    final result = parseRows(widget.table, _mapping);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final duplicates = findDuplicates(
      result.items,
      existing: ref.watch(allItemsProvider).value ?? const [],
      categories: categories,
    );
    final toImport = [
      for (var i = 0; i < result.items.length; i++)
        if (!_skipDuplicates || !duplicates.contains(i)) result.items[i],
    ];
    final newCategories = countNewCategories(toImport, categories);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              Text(widget.fileName, style: _mutedStyle),
              const SizedBox(height: 4),
              Text(
                [l.itemCount(result.items.length), if (newCategories > 0) l.newCategoryCount(newCategories)]
                    .join(' · '),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              if (result.skipped > 0) ...[
                const SizedBox(height: 4),
                Text(l.skippedRows(result.skipped), style: TextStyle(color: AppColors.warning)),
              ],
              if (duplicates.isNotEmpty) ...[
                const SizedBox(height: 16),
                FieldLabel(l.duplicatesFound(duplicates.length)),
                AppSelectField<bool>(
                  value: _skipDuplicates,
                  options: [SelectOption(true, l.duplicatesSkip), SelectOption(false, l.duplicatesAdd)],
                  onChanged: (v) => setState(() => _skipDuplicates = v),
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _preview = false),
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(l.adjustColumns),
                ),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < result.items.length; i++)
                _ItemLine(
                  item: result.items[i],
                  note: _skipDuplicates && duplicates.contains(i) ? l.alreadyHave : null,
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: PrimaryButton(
              label: toImport.isEmpty ? l.nothingToImport : l.importButton(l.itemCount(toImport.length)),
              onPressed: toImport.isEmpty || _importing ? null : () => _import(toImport),
            ),
          ),
        ),
      ],
    );
  }

  TextStyle get _mutedStyle =>
      TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.75));
}

/// One incoming item: name (with quantity), category, weight. [note] dims
/// it with a reason — e.g. a duplicate that will be skipped.
class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item, this.note});

  final ImportedItem item;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final category = [?item.parentCategoryName, ?item.categoryName].join(' / ');
    final details = [
      if (category.isNotEmpty) category,
      if (item.worn) context.l10n.wornTag,
      ?note,
    ].join(' · ');
    // Shown through the same name widget as everywhere else, so the
    // quantity reads "(4 шт.)" here too.
    final asItem = Item(
      id: 0,
      uuid: '',
      updatedAt: 0,
      name: item.name,
      weightGrams: item.weightGrams,
      condition: item.condition,
      quantity: item.quantity,
      worn: item.worn,
    );
    return Opacity(
      opacity: note == null ? 1 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  itemNameText(asItem, style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (details.isNotEmpty)
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(formatWeight(context, item.weightGrams * item.quantity)),
          ],
        ),
      ),
    );
  }
}
