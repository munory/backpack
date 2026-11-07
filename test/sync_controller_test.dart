import 'package:backpack/account/account_provider.dart';
import 'package:backpack/account/api_client.dart';
import 'package:backpack/account/token_store.dart';
import 'package:backpack/data/database.dart';
import 'package:backpack/data/providers.dart';
import 'package:backpack/sync/sync_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_server.dart';

const kate = AccountUser(id: 'u1', email: 'kate@example.com', hasPassword: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeServer server;
  late AppDatabase db;

  setUp(() {
    server = FakeServer();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  /// The app as it runs: signed in already (or not), sync watched by the
  /// app shell.
  ProviderContainer app({bool signedIn = true}) {
    final store = signedIn
        ? MemoryTokenStore(const Tokens(access: 'access-1', refresh: 'refresh-1'), kate)
        : MemoryTokenStore();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        accountsEnabledProvider.overrideWithValue(true),
      tokenStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(
          ApiClient(tokens: store, httpClient: server.client, baseUrl: 'http://server'),
        ),
        syncTimingProvider.overrideWithValue(
          const SyncTiming(afterEdit: Duration(milliseconds: 20), whileOpen: Duration(hours: 1)),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(syncProvider, (_, _) {});
    return container;
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 150));

  Future<int> addStove() =>
      db.addItem(name: 'Горелка', weightGrams: 90, condition: ItemCondition.newItem, packType: PackType.gear);

  test('signed in at launch: syncs straight away', () async {
    final container = app();
    await settle();

    expect(container.read(syncProvider), isA<SyncDone>());
    expect(server.sync.stored('categories'), hasLength(6));
  });

  test('an edit is sent by itself shortly after — and that\'s the end of it', () async {
    app();
    await settle();

    await addStove();
    await settle();
    expect(server.sync.stored('items').map((r) => r['name']), ['Горелка']);

    final requests = server.sync.requests;
    await settle();
    expect(server.sync.requests, requests, reason: 'applying an answer doesn\'t start another sync');
  });

  test('offline: says so, and catches up with the next edit', () async {
    server.down = true;
    final container = app();
    await settle();
    expect(container.read(syncProvider), isA<SyncOffline>());

    server.down = false;
    await addStove();
    await settle();
    expect(container.read(syncProvider), isA<SyncDone>());
    expect(server.sync.stored('items'), hasLength(1));
  });

  test('signed out: nothing is synced', () async {
    final container = app(signedIn: false);
    await settle();
    await addStove();
    await settle();

    expect(container.read(syncProvider), isA<SyncOff>());
    expect(server.sync.requests, 0);
  });

  test('signing out stops syncing; the edits wait on the phone', () async {
    final container = app();
    await settle();
    await container.read(accountProvider.notifier).logout();
    await settle();

    final requests = server.sync.requests;
    await addStove();
    await settle();
    expect(container.read(syncProvider), isA<SyncOff>());
    expect(server.sync.requests, requests);
    expect(await db.select(db.syncOutbox).get(), isNotEmpty);
  });
}
