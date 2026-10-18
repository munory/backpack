import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/choice_chip.dart';
import '../../common/input_decoration.dart';
import '../../common/theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// So far just the app's own light/dark preference — the natural home for
/// whatever data-management actions (import, export, wipe) land here next.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        children: [
          const Text('Профиль', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          const FieldLabel('Внешний вид'),
          ValueListenableBuilder<AppThemeMode>(
            valueListenable: appThemeMode,
            builder: (context, mode, _) {
              Widget option(AppThemeMode value, String label) {
                return Expanded(
                  child: AppChoiceChip(
                    label: label,
                    selected: mode == value,
                    onTap: () {
                      appThemeMode.value = value;
                      db.updateThemeMode(value);
                    },
                  ),
                );
              }

              return Row(
                children: [
                  option(AppThemeMode.system, 'Системная'),
                  const SizedBox(width: 8),
                  option(AppThemeMode.light, 'Светлая'),
                  const SizedBox(width: 8),
                  option(AppThemeMode.dark, 'Тёмная'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
