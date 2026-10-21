import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/category_actions.dart';
import '../../common/category_card.dart';
import '../../common/category_form_sheet.dart';
import '../../common/empty_state.dart';
import '../../common/input_decoration.dart';
import '../../common/item_name.dart';
import '../../common/l10n.dart';
import '../../common/theme.dart';
import '../../common/trip_switcher.dart';
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

/// Ordering the flat filtered list applies on top of matching — [none]
/// keeps whatever order the items came back in.
enum _WeightSort { none, ascending, descending }

class _GearListScreenState extends ConsumerState<GearListScreen> {
  final _searchController = TextEditingController();
  ItemCondition? _conditionFilter;
  PackType? _packTypeFilter;
  _WeightSort _weightSort = _WeightSort.none;

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
    final l = context.l10n;

    if (rootTotals.isEmpty) {
      return EmptyStateView(
        icon: Icons.inventory_2_outlined,
        title: l.emptyInventory,
        ctaLabel: l.addFirstItem,
        ctaIcon: Icons.add,
        onCta: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddItemScreen()),
        ),
      );
    }

    final itemCount = itemsAsync.value?.length ?? 0;
    final categoryCount = rootTotals.length;
    final query = _searchController.text.trim().toLowerCase();
    final hasActiveFilter =
        _conditionFilter != null || _packTypeFilter != null || _weightSort != _WeightSort.none;
    final showFlatList = query.isNotEmpty || hasActiveFilter;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        children: [
          Text(
            l.myInventory,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatWeight(context, totalGrams)} · ${l.itemCount(itemCount)} · '
            '${l.categoryCount(categoryCount)}',
            style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 13),
          ),
          if (ref.watch(activeTripProvider).value case final trip?) ...[
            const SizedBox(height: 8),
            _PackingForLine(trip: trip),
          ],
          const SizedBox(height: 16),
          // Only worth surfacing once there's enough in the closet that
          // scanning the whole list stops being the fastest way to find
          // something.
          if (itemCount >= 8)
            SizedBox(
              height: kFieldHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: appFieldDecoration(hint: l.searchHint).copyWith(
                        prefixIcon:
                            Icon(Icons.search, color: AppColors.textPrimary.withValues(alpha: 0.6)),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(_searchController.clear),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _FilterIconButton(
                    active: hasActiveFilter,
                    onTap: () => _openFilterSheet(context, itemsAsync.value ?? const [], categoryById, query),
                  ),
                ],
              ),
            ),
          if (itemCount >= 8) const SizedBox(height: 16),
          if (showFlatList)
            ..._filteredItemRows(context, query, itemsAsync.value ?? const [], categoryById)
          else
            for (final entry in rootTotals)
              CategoryCard(
                title: entry.title ?? l.uncategorized,
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
                  final duplicated = await db.duplicateItem(item, copyWord: l.copyWord);
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => AddItemScreen(editing: duplicated)),
                    );
                  }
                },
                destructiveActionLabel: l.delete,
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
                onDeleteCategory: (category) =>
                    deleteCategoryWithConfirmation(context, db, category),
              ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet(
    BuildContext context,
    List<Item> allItems,
    Map<int, Category> categoryById,
    String query,
  ) async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _FilterSheet(
          initialCondition: _conditionFilter,
          initialPackType: _packTypeFilter,
          initialSort: _weightSort,
          allItems: allItems,
          categoryById: categoryById,
          query: query,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _conditionFilter = result.condition;
        _packTypeFilter = result.packType;
        _weightSort = result.sort;
      });
    }
  }

  /// The flat, non-grouped-by-category list shown whenever a search query
  /// or any filter/sort is active — grouping by category doesn't make sense
  /// once you're asking "show me everything that's under repair" or "what's
  /// heaviest across the whole closet", so this drops the category cards in
  /// favor of one ordered list with each item's category named inline.
  List<Widget> _filteredItemRows(
    BuildContext context,
    String query,
    List<Item> allItems,
    Map<int, Category> categoryById,
  ) {
    var matches = allItems
        .where((i) => matchesFilters(
              i,
              categoryById,
              query: query,
              condition: _conditionFilter,
              packType: _packTypeFilter,
            ))
        .toList();

    if (_weightSort != _WeightSort.none) {
      matches.sort((a, b) => itemTotalGrams(a).compareTo(itemTotalGrams(b)));
      if (_weightSort == _WeightSort.descending) matches = matches.reversed.toList();
    }

    if (matches.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              context.l10n.nothingFound,
              style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7)),
            ),
          ),
        ),
      ];
    }
    return [
      for (final item in matches)
        _FilteredItemRow(
          item: item,
          categoryName: item.categoryId == null
              ? context.l10n.noCategory
              : categoryById[item.categoryId]?.name,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AddItemScreen(editing: item)),
          ),
        ),
    ];
  }
}

/// Shared by the flat list and the filter sheet's live count, so the two
/// never quietly drift apart on what "matches" means. Public (not
/// `_`-prefixed) so it's unit-testable directly — see test/filters_test.dart.
bool matchesFilters(
  Item item,
  Map<int, Category> categoryById, {
  required String query,
  required ItemCondition? condition,
  required PackType? packType,
}) {
  if (query.isNotEmpty && !item.name.toLowerCase().contains(query)) return false;
  if (condition != null && item.condition != condition) return false;
  if (packType != null && effectivePackType(item, categoryById) != packType) return false;
  return true;
}

