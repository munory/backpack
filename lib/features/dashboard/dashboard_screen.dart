import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/category_card.dart';
import '../../common/category_form_sheet.dart';
import '../../common/empty_state.dart';
import '../../common/input_decoration.dart';
import '../../common/navigation.dart';
import '../../common/theme.dart';
import '../../common/weight_breakdown.dart';
import '../../common/weight_format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../add_item/add_item_screen.dart';

enum _WeightView { total, base }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  _WeightView _view = _WeightView.total;

  Future<void> _showSetTargetDialog(BuildContext context, WidgetRef ref, Trip trip) async {
    final controller = TextEditingController(
      text: trip.targetWeightGrams == null
          ? ''
          : (trip.targetWeightGrams! / 1000).toString(),
    );
    final result = await showDialog<double?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Целевой вес рюкзака'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Вес (кг)'),
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
                '0 или пусто — убрать цель',
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
                  child: const Text('Отмена'),
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
                    final parsed = double.tryParse(controller.text.replaceAll(',', '.'));
                    Navigator.pop(context, parsed ?? 0.0);
                  },
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (result == null) return;
    final db = ref.read(databaseProvider);
    if (result <= 0) {
      await db.updateTripTarget(trip.id, null);
    } else {
      await db.updateTripTarget(trip.id, (result * 1000).round());
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

    if (rootTotals.isEmpty) {
      return EmptyStateView(
        icon: Icons.backpack_outlined,
        title: 'Твой рюкзак пуст',
        subtitle: 'Отметь снаряжение как "в рюкзаке" в Инвентаре, чтобы увидеть вес.',
        ctaLabel: 'Перейти в Инвентарь',
        ctaIcon: Icons.arrow_forward,
        onCta: () => ref.read(currentTabProvider.notifier).state = 1,
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
                          ? formatKg(totalGrams)
                          : '${formatKg(totalGrams)} ⁄ ${formatKg(targetGrams)}',
                      style: weightDisplayStyle(isOverweight: isOverweight),
                    ),
                  ),
                  Center(
                    child: InkWell(
                      onTap: () => _showSetTargetDialog(context, ref, trip),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                        child: Text(
                          targetGrams == null ? 'Задать целевой вес' : 'Изменить целевой вес',
                          style: TextStyle(color: AppColors.accent, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Center(
                    child: Text(
                      formatKg(baseWeightGrams),
                      style: weightDisplayStyle(isOverweight: false),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Center(
                    child: Text(
                      'Только снаряжение и рюкзак — без еды и воды',
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
          const SizedBox(height: 20),
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
              onEditItem: (item) => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddItemScreen(editing: item)),
              ),
              onDuplicateItem: (item) async {
                final duplicated = await ref.read(databaseProvider).duplicateItem(item);
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AddItemScreen(editing: duplicated)),
                  );
                }
              },
              destructiveActionLabel: 'Убрать из похода',
              destructiveActionDangerous: false,
              onDestructiveAction: (item) =>
                  ref.read(databaseProvider).setItemPacked(item.id, false),
              onEditCategory: (category) => showCategoryFormSheet(context, editing: category),
              onDeleteCategory: (category) async {
                final ok = await ref.read(databaseProvider).deleteCategory(category.id);
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
          _segment(_WeightView.total, 'Общий вес'),
          _segment(_WeightView.base, 'Базовый'),
        ],
      ),
    );
  }
}

