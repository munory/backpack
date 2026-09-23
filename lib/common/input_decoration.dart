import 'package:flutter/material.dart';

import 'theme.dart';

/// Fixed height every field/selector in the app is built to, so text
/// fields and pickers are pixel-identical regardless of what's inside them.
const kFieldHeight = 44.0;

/// Standard border/shape for every field and selector in the app.
final _fieldBorder = OutlineInputBorder(
  borderSide: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.2)),
);

/// The single field style used across every form in the app: outlined,
/// rounded, compact height, no floating label — labels are a plain
/// [FieldLabel] placed above the field instead, so extra elements (info
/// icons, badges) can sit next to the label without fighting the
/// decoration's internal layout.
InputDecoration appFieldDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    border: _fieldBorder,
    enabledBorder: _fieldBorder,
    focusedBorder: _fieldBorder.copyWith(
      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

/// A plain text label placed above a field instead of Material's floating
/// labelText — the standard for every form in the app. Pass [trailing] for
/// a small icon/badge next to the label (e.g. an info tooltip).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}

/// One option in an [AppSelectField].
class SelectOption<T> {
  const SelectOption(this.value, this.label, {this.depth = 0});

  final T value;
  final String label;

  /// Indentation level, for showing a category tree.
  final int depth;
}

/// A tap-to-pick field that looks exactly like [appFieldDecoration] — same
/// box, same height, same border — instead of Flutter's built-in dropdown
/// widgets, which each have their own internal sizing/positioning opinions
/// that never quite matched a plain TextField (DropdownButtonFormField's
/// menu jumps to align the selected item; DropdownMenu's box sizes itself
/// a bit differently even with a matching decoration theme). Opens a menu
/// anchored right under the field itself (the same mechanism as the weight
/// unit picker) instead of a full bottom sheet, so it reads as an ordinary
/// inline dropdown rather than another modal stacking on top of the dialog.
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
    this.menuColor,
    this.pinSelectedFirst = false,
  });

  final T value;
  final List<SelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? hint;

  /// Overrides the app-wide menu color (see [AppColors.menuSurface]) for
  /// contexts where that tone doesn't read right — e.g. a picker opening on
  /// top of an already-elevated sheet instead of the plain page background.
  final Color? menuColor;

  /// Reorders the menu so the currently selected option always appears
  /// first — handy for a short, flat list (e.g. item condition) where you
  /// want to immediately see your current choice and pick a different one
  /// without hunting for it. Leave off for a list whose order carries
  /// meaning, like a category tree, where pulling the selected item out of
  /// its place would break the hierarchy.
  final bool pinSelectedFirst;

  Future<void> _openPicker(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    );

    final orderedOptions = !pinSelectedFirst
        ? options
        : [
            ...options.where((o) => o.value == value),
            ...options.where((o) => o.value != value),
          ];

    final selected = await showMenu<T>(
      context: context,
      position: position,
      color: menuColor,
      constraints: BoxConstraints(minWidth: box.size.width, maxWidth: box.size.width),
      items: [
        for (final option in orderedOptions)
          PopupMenuItem<T>(
            value: option.value,
            child: Padding(
              padding: EdgeInsets.only(left: option.depth * 16.0),
              child: Text(
                option.label,
                style: TextStyle(
                  color: option.value == value ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: option.value == value ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
      ],
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.value == value);
    final label = selected.isEmpty ? null : selected.first.label;

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => _openPicker(context),
      child: Container(
        height: kFieldHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.fromBorderSide(_fieldBorder.borderSide),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label ?? hint ?? '',
                overflow: TextOverflow.ellipsis,
                // Match TextField's default text style (bodyLarge) exactly —
                // this widget stands in for a TextField, so its value text
                // must render at the same size/weight, not whatever size the
                // ambient DefaultTextStyle here happens to be.
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: label == null
                          ? AppColors.textSecondary.withValues(alpha: 0.6)
                          : AppColors.textPrimary,
                    ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: AppColors.textPrimary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
