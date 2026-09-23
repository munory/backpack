import 'package:flutter/material.dart';

import 'theme.dart';

/// A round "packed" toggle matching the app's soft, rounded visual language
/// — a square (even with rounded corners) reads as a generic form control
/// next to everything else here, which is all circles/pills/soft curves.
///
/// Classic radio-button styling: a ring that's always visible, with a
/// smaller filled dot appearing inside it once selected — not the whole
/// circle turning into a solid block.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 22,
        height: 22,
        child: Center(
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: value ? AppColors.accent : AppColors.textPrimary.withValues(alpha: 0.25),
                width: 1.3,
              ),
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: value ? 8 : 0,
                height: value ? 8 : 0,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
