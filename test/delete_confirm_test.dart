import 'package:backpack/common/category_actions.dart';
import 'package:backpack/common/l10n.dart';
import 'package:backpack/data/database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// A screen with one button that runs [action], in Russian.
  Future<void> pumpButton(WidgetTester tester, Future<void> Function(BuildContext) action) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      supportedLocales: const [Locale('en'), Locale('ru')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () => action(context), child: const Text('go')),
        ),
      ),
    ));
  }

  Future<T> run<T>(WidgetTester tester, Future<T> Function() f) async => (await tester.runAsync(f)) as T;

  Future<Item> addStove() async {
    final id = await db.addItem(
      name: 'Горелка',
      weightGrams: 90,
      condition: ItemCondition.newItem,
      packType: PackType.gear,
    );
    return (db.select(db.items)..where((i) => i.id.equals(id))).getSingle();
  }

  testWidgets('deleting an item asks first; Отмена keeps it', (tester) async {
    final stove = await run(tester, addStove);
    await pumpButton(tester, (context) => deleteItemWithConfirmation(context, db, stove));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить «Горелка»?'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(await run(tester, () => db.select(db.items).get()), hasLength(1));
  });

  testWidgets('"Больше не спрашивать" deletes now and skips the question next time', (tester) async {
    final stove = await run(tester, addStove);
    await pumpButton(tester, (context) => deleteItemWithConfirmation(context, db, stove));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Больше не спрашивать'));
    await tester.pump();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));

    expect(await run(tester, () => db.select(db.items).get()), isEmpty);
    final settings = await run(tester, () => db.select(db.appSettings).getSingle());
    expect(settings.confirmItemDelete, isFalse);

    // The next one goes without a question.
    final pot = await run(tester, addStove);
    await pumpButton(tester, (context) => deleteItemWithConfirmation(context, db, pot));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(find.byType(AlertDialog), findsNothing);
    expect(await run(tester, () => db.select(db.items).get()), isEmpty);
  });

  testWidgets('a category is always asked about, even with item questions off', (tester) async {
    final kitchen = await run(tester, () async {
      await db.updateConfirmItemDelete(false);
      return (db.select(db.categories)..where((c) => c.name.equals('Кухня'))).getSingle();
    });
    await pumpButton(tester, (context) => deleteCategoryWithConfirmation(context, db, kitchen));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить категорию «Кухня»?'), findsOneWidget);
    expect(find.text('Больше не спрашивать'), findsNothing);

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    final names = await run(tester, () async => [for (final c in await db.select(db.categories).get()) c.name]);
    expect(names, isNot(contains('Кухня')));
  });
}
