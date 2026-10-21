import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/category_actions.dart';
import '../../common/category_card.dart';
import '../../common/category_form_sheet.dart';
import '../../common/empty_state.dart';
import '../../common/input_decoration.dart';
import '../../common/l10n.dart';
import '../../common/navigation.dart';
import '../../common/text_format.dart';
import '../../common/theme.dart';
import '../../common/trip_switcher.dart';
import '../../common/weight_breakdown.dart';
import '../../common/weight_format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../add_item/add_item_screen.dart';
import '../packing/packing_screen.dart';

enum _WeightView { total, base }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  _WeightView _view = _WeightView.total;

  Future<void> _showSetTargetDialog(BuildContext context, WidgetRef ref, Trip trip) async {
    final unit = weightUnitOf(context);
    final perUnit = gramsPerBigUnit(unit);
    final l = context.l10n;
    final initialText = trip.targetWeightGrams == null
        ? ''
        : formatInputNumber(trip.targetWeightGrams! / perUnit, languageCode: l.localeName);
    final controller = TextEditingController(text: initialText);
    final result = await showDialog<double?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.targetWeightTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(l.weightIn(bigUnitLabel(l, unit))),
            SizedBox(
              height: kFieldHeight,
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: appFieldDecoration(),
              ),
            ),
            if (trip.targetWeightGrams != null) ...[
              const SizedBox(height: 6),
              Text(
                l.clearTargetHint,
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  child: Text(l.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  // M3 tints a themed FilledButton's background toward the
                  // seed color's tonal palette by default, which muddies
                  // our accent — pin it to the real value, same as every
                  // other primary button.
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                  onPressed: () {
                    // Save always pops a real number — 0 stands for "cleared
                    // the field" (there's no separate remove-target button
                    // to keep the actions row from overflowing with a third
                    // button). Cancel pops null, so the two stay
                    // distinguishable.
                    final parsed = parseInputNumber(controller.text);
                    Navigator.pop(context, parsed ?? 0.0);
                  },
                  child: Text(l.save),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Saved untouched: keep the exact stored grams rather than the rounded
    // value shown (23 kg shown as 50.71 lb would come back as 23.002 kg).
    if (result == null || controller.text == initialText) return;
    final db = ref.read(databaseProvider);
    if (result <= 0) {
      await db.updateTripTarget(trip.id, null);
    } else {
      await db.updateTripTarget(trip.id, (result * perUnit).round());
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(activeTripProvider).value;
    final totalGrams = ref.watch(totalWeightProvider);
    final byType = ref.watch(weightByPackTypeProvider);
    // Categories are shared master data — unlike the Gear list (whole
    // closet), an empty category here just means nothing from it is packed
    // for this trip yet, so it shouldn't take up space on the dashboard.
    final rootTotals =
        ref.watch(rootCategoryTotalsProvider).where((e) => e.weightGrams > 0).toList();
    final itemsAsync = ref.watch(activeTripItemsProvider);
    // The trip's items carry the *trip's* quantity (see
    // activeTripItemsProvider); editing or copying must start from the
    // real closet row, or saving would overwrite how many you own.
    final closetById = {
      for (final i in ref.watch(allItemsProvider).value ?? const <Item>[]) i.id: i,
    };
    final l = context.l10n;

    if (rootTotals.isEmpty) {
      final empty = EmptyStateView(
        icon: Icons.backpack_outlined,
        title: l.emptyPackTitle,
        subtitle: l.emptyPackSubtitle,
        ctaLabel: l.goToInventory,
        ctaIcon: Icons.arrow_forward,
        onCta: () => ref.read(currentTabProvider.notifier).state = 1,
      );
      if (trip == null) return empty;
      // Keep the trip switcher even on an empty trip — a freshly created
      // trip starts empty, and you may just want to switch back.
      return SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _TripSwitcher(trip: trip),
            ),
            Expanded(child: empty),
          ],
        ),
      );
    }

    final targetGrams = trip!.targetWeightGrams;
    final isOverweight = targetGrams != null && totalGrams > targetGrams;
    // Everything except food/water — the number ultralight folks actually
    // compare trip to trip, since food and water get eaten/drunk and don't
    // reflect what your gear itself weighs.
    final baseWeightGrams =
        totalGrams - (byType[PackType.food] ?? 0) - (byType[PackType.water] ?? 0);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        children: [
          _TripSwitcher(trip: trip),
          const SizedBox(height: 12),
          HeroWeightCard(
            child: Column(
              // Without this, WeightBar (and anything else with no intrinsic
              // width of its own) shrinks to a tiny natural size instead of
              // spanning the card — this is what was making the progress
              // bar render as a broken little pill.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: _WeightViewToggle(
                    value: _view,
                    onChanged: (v) => setState(() => _view = v),
                  ),
                ),
                const SizedBox(height: 8),
                if (_view == _WeightView.total) ...[
                  Center(
                    child: Text(
                      targetGrams == null
                          ? formatWeight(context, totalGrams)
                          : '${formatWeight(context, totalGrams)} ⁄ ${formatWeight(context, targetGrams)}',
                      style: weightDisplayStyle(isOverweight: isOverweight),
                    ),
                  ),
                  Center(
                    child: InkWell(
                      onTap: () => _showSetTargetDialog(context, ref, trip),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                        child: Text(
                          targetGrams == null ? l.setTarget : l.changeTarget,
                          style: TextStyle(color: AppColors.accent, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Center(
                    child: Text(
                      formatWeight(context, baseWeightGrams),
                      style: weightDisplayStyle(isOverweight: false),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Center(
                    child: Text(
                      l.baseWeightHint,
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                WeightBar(byType: byType, totalGrams: totalGrams, targetGrams: targetGrams ?? totalGrams),
                const SizedBox(height: 14),
                WeightLegend(byType: byType),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _PackingButton(rows: ref.watch(activeTripRowsProvider).value ?? const {}),
          const SizedBox(height: 20),
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
              onEditItem: (item) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddItemScreen(editing: closetById[item.id] ?? item),
                ),
              ),
              onDuplicateItem: (item) async {
                final duplicated = await ref
                    .read(databaseProvider)
                    .duplicateItem(closetById[item.id] ?? item, copyWord: l.copyWord);
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AddItemScreen(editing: duplicated)),
                  );
                }
              },
              ownedQuantities: {for (final e in closetById.entries) e.key: e.value.quantity},
              onTripQuantityChanged: (item, quantity) {
                final owned = closetById[item.id]?.quantity;
                // Back at "all of them" → store null, so raising the closet
                // quantity later still means "take all" on this trip.
                ref.read(databaseProvider).setTripItemQuantity(
                      trip.id,
                      item.id,
                      quantity == owned ? null : quantity,
                    );
              },
              destructiveActionLabel: l.removeFromTrip,
              destructiveActionDangerous: false,
              onDestructiveAction: (item) =>
                  ref.read(databaseProvider).setItemPacked(item.id, false),
              onEditCategory: (category) => showCategoryFormSheet(context, editing: category),
              onDeleteCategory: (category) => deleteCategoryWithConfirmation(
                context,
                ref.read(databaseProvider),
                category,
              ),
            ),
        ],
      ),
    );
  }
}

