import 'package:flutter/material.dart';

import 'theme.dart';

/// A round "packed" toggle matching the app's soft, rounded visual language
/// — a square (even with rounded corners) reads as a generic form control
/// next to everything else here, which is all circles/pills/soft curves.
///
/// Classic radio-button styling: a ring that's always visible, with a
/// smaller filled dot appearing inside it once selected — not the whole
/// circle turning into a solid block.
///
/// [partial] is the third state for a whole category: some of it, not all —
/// a short dash in the ring. Tapping it selects all.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({super.key, required this.value, required this.onChanged, this.partial = false});

  final bool value;
  final bool partial;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(partial || !value),
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
                color: value || partial ? AppColors.accent : AppColors.textPrimary.withValues(alpha: 0.25),
                width: 1.3,
              ),
            ),
            child: Center(
              child: partial && !value
                  ? Container(
                      width: 7,
                      height: 1.6,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    )
                  : AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: value ? 8 : 0,
                      height: value ? 8 : 0,
                      decoration: BoxDecoration(
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
