import 'package:flutter/material.dart';

import 'theme.dart';

/// The app's main call-to-action button: full width, accent-colored, with a
/// soft glow in the same hue instead of a default dark elevation shadow.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final style = FilledButton.styleFrom(
      backgroundColor: enabled ? AppColors.accent : null,
      padding: const EdgeInsets.symmetric(vertical: 14),
      overlayColor: Colors.black.withValues(alpha: 0.15),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
    final labelWidget = Text(label);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: SizedBox(
        width: double.infinity,
        child: icon == null
            ? FilledButton(style: style, onPressed: onPressed, child: labelWidget)
            : FilledButton.icon(
                style: style,
                onPressed: onPressed,
                icon: Icon(icon, size: 20),
                label: labelWidget,
              ),
      ),
    );
  }
}
