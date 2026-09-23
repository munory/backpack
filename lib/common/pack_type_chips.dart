import 'package:flutter/material.dart';

import '../data/database.dart';
import 'theme.dart';

/// The Food/Water/Gear picker used both for a category's "Раздел" and for
/// an item's own Раздел when it has no category. Pyramid layout: Food and
/// Water side by side, Gear full width below (base weight vs consumables).
class PackTypeChips extends StatelessWidget {
  const PackTypeChips({super.key, required this.value, required this.onChanged});

  final PackType value;
  final ValueChanged<PackType> onChanged;

  Widget _chip(PackType type, String label) {
    final selected = value == type;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(type),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // No fill at all — that treatment is reserved for the primary
          // action button, so a selected toggle here doesn't read as
          // another button to press. Just the outline + text.
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.textPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _chip(PackType.food, 'Еда')),
            const SizedBox(width: 8),
            Expanded(child: _chip(PackType.water, 'Вода')),
          ],
        ),
        const SizedBox(height: 8),
        _chip(PackType.gear, 'Снаряжение'),
      ],
    );
  }
}
