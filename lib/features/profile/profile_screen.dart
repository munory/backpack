import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../common/l10n.dart';
import '../../common/navigation.dart';
import '../../common/theme.dart';
import '../../common/weight_format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../data_transfer/export_file.dart';
import '../data_transfer/gear_csv.dart';
import '../data_transfer/gear_xlsx.dart';

/// A summary of the whole closet up top, then plain grouped lists: data
/// (import/export), settings, and about. Settings rows show their current
/// value and open an anchored menu, like every other picker in the app.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final l = context.l10n;
    final hasItems = (ref.watch(allItemsProvider).value ?? const []).isNotEmpty;
    final languageNames = {
      AppLanguage.system: l.languageSystem,
      // Language names stay in their own language, so they're findable
      // whichever one the app is currently in.
      AppLanguage.ru: 'Русский',
      AppLanguage.en: 'English',
    };

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Text(l.profile, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          // Not `const` — it must rebuild to pick up a theme change (see
          // BackpackApp in main.dart).
          _SummaryCard(),
          _SectionLabel(l.sectionData),
          _Group(children: [
            _Row(label: l.importFromFile, comingSoon: true),
            // Two exports for two jobs: Excel to read and work with the
            // list (opens right in any Excel, whatever its regional
            // settings), CSV to move it into LighterPack.
            _ExportRow(
              label: l.exportExcel,
              enabled: hasItems,
              makeFile: () => ExportFile(
                buildGearXlsx(
                  items: ref.read(allItemsProvider).value ?? const [],
                  categories: ref.read(categoriesProvider).value ?? const [],
                  unit: weightUnitOf(context),
                  l: l,
                ),
                extension: 'xlsx',
                mimeType: xlsxMimeType,
              ),
            ),
            _ExportRow(
              label: l.exportLighterPack,
              enabled: hasItems,
              makeFile: () => ExportFile(
                csvFileBytes(buildGearCsv(
                  items: ref.read(allItemsProvider).value ?? const [],
                  categories: ref.read(categoriesProvider).value ?? const [],
                  unit: weightUnitOf(context),
                  l: l,
                )),
                extension: 'csv',
                mimeType: csvMimeType,
              ),
            ),
          ]),
          _SectionLabel(l.sectionSettings),
          _Group(children: [
            _SettingRow<AppThemeMode>(
              label: l.appearance,
              current: appThemeMode.value,
              options: {
                AppThemeMode.system: l.themeSystem,
                AppThemeMode.light: l.themeLight,
                AppThemeMode.dark: l.themeDark,
              },
              onChanged: (v) {
                appThemeMode.value = v;
                db.updateThemeMode(v);
              },
            ),
            _SettingRow<AppLanguage>(
              label: l.language,
              current: appLanguage.value,
              options: languageNames,
              onChanged: (v) {
                appLanguage.value = v;
                db.updateLanguage(v);
              },
            ),
            // Until picked, the language's default shows as the value.
            _SettingRow<WeightUnit>(
              label: l.weightUnits,
              current: weightUnitOf(context),
              options: {WeightUnit.metric: l.unitsMetric, WeightUnit.imperial: l.unitsImperial},
              onChanged: (v) {
                appWeightUnit.value = v;
                db.updateWeightUnit(v);
              },
            ),
          ]),
          _SectionLabel(l.sectionAbout),
          _Group(children: [
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) =>
                  _Row(label: l.version(snapshot.data?.version ?? '')),
            ),
            _Row(
              label: l.clearAllData,
              color: AppColors.overWeight,
              onTap: () async {
                if (await _confirmClearAll(context)) {
                  await db.clearAllData(language: l.localeName);
                }
              },
            ),
          ]),
        ],
      ),
    );
  }

  Future<bool> _confirmClearAll(BuildContext context) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.clearAllTitle),
        content: Text(
          l.clearAllBody,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  child: Text(l.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.overWeight),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l.clearAllConfirm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}

