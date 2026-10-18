import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/theme.dart';
import '../../common/weight_format.dart';
import '../../data/providers.dart';
import 'create_trip_screen.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(activeTripProvider).value;

    if (trip == null) {
      // Not `const` — see the comment on `home:` in main.dart: a canonicalized
      // const instance here would never rebuild on a brightness change even
      // though TripsScreen's own build() just did.
      return CreateTripScreen();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(trip.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              trip.targetWeightGrams == null
                  ? 'Цель не задана'
                  : 'Цель: ${formatKg(trip.targetWeightGrams!)}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              'Управление составом похода и создание новых поездок — скоро.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
