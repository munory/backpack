import 'package:flutter/material.dart';

import '../data/database.dart';
import 'l10n.dart';
import 'theme.dart';

/// Deletes a category, showing the "has children" error dialog if it
/// refuses — shared by Dashboard and Inventory so the two don't drift out
/// of sync the next time this wording or behavior changes.
Future<void> deleteCategoryWithConfirmation(
  BuildContext context,
  AppDatabase db,
  Category category,
) async {
  final ok = await db.deleteCategory(category.id);
  if (!ok && context.mounted) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          context.l10n.categoryHasChildren,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.gotIt),
          ),
        ],
      ),
    );
  }
}
