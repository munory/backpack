import 'package:backpack/common/l10n.dart';
import 'package:backpack/data/database.dart';
import 'package:backpack/data/providers.dart';
import 'package:backpack/features/gear_list/gear_list_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the trip switcher lists every trip, straight after launch', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.runAsync(() async {
      await db.createTrip(name: 'Карелия');
      await db.createTrip(name: 'Алтай'); // active
    });
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(() async {
      container.dispose();
      await tester.runAsync(db.close);
    });

    // Инвентарь first, the Походы tab never opened: nothing else has
    // loaded the trip list.
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('en'), Locale('ru')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(body: GearListScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Алтай'));
    await tester.pumpAndSettle();

    expect(find.text('Карелия'), findsOneWidget);
    expect(find.text('Все походы'), findsOneWidget);
  });
}
