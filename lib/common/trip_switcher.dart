import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';
import 'l10n.dart';
import 'navigation.dart';
import 'theme.dart';

/// The trip picker anchored under whatever [context] belongs to — every
/// trip (the active one checked), then "Все походы". Picking one makes it
/// active. Shared by Главная's title and Инвентарь's "Собираю для" line.
Future<void> showTripSwitcherMenu(BuildContext context, WidgetRef ref, Trip current) async {
  final trips = ref.read(tripsProvider).value ?? const <Trip>[];
  final box = context.findRenderObject()! as RenderBox;
  final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final topLeft = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
  final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);

  final selected = await showMenu<int>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    ),
    items: [
      for (final t in trips)
        PopupMenuItem(
          value: t.id,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tripName(context.l10n, t),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.id == current.id ? AppColors.accent : AppColors.textPrimary,
                    fontWeight: t.id == current.id ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (t.id == current.id) Icon(Icons.check, size: 18, color: AppColors.accent),
            ],
          ),
        ),
      const PopupMenuDivider(),
      PopupMenuItem(value: -1, child: Text(context.l10n.allTrips)),
    ],
  );
  if (selected == null) return;
  if (selected == -1) {
    ref.read(currentTabProvider.notifier).state = 2;
  } else if (selected != current.id) {
    await ref.read(databaseProvider).setActiveTrip(selected);
  }
}
