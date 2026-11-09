import 'package:flutter/material.dart';

import '../data/database.dart';
import 'l10n.dart';
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

  /// The narrowest a part with any weight at all is drawn — 40 g against
  /// a 23 kg target would otherwise be less than a pixel.
  static const minPartWidth = 6.0;

  @override
  Widget build(BuildContext context) {
    final fillFraction = targetGrams == 0 ? 1.0 : (totalGrams / targetGrams).clamp(0.0, 1.0);
    final parts = [
      for (final type in PackType.values)
        if ((byType[type] ?? 0) > 0) (type: type, grams: byType[type]!),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 10,
        color: AppColors.trackBackground,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widths = partWidths(
              [for (final p in parts) p.grams],
              filled: constraints.maxWidth * fillFraction,
              available: constraints.maxWidth,
              minWidth: minPartWidth,
            );
            return Row(
              children: [
                for (var i = 0; i < parts.length; i++)
                  Container(width: widths[i], color: colorForPackType(parts[i].type)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// How wide to draw each part of a bar [filled] pixels long: in proportion
/// to its grams, but none narrower than [minWidth] — what the small parts
/// gain is taken from the big ones. Stays within [available].
@visibleForTesting
List<double> partWidths(
  List<int> grams, {
  required double filled,
  required double available,
  required double minWidth,
}) {
  if (grams.isEmpty) return const [];
  final total = grams.fold<int>(0, (a, b) => a + b);
  final floor = grams.length * minWidth < available ? grams.length * minWidth : available;
  final length = filled.clamp(floor, available).toDouble();
  if (length <= grams.length * minWidth) return [for (final _ in grams) length / grams.length];

  final widths = [for (final g in grams) length * g / total];
  final lifted = [for (final w in widths) w < minWidth ? minWidth : w];
  final excess = lifted.fold<double>(0, (a, b) => a + b) - length;
  if (excess <= 0) return lifted;
  // Taken from the parts above the minimum, in proportion to their room.
  final room = lifted.fold<double>(0, (a, w) => a + (w - minWidth));
  return [for (final w in lifted) w - (w - minWidth) / room * excess];
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
    final label = packTypeLabel(context.l10n, type);
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
            Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(formatWeight(context, grams), style: const TextStyle(fontWeight: FontWeight.w600)),
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
