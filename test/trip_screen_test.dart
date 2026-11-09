import 'package:backpack/common/l10n.dart';
import 'package:backpack/common/navigation.dart';
import 'package:backpack/data/database.dart';
import 'package:backpack/data/providers.dart';
import 'package:backpack/features/trips/create_trip_screen.dart';
import 'package:backpack/features/trips/trips_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<Trip> tripNamed(String name) =>
      (db.select(db.trips)..where((t) => t.name.equals(name))).getSingle();

  /// The app in Russian, on a screen with an "open" button that pushes the
  /// trip screen — so leaving it lands back there.
  Future<void> openTrip(WidgetTester tester, Trip trip) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('en'), Locale('ru')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => TripFormScreen(editing: trip)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('"Выбрать" on a trip card makes it the active one and goes to Главная', (tester) async {
    await tester.runAsync(() async {
      await db.createTrip(name: 'Карелия');
      await db.createTrip(name: 'Алтай'); // the active one now
    });
    container.read(currentTabProvider.notifier).state = 2;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('en'), Locale('ru')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(body: TripsScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    // Only the trip that isn't active offers it.
    expect(find.text('Выбрать'), findsOneWidget);
    await tester.tap(find.text('Выбрать'));
    await tester.pumpAndSettle();

    final active = await tester.runAsync(() async => (await db.activeTrip())?.name);
    expect(active, 'Карелия');
    expect(container.read(currentTabProvider), 0);
  });

  testWidgets('"Сохранить" works only after a change, and saves it', (tester) async {
    late Trip karelia;
    await tester.runAsync(() async {
      await db.createTrip(name: 'Карелия');
      karelia = await tripNamed('Карелия');
    });

    await openTrip(tester, karelia);
    final save = find.widgetWithText(FilledButton, 'Сохранить');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Карелия, сплав');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final names = await tester.runAsync(() async => [for (final t in await db.select(db.trips).get()) t.name]);
    expect(names, ['Карелия, сплав']);
  });

  testWidgets('naming the draft turns it into a trip', (tester) async {
    late Trip draft;
    await tester.runAsync(() async {
      await db.createTrip(name: 'Черновик', isDraft: true);
      draft = (await db.select(db.trips).get()).single;
    });

    await openTrip(tester, draft);
    await tester.enterText(find.byType(TextField).first, 'Хибины');
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final trip = await tester.runAsync(() async => (await db.select(db.trips).get()).single);
    expect(trip!.name, 'Хибины');
    expect(trip.isDraft, isFalse);
  });
}
