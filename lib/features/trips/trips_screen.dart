import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/empty_state.dart';
import '../../common/navigation.dart';
import '../../common/text_format.dart';
import '../../common/theme.dart';
import '../../common/weight_format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'create_trip_screen.dart';

/// Every trip, with the active one marked. Tapping a trip makes it active
/// and jumps to Главная (which always shows the active trip); long-press
/// edits, duplicates or deletes. Trips that have already ended collect in
/// a collapsed "Архив" group at the bottom — kept as templates to copy,
/// out of the way of what's coming up.
class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  bool _archiveExpanded = false;

  void _openForm({Trip? editing}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripFormScreen(editing: editing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripsProvider).value ?? const <Trip>[];
    final summaries = ref.watch(tripSummariesProvider).value ?? const <int, TripSummary>{};
    final activeId = ref.watch(appSettingsProvider).value?.activeTripId;

    if (trips.isEmpty) {
      return EmptyStateView(
        icon: Icons.map_outlined,
        title: 'Походов пока нет',
        subtitle: 'Создай поход, чтобы собрать для него свой список вещей и следить за весом.',
        ctaLabel: 'Создать поход',
        ctaIcon: Icons.add,
        onCta: _openForm,
      );
    }

    final today = DateUtils.dateOnly(DateTime.now());
    bool isPast(Trip t) => t.endDate != null && DateUtils.dateOnly(t.endDate!).isBefore(today);
    // The draft is the working scratch list — pinned to the top.
    final upcoming = [
      ...trips.where((t) => t.isDraft),
      ...trips.where((t) => !t.isDraft && !isPast(t)),
    ];
    final past = trips.where(isPast).toList();

    Widget card(Trip t) => _TripCard(
          trip: t,
          summary: summaries[t.id],
          isActive: t.id == activeId,
          onEdit: () => _openForm(editing: t),
        );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'Мои походы',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: _openForm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Новый поход'),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final t in upcoming) card(t),
          if (past.isNotEmpty) ...[
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _archiveExpanded = !_archiveExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  children: [
                    Text(
                      'Архив · ${past.length}',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _archiveExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
            if (_archiveExpanded) for (final t in past) card(t),
          ],
        ],
      ),
    );
  }
}

class _TripCard extends ConsumerWidget {
  const _TripCard({
    required this.trip,
    required this.summary,
    required this.isActive,
    required this.onEdit,
  });

  final Trip trip;
  final TripSummary? summary;
  final bool isActive;
  final VoidCallback onEdit;

  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      items: [
        if (trip.isDraft)
          const PopupMenuItem(value: 'edit', child: Text('Превратить в поход'))
        else ...[
          const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
          const PopupMenuItem(value: 'duplicate', child: Text('Дублировать')),
        ],
        PopupMenuItem(
          value: 'delete',
          child: Text('Удалить', style: TextStyle(color: AppColors.overWeight)),
        ),
      ],
    );
    if (!context.mounted) return;
    final db = ref.read(databaseProvider);
    switch (selected) {
      case 'edit':
        onEdit();
      case 'duplicate':
        // Like a duplicated item, a copied trip almost always needs a new
        // name/dates — open it straight into editing.
        final id = await db.duplicateTrip(trip);
        final copy = await (db.select(db.trips)..where((t) => t.id.equals(id))).getSingle();
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TripFormScreen(editing: copy)),
          );
        }
      case 'delete':
        if (await _confirmDelete(context)) await db.deleteTrip(trip.id);
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить «${trip.name}»?'),
        content: Text(
          'Список вещей этого похода удалится. Сами вещи останутся в Инвентаре.',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.overWeight),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Удалить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grams = summary?.grams ?? 0;
    final count = summary?.itemCount ?? 0;
    final target = trip.targetWeightGrams;
    final dates = formatTripDates(trip.startDate, trip.endDate);
    final over = target != null && grams > target;
    final meta = [?dates, '$count ${itemWord(count)}'].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.cardShadow,
        border: isActive ? Border.all(color: AppColors.accent, width: 1.5) : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await ref.read(databaseProvider).setActiveTrip(trip.id);
          ref.read(currentTabProvider.notifier).state = 0;
        },
        onLongPress: () => _showMenu(context, ref),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (trip.isDraft) ...[
                    Icon(
                      Icons.edit_note,
                      size: 20,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      trip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (isActive)
                    Text(
                      'Активный',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                meta,
                style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.65), fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // A bar only means something against a target — without
                  // one it would just sit full and read as "100% packed".
                  if (target != null && target > 0)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (grams / target).clamp(0, 1).toDouble(),
                          minHeight: 6,
                          backgroundColor: AppColors.trackBackground,
                          color: over ? AppColors.overWeight : AppColors.gear,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 12),
                  Text(
                    target == null ? formatKg(grams) : '${formatKg(grams)} / ${formatKg(target)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: over ? AppColors.overWeight : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
