import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/category_card.dart';
import '../../common/category_form_sheet.dart';
import '../../common/empty_state.dart';
import '../../common/input_decoration.dart';
import '../../common/item_name.dart';
import '../../common/theme.dart';
import '../../common/weight_format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../add_item/add_item_screen.dart';

/// The master gear closet — everything the user owns, independent of any
/// trip. This is what a brand-new user lands on, not the trip dashboard.
///
/// Deliberately plain up top (no hero number, no chart) — that treatment is
/// Dashboard's job (glanceable trip status). This screen is for organizing
/// and browsing the whole closet, so it just states the totals in passing.
class GearListScreen extends ConsumerStatefulWidget {
  const GearListScreen({super.key});

  @override
  ConsumerState<GearListScreen> createState() => _GearListScreenState();
}

class _GearListScreenState extends ConsumerState<GearListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalGrams = ref.watch(closetTotalWeightProvider);
    final rootTotals = ref.watch(closetRootCategoryTotalsProvider);
    final itemsAsync = ref.watch(allItemsProvider);
    final packedItemIds = ref.watch(activeTripItemIdsProvider);
    final db = ref.read(databaseProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final categoryById = {for (final c in categories) c.id: c};

    if (rootTotals.isEmpty) {
      return EmptyStateView(
        icon: Icons.inventory_2_outlined,
        title: 'Твой инвентарь пуст',
        ctaLabel: 'Добавить первую вещь',
        ctaIcon: Icons.add,
        onCta: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddItemScreen()),
        ),
      );
    }

    final itemCount = itemsAsync.value?.length ?? 0;
    final categoryCount = rootTotals.length;
    final query = _searchController.text.trim().toLowerCase();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        children: [
          Text(
            'Мой инвентарь',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatKg(totalGrams)} · $itemCount ${_itemWord(itemCount)} · '
            '$categoryCount ${_categoryWord(categoryCount)}',
            style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Only worth surfacing once there's enough in the closet that
          // scanning the whole list stops being the fastest way to find
          // something.
          if (itemCount >= 8)
            SizedBox(
              height: kFieldHeight,
              child: TextField(
                controller: _searchController,
                decoration: appFieldDecoration(hint: 'Найти вещь…').copyWith(
                  prefixIcon: Icon(Icons.search, color: AppColors.textPrimary.withValues(alpha: 0.6)),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(_searchController.clear),
                        ),
                ),
              ),
            ),
          if (itemCount >= 8) const SizedBox(height: 16),
          if (query.isNotEmpty)
            ..._searchResults(context, query, itemsAsync.value ?? const [], categoryById)
          else
            for (final entry in rootTotals)
              CategoryCard(
                title: entry.title,
                packType: entry.packType,
                category: entry.category,
                weightGrams: entry.weightGrams,
                items: (itemsAsync.value ?? const [])
                    .where((i) => entry.category != null
                        ? i.categoryId == entry.category!.id
                        : i.categoryId == null)
                    .toList(),
                packedItemIds: packedItemIds,
                onTogglePacked: (item, packed) => db.setItemPacked(item.id, packed),
                onEditItem: (item) => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AddItemScreen(editing: item)),
                ),
                onDuplicateItem: (item) async {
                  final duplicated = await db.duplicateItem(item);
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => AddItemScreen(editing: duplicated)),
                    );
                  }
                },
                destructiveActionLabel: 'Удалить',
                onDestructiveAction: (item) => db.deleteItem(item.id),
                onAddItem: entry.category == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AddItemScreen(initialCategoryId: entry.category!.id),
                          ),
                        ),
                onEditCategory: (category) => showCategoryFormSheet(context, editing: category),
                onDeleteCategory: (category) async {
                  final ok = await db.deleteCategory(category.id);
                  if (!ok && context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        content: const Text(
                          'Сначала удали или перенеси дочерние категории — '
                          'у этой категории ещё есть вложенные.',
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
                },
              ),
        ],
      ),
    );
  }

  List<Widget> _searchResults(
    BuildContext context,
    String query,
    List<Item> allItems,
    Map<int, Category> categoryById,
  ) {
    final matches = allItems.where((i) => i.name.toLowerCase().contains(query)).toList();
    if (matches.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Ничего не нашлось',
              style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7)),
            ),
          ),
        ),
      ];
    }
    return [
      for (final item in matches)
        _SearchResultRow(
          item: item,
          categoryName: item.categoryId == null ? 'Без категории' : categoryById[item.categoryId]?.name,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AddItemScreen(editing: item)),
          ),
        ),
    ];
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.item, required this.categoryName, required this.onTap});

  final Item item;
  final String? categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    itemNameText(item, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (categoryName != null)
                      Text(
                        categoryName!,
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Text(formatKg(item.weightGrams * item.quantity)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Russian plural forms depend on the last one/two digits, not just "1 vs
/// many" — 21 вещь, 22 вещи, 25 вещей.
String _pluralize(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return few;
  return many;
}

String _itemWord(int n) => _pluralize(n, 'вещь', 'вещи', 'вещей');
String _categoryWord(int n) => _pluralize(n, 'категория', 'категории', 'категорий');