/// The whole closet at a glance — total weight, how much there is, and
/// anything worn out, each worn-out line jumping straight to Инвентарь
/// filtered to it.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final items = ref.watch(allItemsProvider).value ?? const <Item>[];
    final categoryCount = ref.watch(closetRootCategoryTotalsProvider).length;
    final tripCount =
        (ref.watch(tripsProvider).value ?? const <Trip>[]).where((t) => !t.isDraft).length;
    int countOf(ItemCondition c) => items.where((i) => i.condition == c).length;
    final repair = countOf(ItemCondition.wornOut);
    final replace = countOf(ItemCondition.needsReplacement);

    void openFiltered(ItemCondition condition) {
      ref.read(inventoryConditionRequestProvider.notifier).state = condition;
      ref.read(currentTabProvider.notifier).state = 1;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.allYourGear,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 2),
          Text(
            formatWeight(context, ref.watch(closetTotalWeightProvider)),
            style: weightDisplayStyle(isOverweight: false).copyWith(fontSize: 30),
          ),
          const SizedBox(height: 2),
          Text(
            [l.itemCount(items.length), l.categoryCount(categoryCount), l.tripCount(tripCount)]
                .join(' · '),
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.8)),
          ),
          if (repair > 0 || replace > 0) const SizedBox(height: 8),
          if (repair > 0)
            _AttentionLine(
              text: l.attentionRepair(repair),
              condition: ItemCondition.wornOut,
              onTap: () => openFiltered(ItemCondition.wornOut),
            ),
          if (replace > 0)
            _AttentionLine(
              text: l.attentionReplace(replace),
              condition: ItemCondition.needsReplacement,
              onTap: () => openFiltered(ItemCondition.needsReplacement),
            ),
        ],
      ),
    );
  }
}

class _AttentionLine extends StatelessWidget {
  const _AttentionLine({required this.text, required this.condition, required this.onTap});

  final String text;
  final ItemCondition condition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorForCondition(condition);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: color))),
            Icon(Icons.chevron_right, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 22, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

/// A card of rows separated by hairlines.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: AppColors.textPrimary.withValues(alpha: 0.08),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One list row: a label, optionally a value on the right, and a chevron
/// when it leads somewhere. [comingSoon] rows are shown but inert, marked
/// "скоро" — what lands here in the next steps.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    this.value,
    this.onTap,
    this.color,
    this.comingSoon = false,
    this.enabled = true,
    this.trailingIcon,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Color? color;
  final bool comingSoon;

  /// False greys the row out — e.g. export with nothing to export.
  final bool enabled;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textSecondary.withValues(alpha: 0.6);
    final active = enabled && !comingSoon;
    return InkWell(
      onTap: active ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: active ? (color ?? AppColors.textPrimary) : muted,
                ),
              ),
            ),
            if (comingSoon)
              Text(context.l10n.comingSoon, style: TextStyle(fontSize: 13, color: muted)),
            if (value != null)
              Text(value!, style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            if (trailingIcon != null) ...[
              const SizedBox(width: 2),
              Icon(trailingIcon, size: 20, color: muted),
            ],
          ],
        ),
      ),
    );
  }
}

/// An export row: tap opens a small anchored menu — save the file to the
/// phone (the system "Save as" screen), or send it to another app. The
/// share sheet alone can't save to the phone, which is what most people
/// are actually after.
class _ExportRow extends StatelessWidget {
  const _ExportRow({required this.label, required this.enabled, required this.makeFile});

  final String label;
  final bool enabled;

  /// Builds the file only once an action is picked, from current data.
  final ExportFile Function() makeFile;

  Future<void> _open(BuildContext context) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset(box.size.width / 2, box.size.height), ancestor: overlay);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'save',
          child: _MenuLine(icon: Icons.download_outlined, text: l.saveToPhone),
        ),
        PopupMenuItem(
          value: 'share',
          child: _MenuLine(icon: Icons.ios_share, text: l.sendTo),
        ),
      ],
    );
    if (action == 'save') {
      if (await makeFile().save()) messenger.showSnackBar(SnackBar(content: Text(l.fileSaved)));
    } else if (action == 'share') {
      await makeFile().share();
    }
  }

  @override
  Widget build(BuildContext context) {
    // A Builder so the menu anchors to this row, not the whole screen.
    return Builder(
      builder: (rowContext) => _Row(
        label: label,
        enabled: enabled,
        trailingIcon: Icons.chevron_right,
        onTap: () => _open(rowContext),
      ),
    );
  }
}

class _MenuLine extends StatelessWidget {
  const _MenuLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: AppColors.textPrimary)),
      ],
    );
  }
}

/// A settings row showing its current value; tap opens an anchored menu of
/// the options, the current one checked.
class _SettingRow<T> extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.current,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T current;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    // Anchored under the row's right edge, where the value sits.
    final topLeft = box.localToGlobal(Offset(box.size.width / 2, box.size.height), ancestor: overlay);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
    final selected = await showMenu<T>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final MapEntry(key: value, value: name) in options.entries)
          PopupMenuItem(
            value: value,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: value == current ? AppColors.accent : AppColors.textPrimary,
                      fontWeight: value == current ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (value == current) Icon(Icons.check, size: 18, color: AppColors.accent),
              ],
            ),
          ),
      ],
    );
    if (selected != null && selected != current) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    // A Builder so the menu anchors to this row, not the whole screen.
    return Builder(
      builder: (rowContext) => _Row(
        label: label,
        value: options[current],
        trailingIcon: Icons.expand_more,
        onTap: () => _open(rowContext),
      ),
    );
  }
}
