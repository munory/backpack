import 'package:flutter/material.dart';

import '../data/database.dart';
import 'theme.dart';
import 'weight_format.dart';

/// Segmented progress bar showing how much of [targetGrams] each pack type
/// (Food/Gear/Water) contributes, filled up to the actual [totalGrams].
class WeightBar extends StatelessWidget {
  const WeightBar({
    super.key,
    required this.byType,
    required this.totalGrams,
    required this.targetGrams,
  });

  final Map<PackType, int> byType;
  final int totalGrams;
  final int targetGrams;

  @override
  Widget build(BuildContext context) {
    final fillFraction = targetGrams == 0 ? 1.0 : (totalGrams / targetGrams).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 10,
        color: AppColors.trackBackground,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fillFraction,
          child: Row(
            children: [
              for (final type in PackType.values)
                if ((byType[type] ?? 0) > 0)
                  Expanded(
                    flex: byType[type]!,
                    child: Container(color: colorForPackType(type)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Food / Gear / Water legend with a color dot and weight under each label,
/// paired with [WeightBar] under the hero weight number.
class WeightLegend extends StatelessWidget {
  const WeightLegend({super.key, required this.byType});

  final Map<PackType, int> byType;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final type in PackType.values) _LegendItem(type: type, grams: byType[type] ?? 0),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.type, required this.grams});

  final PackType type;
  final int grams;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      PackType.food => 'Еда',
      PackType.gear => 'Снаряжение',
      PackType.water => 'Вода',
    };
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: colorForPackType(type), shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(formatKg(grams), style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// The rounded, shadowed card the Dashboard's hero weight block sits in —
/// visually separates the summary from the page background and the
/// category list below it. Gear list deliberately doesn't use this — it's
/// a plain browsing/organizing screen, not a glanceable status screen.
class HeroWeightCard extends StatelessWidget {
  const HeroWeightCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
  }
}