/// The filter sheet's answer — null from [showModalBottomSheet] (dismissed
/// without confirming) means "leave the current filters alone".
typedef _FilterResult = ({ItemCondition? condition, PackType? packType, _WeightSort sort});

/// Square button matching a text field's height, opening the filter sheet.
/// The small dot is the only thing on the main screen that still hints a
/// filter is active — everything else about it lives in the sheet now.
class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Container(
        width: kFieldHeight,
        height: kFieldHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.2)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.tune, color: AppColors.textPrimary.withValues(alpha: 0.7)),
            if (active)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: AppColors.overWeight, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The filters bottom sheet — condition/section/sort as outlined chips
/// (same look as the Раздел picker elsewhere: outline + accent text when
/// selected, no fill), with a live "Показать (N вещей)" count so the count
/// updates before committing to anything. Nothing here touches the
/// screen's actual filter state until "Показать" is pressed — dismissing
/// the sheet any other way discards the draft.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initialCondition,
    required this.initialPackType,
    required this.initialSort,
    required this.allItems,
    required this.categoryById,
    required this.query,
  });

  final ItemCondition? initialCondition;
  final PackType? initialPackType;
  final _WeightSort initialSort;
  final List<Item> allItems;
  final Map<int, Category> categoryById;
  final String query;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ItemCondition? _condition = widget.initialCondition;
  late PackType? _packType = widget.initialPackType;
  late _WeightSort _sort = widget.initialSort;

  int get _matchCount => widget.allItems
      .where((i) => matchesFilters(
            i,
            widget.categoryById,
            query: widget.query,
            condition: _condition,
            packType: _packType,
          ))
      .length;

  /// A fixed-height grid tile rather than a Wrap chip — text truncates
  /// instead of wrapping, so every tile in a row stays the same height
  /// regardless of label length, and callers lay them out in equal-width
  /// [Expanded]s for a clean grid instead of ragged, content-sized chips.
  Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: kFieldHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.textPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? AppColors.accent : AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Two equal-width tiles side by side — the grid unit every filter
  /// section below is built from.
  Widget _chipRow(List<Widget> chips) {
    return Row(
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: chips[i]),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _matchCount;
    final l = context.l10n;
    Widget conditionChip(ItemCondition c) => _chip(
          conditionLabel(l, c),
          _condition == c,
          () => setState(() => _condition = c),
        );
    Widget packTypeChip(PackType t) => _chip(
          packTypeLabel(l, t),
          _packType == t,
          () => setState(() => _packType = t),
        );

    return SafeArea(
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
            Row(
              children: [
                Text(
                  l.filters,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _condition = null;
                    _packType = null;
                    _sort = _WeightSort.none;
                  }),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  child: Text(l.resetAll),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FieldLabel(l.sort),
            _chipRow([
              _chip(l.lightestFirst, _sort == _WeightSort.ascending,
                  () => setState(() => _sort = _WeightSort.ascending),
                  icon: Icons.arrow_upward),
              _chip(l.heaviestFirst, _sort == _WeightSort.descending,
                  () => setState(() => _sort = _WeightSort.descending),
                  icon: Icons.arrow_downward),
            ]),
            const SizedBox(height: 8),
            _chip(l.defaultOrder, _sort == _WeightSort.none,
                () => setState(() => _sort = _WeightSort.none)),
            const SizedBox(height: 20),
            FieldLabel(l.condition),
            _chipRow([
              _chip(l.all, _condition == null, () => setState(() => _condition = null)),
              conditionChip(conditionOrder[0]),
            ]),
            const SizedBox(height: 8),
            _chipRow([conditionChip(conditionOrder[1]), conditionChip(conditionOrder[2])]),
            const SizedBox(height: 20),
            FieldLabel(l.section),
            _chipRow([
              _chip(l.all, _packType == null, () => setState(() => _packType = null)),
              packTypeChip(PackType.food),
              packTypeChip(PackType.water),
            ]),
            const SizedBox(height: 8),
            // "Снаряжение" alone, full width — same pyramid PackTypeChips
            // uses for its longest label instead of squeezing 4 equal
            // columns and truncating it.
            packTypeChip(PackType.gear),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                (condition: _condition, packType: _packType, sort: _sort),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: Text(l.showItems(l.itemCount(count))),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredItemRow extends StatelessWidget {
  const _FilteredItemRow({required this.item, required this.categoryName, required this.onTap});

  final Item item;
  final String? categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final conditionColor = colorForCondition(item.condition);
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
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: conditionColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          conditionLabel(context.l10n, item.condition),
                          style: TextStyle(fontSize: 13, color: conditionColor),
                        ),
                        if (categoryName != null)
                          Text(
                            ' · $categoryName',
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(formatWeight(context, item.weightGrams * item.quantity)),
            ],
          ),
        ),
      ),
    );
  }
}


/// "Собираю для: Karelia ▾" — says which trip the checkboxes below add to,
/// which otherwise isn't visible anywhere on this screen. Tap to switch.
class _PackingForLine extends ConsumerWidget {
  const _PackingForLine({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showTripSwitcherMenu(context, ref, trip),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.packingFor,
                style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 14),
              ),
              Flexible(
                child: Text(
                  tripName(context.l10n, trip),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.expand_more, size: 18, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}