/// iOS-style two-segment pill for switching the hero number between total
/// weight and base weight (everything except food/water) — only one big
/// number shown at a time, instead of stacking both permanently.
class _WeightViewToggle extends StatelessWidget {
  const _WeightViewToggle({required this.value, required this.onChanged});

  final _WeightView value;
  final ValueChanged<_WeightView> onChanged;

  Widget _segment(_WeightView segment, String label) {
    final selected = value == segment;
    return GestureDetector(
      onTap: () => onChanged(segment),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.trackBackground,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(_WeightView.total, context.l10n.totalWeight),
          _segment(_WeightView.base, context.l10n.baseWeight),
        ],
      ),
    );
  }
}


/// "Карелия на выходные ▾ · 12–14 окт" above the weight card — tap to jump
/// to another trip without leaving Главная. An anchored menu rather than a
/// sheet, same as every other picker in the app.
class _TripSwitcher extends ConsumerWidget {
  const _TripSwitcher({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final dates = formatTripDates(trip.startDate, trip.endDate, languageCode: l.localeName);
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showTripSwitcherMenu(context, ref, trip),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      tripName(l, trip),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                ],
              ),
              if (dates != null)
                Text(
                  dates,
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Чек-лист сборов · 12 из 30" — opens the packing checklist. The
/// subtitle is there because "packing" alone was easy to mistake for the
/// Инвентарь checkboxes (which plan the list, not tick off the bag).
class _PackingButton extends StatelessWidget {
  const _PackingButton({required this.rows});

  final Map<int, TripItem> rows;

  @override
  Widget build(BuildContext context) {
    final total = rows.length;
    final packed = rows.values.where((r) => r.inBag).length;
    final done = total > 0 && packed == total;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PackingScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle_outline : Icons.checklist,
                color: done ? AppColors.good : AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      done ? context.l10n.packDone : context.l10n.packingChecklist,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      context.l10n.packingSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                context.l10n.nOfM(packed, total),
                style: TextStyle(
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: AppColors.textSecondary.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
