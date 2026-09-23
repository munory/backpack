import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/category_form_sheet.dart';
import '../../common/input_decoration.dart';
import '../../common/pack_type_chips.dart';
import '../../common/primary_button.dart';
import '../../common/text_format.dart';
import '../../common/theme.dart';
import '../../common/weight_format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key, this.editing, this.initialCategoryId});

  /// When set, the form edits this existing item in place instead of
  /// creating a new one.
  final Item? editing;

  /// Pre-selects this category for a brand-new item — e.g. tapping "+
  /// Добавить вещь" inside an already-expanded, empty category. Ignored
  /// when [editing] is set.
  final int? initialCategoryId;

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

const _gramsPerOunce = 28.3495;

/// Whole number if it rounds cleanly, otherwise up to 2 decimal places —
/// used when switching weight units so the field shows a value someone
/// would actually type, not a long float tail.
String _formatWeightValue(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '').replaceFirst(RegExp(r'\.$'), '');
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  int? _categoryId;
  ItemCondition _condition = ItemCondition.newItem;
  int _quantity = 1;
  // Only used when _categoryId is null — an item without a category still
  // needs to know its own section to count toward the right total.
  PackType _itemPackType = PackType.gear;
  String _weightUnit = 'г';
  String? _error;

  // The field only ever displays a *rounded* value, so re-parsing that text
  // as the source of truth on every unit switch compounds rounding error
  // (200g -> 7.05oz -> 199.86g -> ...). This holds the actual weight at full
  // precision, in grams, independent of whatever's currently rounded for
  // display; only user keystrokes (not our own reformatting) update it.
  double? _preciseGrams;
  bool _suppressWeightSync = false;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _nameController.text = editing.name;
      _weightController.text = editing.weightGrams.toString();
      _preciseGrams = editing.weightGrams.toDouble();
      _categoryId = editing.categoryId;
      _condition = editing.condition;
      _itemPackType = editing.packType ?? PackType.gear;
      _quantity = editing.quantity;
    } else if (widget.initialCategoryId != null) {
      _categoryId = widget.initialCategoryId;
    }
    // The submit button is disabled until the form is actually fillable —
    // needs a rebuild on every keystroke to keep that in sync.
    _nameController.addListener(() => setState(() {}));
    _weightController.addListener(_syncPreciseGramsFromText);
  }

  void _syncPreciseGramsFromText() {
    if (_suppressWeightSync) return;
    final raw = double.tryParse(_weightController.text.replaceAll(',', '.'));
    _preciseGrams = raw == null ? null : (_weightUnit == 'унц.' ? raw * _gramsPerOunce : raw);
    setState(() {});
  }

  void _onWeightUnitChanged(String newUnit) {
    if (_preciseGrams != null) {
      final displayValue = newUnit == 'унц.' ? _preciseGrams! / _gramsPerOunce : _preciseGrams!;
      _suppressWeightSync = true;
      _weightController.text = _formatWeightValue(displayValue);
      _suppressWeightSync = false;
    }
    setState(() => _weightUnit = newUnit);
  }

  bool get _canSubmit {
    return _nameController.text.trim().isNotEmpty && _preciseGrams != null && _preciseGrams! > 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _createCategory() async {
    final created = await showCategoryFormSheet(context);
    if (created != null) {
      setState(() => _categoryId = created);
    }
  }

  Future<void> _submit() async {
    final name = capitalizeFirst(_nameController.text.trim());

    if (name.isEmpty) {
      setState(() => _error = 'Введи название вещи');
      return;
    }
    if (_preciseGrams == null || _preciseGrams! <= 0) {
      setState(() => _error = 'Укажи вес');
      return;
    }
    final weightGrams = _preciseGrams!.round();

    final db = ref.read(databaseProvider);
    final editing = widget.editing;
    if (editing == null) {
      await db.addItem(
        name: name,
        weightGrams: weightGrams,
        categoryId: _categoryId,
        condition: _condition,
        packType: _categoryId == null ? _itemPackType : null,
        quantity: _quantity,
      );
    } else {
      await db.updateItem(
        id: editing.id,
        name: name,
        weightGrams: weightGrams,
        categoryId: _categoryId,
        condition: _condition,
        packType: _categoryId == null ? _itemPackType : null,
        quantity: _quantity,
      );
    }
    if (mounted) Navigator.pop(context);
  }


  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final flat = flattenCategories(categories);

    final isEditing = widget.editing != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Редактировать вещь' : 'Добавить вещь')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Название вещи'),
            SizedBox(
              height: kFieldHeight,
              child: TextField(
                controller: _nameController,
                decoration: appFieldDecoration(),
              ),
            ),
            const SizedBox(height: 20),
            const FieldLabel('Вес'),
            SizedBox(
              height: kFieldHeight,
              child: TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: appFieldDecoration().copyWith(
                  suffixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 1,
                          height: 24,
                          color: AppColors.textPrimary.withValues(alpha: 0.15),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          initialValue: _weightUnit,
                          onSelected: _onWeightUnitChanged,
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'г', child: Text('г')),
                            PopupMenuItem(value: 'унц.', child: Text('унц.')),
                          ],
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _weightUnit,
                                style: const TextStyle(color: AppColors.textPrimary),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FieldLabel(
              'Количество',
              trailing: _quantity > 1 && _preciseGrams != null
                  ? Text(
                      '= ${formatKg((_preciseGrams! * _quantity).round())} всего',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
            Container(
              height: kFieldHeight,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    color: AppColors.textPrimary,
                    onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '$_quantity',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    color: AppColors.textPrimary,
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const FieldLabel('Категория'),
            AppSelectField<int?>(
              value: _categoryId,
              onChanged: (v) => setState(() => _categoryId = v),
              options: [
                const SelectOption(null, 'Без категории'),
                for (final f in flat)
                  SelectOption(f.category.id, f.category.name, depth: f.depth + 1),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _createCategory,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Создать категорию'),
              ),
            ),
            // No category chosen — the item still needs to know its own
            // section to count toward the right total on the dashboard.
            if (_categoryId == null) ...[
              const SizedBox(height: 20),
              const FieldLabel('Раздел'),
              PackTypeChips(
                value: _itemPackType,
                onChanged: (v) => setState(() => _itemPackType = v),
              ),
            ],
            const SizedBox(height: 20),
            const FieldLabel('Состояние'),
            AppSelectField<ItemCondition>(
              value: _condition,
              onChanged: (v) => setState(() => _condition = v),
              pinSelectedFirst: true,
              options: [
                for (final entry in conditionLabels.entries)
                  SelectOption(entry.key, entry.value),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.overWeight)),
            ],
            const SizedBox(height: 32),
            PrimaryButton(
              label: isEditing ? 'Сохранить' : 'Добавить вещь',
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
