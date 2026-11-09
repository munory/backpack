import 'package:flutter/material.dart';

import '../data/database.dart';
import 'app_checkbox.dart';
import 'l10n.dart';
import 'theme.dart';

/// Deletes an item for good — after asking, unless "Больше не спрашивать"
/// was ticked once (Профиль turns the question back on).
Future<void> deleteItemWithConfirmation(BuildContext context, AppDatabase db, Item item) async {
  final settings = await db.select(db.appSettings).getSingle();
  if (settings.confirmItemDelete) {
    if (!context.mounted) return;
    final l = context.l10n;
    var dontAsk = false;
    final ok = await _confirm(
      context,
      title: l.deleteItemTitle(item.name),
      body: l.cantBeUndone,
      extra: StatefulBuilder(
        builder: (context, setState) => InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => dontAsk = !dontAsk),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                AppCheckbox(value: dontAsk, onChanged: (v) => setState(() => dontAsk = v)),
                const SizedBox(width: 8),
                Text(l.dontAskAgain, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
    if (!ok) return;
    if (dontAsk) await db.updateConfirmItemDelete(false);
  }
  await db.deleteItem(item.id);
}

/// Deletes a category — always asking first: everything in it would lose
/// its place at once. One with subcategories isn't deleted at all (they go
/// first), and that's said instead of asking.
Future<void> deleteCategoryWithConfirmation(
  BuildContext context,
  AppDatabase db,
  Category category,
) async {
  final hasChildren =
      await (db.select(db.categories)..where((c) => c.parentId.equals(category.id))).get();
  if (!context.mounted) return;
  final l = context.l10n;
  if (hasChildren.isNotEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          l.categoryHasChildren,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.gotIt)),
        ],
      ),
    );
    return;
  }
  if (await _confirm(context, title: l.deleteCategoryTitle(category.name), body: l.deleteCategoryBody)) {
    await db.deleteCategory(category.id);
  }
}

/// "Delete X?" with Отмена and a red Удалить — true if confirmed.
Future<bool> _confirm(BuildContext context, {required String title, required String body, Widget? extra}) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          if (extra != null) ...[const SizedBox(height: 12), extra],
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                child: Text(l.cancel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.overWeight),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.delete),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return ok ?? false;
}
