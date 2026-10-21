import 'package:flutter/material.dart';

import '../data/database.dart';
import 'l10n.dart';
import 'theme.dart';

/// An item's name, with a muted "(N шт.)" suffix when there's more than
/// one — a separate color/weight from the name itself, so the count reads
/// as metadata rather than part of the name (unlike the earlier plain
/// "Name ×2", which read as one run of text in the same style).
///
/// Always a single line, truncated with an ellipsis — a long name is
/// expected to sit in a row that bottom-aligns a checkbox against the
/// name's own line box, and a wrapped second line broke that alignment
/// (the checkbox rode down to the wrapped line, next to "шт.)" instead of
/// the name itself).
/// [showQuantity] false drops the suffix where something else (the trip
/// quantity picker) already shows the count.
Widget itemNameText(Item item, {required TextStyle style, bool showQuantity = true}) {
  if (item.quantity <= 1 || !showQuantity) {
    return Text(item.name, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
  // A Builder only to reach the current language — keeps this a plain
  // function rather than making every caller pass a context in.
  return Builder(
    builder: (context) => Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: item.name),
          TextSpan(
            text: ' ${context.l10n.quantitySuffix(item.quantity)}',
            style: TextStyle(
              fontWeight: FontWeight.normal,
              color: AppColors.textSecondary.withValues(alpha: 0.55),
              fontSize: (style.fontSize ?? 14) - 1,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}
