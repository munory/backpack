import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/choice_chip.dart';
import '../../common/input_decoration.dart';
import '../../common/l10n.dart';
import '../../common/theme.dart';
import '../../common/weight_format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// So far just the app's own light/dark and language preferences — the
/// natural home for whatever data-management actions (import, export,
/// wipe) land here next.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final l = context.l10n;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        children: [
          Text(l.profile, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          FieldLabel(l.appearance),
          _ChoiceRow<AppThemeMode>(
            notifier: appThemeMode,
            options: {
              AppThemeMode.system: l.themeSystem,
              AppThemeMode.light: l.themeLight,
              AppThemeMode.dark: l.themeDark,
            },
            onChanged: db.updateThemeMode,
          ),
          const SizedBox(height: 20),
          FieldLabel(l.language),
          // Language names stay in their own language, so they're findable
          // whichever one the app is currently in.
          _ChoiceRow<AppLanguage>(
            notifier: appLanguage,
            options: {
              AppLanguage.system: l.languageSystem,
              AppLanguage.ru: 'Русский',
              AppLanguage.en: 'English',
            },
            onChanged: db.updateLanguage,
          ),
          const SizedBox(height: 20),
          FieldLabel(l.weightUnits),
          // Until picked, the language's default shows as selected.
          _ChoiceRow<WeightUnit?>(
            notifier: appWeightUnit,
            options: {WeightUnit.metric: l.unitsMetric, WeightUnit.imperial: l.unitsImperial},
            resolve: (v) => v ?? defaultWeightUnit(l.localeName),
            onChanged: (v) => db.updateWeightUnit(v!),
          ),
        ],
      ),
    );
  }
}

/// Equal-width chips bound to a settings notifier — picking one updates the
/// app straight away and persists it via [onChanged]. [resolve] maps the
/// stored value to the chip shown selected (for "not picked yet" defaults).
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.notifier,
    required this.options,
    required this.onChanged,
    this.resolve,
  });

  final ValueNotifier<T> notifier;
  final Map<T, String> options;
  final void Function(T value) onChanged;
  final T Function(T value)? resolve;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<T>(
      valueListenable: notifier,
      builder: (context, current, _) => Row(
        children: [
          for (final (i, entry) in options.entries.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: AppChoiceChip(
                label: entry.value,
                selected: (resolve?.call(current) ?? current) == entry.key,
                onTap: () {
                  notifier.value = entry.key;
                  onChanged(entry.key);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
