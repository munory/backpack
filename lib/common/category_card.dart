import 'package:flutter/material.dart';

import '../data/database.dart';
import 'app_checkbox.dart';
import 'category_style.dart';
import 'item_name.dart';
import 'theme.dart';
import 'weight_format.dart';

/// An expandable category row: icon badge, name, weight, and its items when
/// expanded. Used by both the trip dashboard and the whole-closet gear list.
///
/// [category] is null for the synthetic "uncategorized" bucket (grouped by
/// pack type instead of a real category) — in that case [onEditCategory]/
/// [onDeleteCategory] are simply never offered, since there's no category to
/// act on.
///
/// When [packedItemIds] and [onTogglePacked] are provided, each item gets a
/// checkbox for including/excluding it from the active trip's pack — used
/// by the Gear list screen. Omit both to hide the checkboxes (Dashboard).
///
/// Tapping an item (when [onEditItem] is set) opens it for editing; a long
/// press opens a small menu offering "Дублировать" (when [onDuplicateItem]
/// is set) and a contextual destructive action (when
/// [destructiveActionLabel]/[onDestructiveAction] are set) — "Удалить" (Gear
/// list) or "Убрать из похода" (Dashboard) mean different things, so the
/// caller supplies the label rather than this widget assuming which one it
/// is. Long-pressing the header itself (when [category] and the category
/// callbacks are set) opens a similar menu for the category, not an item.
class CategoryCard extends StatefulWidget {
  const CategoryCard({
    super.key,
    required this.title,
    required this.packType,
    required this.weightGrams,
    required this.items,
    this.category,
    this.packedItemIds,
    this.onTogglePacked,
    this.onEditItem,
    this.onDuplicateItem,
    this.destructiveActionLabel,
    this.onDestructiveAction,
    this.destructiveActionDangerous = true,
    this.onEditCategory,
    this.onDeleteCategory,
    this.onAddItem,
  });

  final String title;
  final PackType packType;
  final int weightGrams;
  final List<Item> items;
  final Category? category;
  final Set<int>? packedItemIds;
  final void Function(Item item, bool packed)? onTogglePacked;
  final void Function(Item item)? onEditItem;
  final void Function(Item item)? onDuplicateItem;
  final String? destructiveActionLabel;
  final void Function(Item item)? onDestructiveAction;
  final bool destructiveActionDangerous;
  final void Function(Category category)? onEditCategory;
  final void Function(Category category)? onDeleteCategory;

  /// Offered when the category is expanded but has nothing in it yet —
  /// opens adding an item straight into this category, instead of an
  /// expand arrow that just reveals emptiness.
  final VoidCallback? onAddItem;

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _expanded = false;

