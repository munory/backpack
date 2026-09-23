import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';
import 'category_style.dart';
import 'input_decoration.dart';
import 'pack_type_chips.dart';
import 'text_format.dart';
import 'theme.dart';

/// A category flattened into depth-first display order, with its nesting
/// depth, for indenting it in a picker.
class FlatCategory {
  FlatCategory(this.category, this.depth);
  final Category category;
  final int depth;
}

List<FlatCategory> flattenCategories(List<Category> categories) {
  final childrenOf = <int?, List<Category>>{};
  for (final c in categories) {
    childrenOf.putIfAbsent(c.parentId, () => []).add(c);
  }
  final result = <FlatCategory>[];
  void visit(int? parentId, int depth) {
    for (final c in childrenOf[parentId] ?? const <Category>[]) {
      result.add(FlatCategory(c, depth));
      visit(c.id, depth + 1);
    }
  }

  visit(null, 0);
  return result;
}

Set<int> _descendantIds(int categoryId, List<Category> all) {
  final childrenOf = <int?, List<Category>>{};
  for (final c in all) {
    childrenOf.putIfAbsent(c.parentId, () => []).add(c);
  }
  final result = <int>{};
  void visit(int id) {
    for (final c in childrenOf[id] ?? const <Category>[]) {
      result.add(c.id);
      visit(c.id);
    }
  }

  visit(categoryId);
  return result;
}

/// Opens the create/edit category sheet. Pass [editing] to edit an existing
/// category in place instead of creating a new one. Returns the created or
/// edited category's id, or null if the user cancelled.
Future<int?> showCategoryFormSheet(BuildContext context, {Category? editing}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _CategoryFormDialog(editing: editing),
    ),
  );
}

class _CategoryFormDialog extends ConsumerStatefulWidget {
  const _CategoryFormDialog({this.editing});
  final Category? editing;

  @override
  ConsumerState<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<_CategoryFormDialog> {
  final _nameController = TextEditingController();
  int? _parentId;
  PackType _packType = PackType.gear;
  String _icon = categoryIconOptions.first.key;
  String _color = categoryColorOptions.first.key;
  String? _error;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _nameController.text = editing.name;
      _parentId = editing.parentId;
      _packType = editing.packType;
      _icon = editing.icon ?? _icon;
      _color = editing.color ?? _color;
    }
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  PackType _resolvePackType(List<Category> categories) {
    if (_parentId == null) return _packType;
    for (final c in categories) {
      if (c.id == _parentId) return c.packType;
    }
    return _packType;
  }

  Future<void> _submit(List<Category> categories) async {
    final name = capitalizeFirst(_nameController.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Введи название категории');
      return;
    }

    final db = ref.read(databaseProvider);
    final packType = _resolvePackType(categories);
    final editing = widget.editing;

    if (editing == null) {
      final id = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: name,
              parentId: Value(_parentId),
              packType: packType,
              icon: Value(_icon),
              color: Value(_color),
            ),
          );
      if (mounted) Navigator.pop(context, id);
    } else {
      await db.updateCategory(
        id: editing.id,
        name: name,
        parentId: _parentId,
        packType: packType,
        icon: _icon,
        color: _color,
      );
      if (mounted) Navigator.pop(context, editing.id);
    }
  }

  Future<void> _showParentCategoryInfo(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(
          'Пока нет ни одной категории — создайте первую, и потом '
          'сможете сделать её родителем для новых.',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final editing = widget.editing;
    // Editing a category can't offer itself or its own descendants as a new
    // parent — that would create a cycle in the tree.
    final excluded =
        editing == null ? const <int>{} : {editing.id, ..._descendantIds(editing.id, categories)};
    final flat =
        flattenCategories(categories).where((f) => !excluded.contains(f.category.id)).toList();

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                editing == null ? 'Новая категория' : 'Редактировать категорию',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const FieldLabel('Название категории'),
              SizedBox(
                height: kFieldHeight,
                child: TextField(
                  controller: _nameController,
                  decoration: appFieldDecoration(),
                ),
              ),
              const SizedBox(height: 20),
              FieldLabel(
                'Родительская категория',
                // The info icon only explains why the list is just "Нет" —
                // once a real category exists, that explanation no longer
                // applies, so the icon should disappear with it.
                trailing: flat.isEmpty
                    ? InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showParentCategoryInfo(context),
                        child: Icon(Icons.info_outline, size: 16, color: AppColors.accent),
                      )
                    : null,
              ),
              AppSelectField<int?>(
                value: _parentId,
                onChanged: (v) => setState(() => _parentId = v),
                menuColor: AppColors.menuSurfaceOnElevated,
                options: [
                  const SelectOption(null, 'Нет (основная категория)'),
                  for (final f in flat)
                    SelectOption(f.category.id, f.category.name, depth: f.depth),
                ],
              ),
              if (_parentId == null) ...[
                const SizedBox(height: 20),
                const FieldLabel('Раздел'),
                PackTypeChips(value: _packType, onChanged: (v) => setState(() => _packType = v)),
              ],
              const SizedBox(height: 20),
              const FieldLabel('Иконка'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final option in categoryIconOptions)
                    _IconChoice(
                      icon: option.icon,
                      selected: option.key == _icon,
                      color: categoryColorOptions.firstWhere((c) => c.key == _color).color,
                      onTap: () => setState(() => _icon = option.key),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const FieldLabel('Цвет'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final option in categoryColorOptions)
                    _ColorChoice(
                      color: option.color,
                      selected: option.key == _color,
                      onTap: () => setState(() => _color = option.key),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.overWeight)),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _nameController.text.trim().isEmpty ? null : () => _submit(categories),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            _nameController.text.trim().isEmpty ? null : AppColors.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      child: Text(editing == null ? 'Создать' : 'Сохранить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One icon option in the picker — shown in the currently-selected color so
/// the grid doubles as a live preview of "icon + color together", not just
/// two separate, hard-to-relate choices.
class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.22 : 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.textPrimary.withValues(alpha: 0.5) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}
