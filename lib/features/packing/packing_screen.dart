import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/app_checkbox.dart';
import '../../common/item_name.dart';
import '../../common/l10n.dart';
import '../../common/theme.dart';
import '../../common/weight_format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// The night-before packing run: the active trip's list as a checklist of
/// what's physically in the bag. A separate state from being on the list at
/// all — here a tap anywhere on the row is the whole point, so it toggles
/// directly (unlike list rows elsewhere, which only react to long-press).
/// Packed items sink to the bottom of their category, so what's left to
/// pack is always on top.
class PackingScreen extends ConsumerWidget {
  const PackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(activeTripProvider).value;
    final items = ref.watch(activeTripItemsProvider).value ?? const <Item>[];
    final rows = ref.watch(activeTripRowsProvider).value ?? const <int, TripItem>{};
    final groups = ref.watch(rootCategoryTotalsProvider).where((g) => g.weightGrams > 0);
    final db = ref.read(databaseProvider);

    bool inBag(Item i) => rows[i.id]?.inBag ?? false;
    final packed = items.where(inBag).length;
    final total = items.length;
    final done = total > 0 && packed == total;
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.packingChecklist),
        actions: [
          TextButton(
            onPressed: trip == null || packed == 0 ? null : () => db.resetInBag(trip.id),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: Text(l.startOver),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            l.packingHint,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            done ? l.allPacked : l.packedProgress(packed, total),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: done ? AppColors.good : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : packed / total,
              minHeight: 8,
              backgroundColor: AppColors.trackBackground,
              color: done ? AppColors.good : AppColors.accent,
            ),
          ),
          const SizedBox(height: 20),
          for (final group in groups) ...[
            _Section(
              title: group.title ?? l.uncategorized,
              items: [
                for (final i in items)
                  if (group.category != null
                      ? i.categoryId == group.category!.id
                      : i.categoryId == null)
                    i,
              ]..sort((a, b) => (inBag(a) ? 1 : 0) - (inBag(b) ? 1 : 0)),
              inBag: inBag,
              onToggle: (item) {
                if (trip != null) db.setInBag(trip.id, item.id, !inBag(item));
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    required this.inBag,
    required this.onToggle,
  });

  final String title;
  final List<Item> items;
  final bool Function(Item) inBag;
  final void Function(Item) onToggle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final packed = items.where(inBag).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                Text(
                  '$packed/${items.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: [
                for (final item in items)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onToggle(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      child: Opacity(
                        opacity: inBag(item) ? 0.45 : 1,
                        child: Row(
                          children: [
                            AppCheckbox(value: inBag(item), onChanged: (_) => onToggle(item)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: itemNameText(
                                item,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  decoration: inBag(item) ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(formatWeight(context, itemTotalGrams(item))),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