  Future<void> _showCategoryMenu(BuildContext context) async {
    final category = widget.category;
    if (category == null) return;
    final canEdit = widget.onEditCategory != null;
    final canDelete = widget.onDeleteCategory != null;
    if (!canEdit && !canDelete) return;

    final box = context.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      items: [
        if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
        if (canDelete)
          PopupMenuItem(
            value: 'delete',
            child: Text('Удалить', style: TextStyle(color: AppColors.overWeight)),
          ),
      ],
    );
    if (selected == 'edit') widget.onEditCategory?.call(category);
    if (selected == 'delete') widget.onDeleteCategory?.call(category);
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    // No category at all (the "Неразобранное" catch-all) gets a neutral,
    // uncolored badge on purpose — a colorful icon here would make it look
    // like just another hand-set-up category instead of a "still needs
    // sorting" pile you can't add to or rename.
    final badgeColor = category != null
        ? lightColorForCategoryValue(category)
        : AppColors.textSecondary.withValues(alpha: 0.12);
    final iconColor =
        category != null ? colorForCategoryValue(category) : AppColors.textSecondary.withValues(alpha: 0.6);
    final icon = category != null ? iconForCategory(category) : Icons.inbox_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            onLongPress: widget.category == null ? null : () => _showCategoryMenu(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(formatKg(widget.weightGrams)),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  if (widget.items.isEmpty && widget.onAddItem == null)
                    Padding(
                      padding: const EdgeInsets.only(left: 42, right: 14, top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Пока пусто',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    if (widget.items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 42, right: 14),
                        child: Column(
                          children: [
                            for (final item in widget.items)
                              _ItemRow(
                                item: item,
                                packed: widget.packedItemIds?.contains(item.id),
                                onTogglePacked: widget.onTogglePacked,
                                onEdit: widget.onEditItem,
                                onDuplicate: widget.onDuplicateItem,
                                destructiveLabel: widget.destructiveActionLabel,
                                onDestructive: widget.onDestructiveAction,
                                destructiveDangerous: widget.destructiveActionDangerous,
                                // Only meaningful in the "Неразобранное"
                                // catch-all — a real category already says
                                // what section it's in via its own title.
                                packTypeLabel: category == null
                                    ? packTypeLabels[item.packType ?? PackType.gear]
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    // Always offered, not just when the category is empty —
                    // otherwise adding a second item means leaving the
                    // category and finding your way back in through the
                    // "+" screen instead of just tapping again right here.
                    // Aligned under the category icon rather than the item
                    // rows' own (further-indented) checkbox column, with
                    // some breathing room above it — so it reads as a
                    // category-level action, not one more line stacked
                    // onto the last item.
                    if (widget.onAddItem != null)
                      Padding(
                        padding: EdgeInsets.only(
                          left: 14,
                          right: 14,
                          top: widget.items.isEmpty ? 0 : 8,
                        ),
                        child: _AddItemRow(onAddItem: widget.onAddItem!),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A trailing "+ Добавить вещь" affordance under a category's item list —
/// shown whether the category is empty or already has items in it.
class _AddItemRow extends StatelessWidget {
  const _AddItemRow({required this.onAddItem});

  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onAddItem,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.add, size: 16, color: AppColors.accent),
            const SizedBox(width: 6),
            Text('Добавить вещь', style: TextStyle(color: AppColors.accent, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.packed,
    required this.onTogglePacked,
    required this.onEdit,
    required this.onDuplicate,
    required this.destructiveLabel,
    required this.onDestructive,
    required this.destructiveDangerous,
    this.packTypeLabel,
  });

  final Item item;
  final bool? packed;
  final String? packTypeLabel;
  final void Function(Item item, bool packed)? onTogglePacked;
  final void Function(Item item)? onEdit;
  final void Function(Item item)? onDuplicate;
  final String? destructiveLabel;
  final void Function(Item item)? onDestructive;
  final bool destructiveDangerous;

  Future<void> _showActionMenu(BuildContext context) async {
    final canEdit = onEdit != null;
    final canDuplicate = onDuplicate != null;
    final canDestroy = destructiveLabel != null && onDestructive != null;
    if (!canEdit && !canDuplicate && !canDestroy) return;

    final box = context.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      items: [
        // Tapping the row already does this — repeating it here is just
        // for discoverability, since long-press is where people look for
        // "what can I do with this" first.
        if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
        if (canDuplicate) const PopupMenuItem(value: 'duplicate', child: Text('Дублировать')),
        if (canDestroy)
          PopupMenuItem(
            value: 'destroy',
            child: Text(
              destructiveLabel!,
              style: TextStyle(
                color: destructiveDangerous ? AppColors.overWeight : AppColors.textPrimary,
              ),
            ),
          ),
      ],
    );
    if (selected == 'edit') onEdit!(item);
    if (selected == 'duplicate') onDuplicate!(item);
    if (selected == 'destroy') onDestructive!(item);
  }

  @override
  Widget build(BuildContext context) {
    final canShowMenu = onEdit != null ||
        onDuplicate != null ||
        (destructiveLabel != null && onDestructive != null);
    final conditionColor = colorForCondition(item.condition);

    // The checkbox and item name are literal siblings in one Row, and the
    // condition line is a second row indented to match — that way Flutter
    // centers checkbox-against-name on its own (same row, same height),
    // instead of us guessing an offset to line it up against a taller
    // two-line block.
    const leadWidth = 22.0;
    const leadSpacing = 3.0;
    // No checkbox at all on Dashboard (packed stays null there, always
    // set on Gear list) — don't reserve its space, or the name sits a
    // checkbox-width further from the edge than it needs to.
    final hasCheckbox = packed != null;
    final indent = hasCheckbox ? leadWidth + leadSpacing : 0.0;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      // Tap used to open editing, but a miss-tap next to the checkbox (a
      // small target) would accidentally launch it — long-press only now,
      // with "Редактировать" as an explicit menu choice instead.
      onLongPress: canShowMenu ? () => _showActionMenu(context) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              // Bottom-align the checkbox with the name text specifically
              // (not centered against the whole row) — Text's own line box
              // includes extra leading above/below the glyphs, so centering
              // a plain small box against it doesn't read as "aligned".
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasCheckbox) ...[
                  AppCheckbox(
                    value: packed!,
                    onChanged: (v) => onTogglePacked?.call(item, v),
                  ),
                  const SizedBox(width: leadSpacing),
                ],
                Expanded(
                  child: itemNameText(
                    item,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatKg(item.weightGrams * item.quantity),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: EdgeInsets.only(left: indent),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: conditionColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    conditionLabels[item.condition]!,
                    style: TextStyle(fontSize: 13, color: conditionColor),
                  ),
                  if (packTypeLabel != null)
                    Text(
                      ' · $packTypeLabel',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.55),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
