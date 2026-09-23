import 'package:flutter/material.dart';

import '../data/database.dart';
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
Widget itemNameText(Item item, {required TextStyle style}) {
  if (item.quantity <= 1) {
    return Text(item.name, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
  return Text.rich(
    TextSpan(
      style: style,
      children: [
        TextSpan(text: item.name),
        TextSpan(
          text: ' (${item.quantity} шт.)',
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
  );
}
