import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/app_checkbox.dart';
import '../../common/category_form_sheet.dart';
import '../../common/input_decoration.dart';
import '../../common/l10n.dart';
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

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  int? _categoryId;
  ItemCondition _condition = ItemCondition.newItem;
  int _quantity = 1;
  // Only used when _categoryId is null — an item without a category still
  // needs to know its own section to count toward the right total.
  PackType _itemPackType = PackType.gear;
  MassUnit _weightUnit = MassUnit.g;
  bool _worn = false;
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
      _preciseGrams = editing.weightGrams.toDouble();
      _categoryId = editing.categoryId;
      _condition = editing.condition;
      _itemPackType = editing.packType ?? PackType.gear;
      _quantity = editing.quantity;
      _worn = editing.worn;
    } else if (widget.initialCategoryId != null) {
      _categoryId = widget.initialCategoryId;
    }
    // The submit button is disabled until the form is actually fillable —
    // needs a rebuild on every keystroke to keep that in sync.
    _nameController.addListener(() => setState(() {}));
    _weightController.addListener(_syncPreciseGramsFromText);
  }

  bool _unitChosen = false;

  /// The field starts in the user's small unit (grams, or ounces for
  /// pounds) — done here rather than in initState, which can't read
  /// settings that depend on the language yet. Kilograms and pounds are in
  /// the unit menu too, for a tent read off a kitchen scale.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_unitChosen) return;
    _unitChosen = true;
    _weightUnit = weightUnitOf(context) == WeightUnit.imperial ? MassUnit.oz : MassUnit.g;
    _showPreciseGrams();
  }

  void _showPreciseGrams() {
    if (_preciseGrams == null) return;
    _suppressWeightSync = true;
    _weightController.text = formatInputNumber(
      _preciseGrams! / _weightUnit.grams,
      languageCode: context.l10n.localeName,
    );
    _suppressWeightSync = false;
  }

  void _syncPreciseGramsFromText() {
    if (_suppressWeightSync) return;
    final raw = parseInputNumber(_weightController.text);
    _preciseGrams = raw == null ? null : raw * _weightUnit.grams;
    setState(() {});
  }

  void _onWeightUnitChanged(MassUnit unit) {
    _weightUnit = unit;
    _showPreciseGrams();
    setState(() {});
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
      setState(() => _error = context.l10n.itemNameRequired);
      return;
    }
    if (_preciseGrams == null || _preciseGrams! <= 0) {
      setState(() => _error = context.l10n.weightRequired);
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
        worn: _worn,
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
        worn: _worn,
      );
    }
    if (mounted) Navigator.pop(context);
  }


  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final flat = flattenCategories(categories);

    final isEditing = widget.editing != null;
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? l.editItem : l.addItem)),
      // Scrolls — with every field showing it no longer fits a small phone.
      body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FieldLabel(l.itemName),
            SizedBox(
              height: kFieldHeight,
              child: TextField(
                controller: _nameController,
                decoration: appFieldDecoration(),
              ),
            ),
            const SizedBox(height: 20),
            FieldLabel(l.weight),
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
                        PopupMenuButton<MassUnit>(
                          initialValue: _weightUnit,
                          onSelected: _onWeightUnitChanged,
                          itemBuilder: (context) => [
                            for (final u in MassUnit.values)
                              PopupMenuItem(value: u, child: Text(u.label(l))),
                          ],
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _weightUnit.label(l),
                                style: TextStyle(color: AppColors.textPrimary),
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
              l.quantity,
              trailing: _quantity > 1 && _preciseGrams != null
                  ? Text(
                      l.weightTotal(formatWeight(context, (_preciseGrams! * _quantity).round())),
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
            FieldLabel(l.category),
            AppSelectField<int?>(
              value: _categoryId,
              onChanged: (v) => setState(() => _categoryId = v),
              options: [
                SelectOption(null, l.noCategory),
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
                label: Text(l.createCategory),
              ),
            ),
            // No category chosen — the item still needs to know its own
            // section to count toward the right total on the dashboard.
            if (_categoryId == null) ...[
              const SizedBox(height: 20),
              FieldLabel(l.section),
              PackTypeChips(
                value: _itemPackType,
                onChanged: (v) => setState(() => _itemPackType = v),
              ),
            ],
            const SizedBox(height: 20),
            FieldLabel(l.condition),
            AppSelectField<ItemCondition>(
              value: _condition,
              onChanged: (v) => setState(() => _condition = v),
              pinSelectedFirst: true,
              options: [
                for (final c in conditionOrder) SelectOption(c, conditionLabel(l, c)),
              ],
            ),
            const SizedBox(height: 16),
            // Boots and a rain shell you hike in aren't in the pack — they
            // stay out of the pack and base weight (shown on Главная as
            // "надето на тебе" instead).
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _worn = !_worn),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    AppCheckbox(value: _worn, onChanged: (v) => setState(() => _worn = v)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.wornLabel, style: const TextStyle(fontSize: 15)),
                          Text(
                            l.wornHint,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: AppColors.overWeight)),
            ],
            const SizedBox(height: 32),
            PrimaryButton(
              label: isEditing ? l.save : l.addItem,
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
      ),
    );
  }
}
