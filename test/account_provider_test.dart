import 'package:backpack/account/account_provider.dart';
import 'package:backpack/account/api_client.dart';
import 'package:backpack/account/token_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_server.dart';

const kate = AccountUser(id: 'u1', email: 'kate@example.com', hasPassword: true);

void main() {
  late FakeServer server;

  setUp(() => server = FakeServer());

  /// The app's providers, but with the session in memory and a pretend server.
  ProviderContainer appWith(MemoryTokenStore store, {bool accountsEnabled = true}) {
    final container = ProviderContainer(overrides: [
      accountsEnabledProvider.overrideWithValue(accountsEnabled),
      tokenStoreProvider.overrideWithValue(store),
      apiClientProvider.overrideWithValue(
        ApiClient(tokens: store, httpClient: server.client, baseUrl: 'http://server'),
      ),
    ]);
    addTearDown(container.dispose);
    // Keep the provider alive between reads, like a screen watching it.
    container.listen(accountProvider, (_, _) {});
    return container;
  }

  /// Lets the background launch check finish.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  test('accounts switched off: signed out, even with a saved session, and the server is never asked', () async {
    final app = appWith(
      MemoryTokenStore(const Tokens(access: 'access-1', refresh: 'refresh-1'), kate),
      accountsEnabled: false,
    );
    await settle();

    expect(app.read(accountProvider), isA<SignedOut>());
    expect(server.meCalls, 0);
  });

  test('a fresh install is signed out', () async {
    final app = appWith(MemoryTokenStore());
    expect(app.read(accountProvider), isA<AccountChecking>());

    await settle();

    expect(app.read(accountProvider), isA<SignedOut>());
  });

  test('signed in last time → signed in at once, then updated from the server', () async {
    server.email = 'kate.new@example.com';
    server.meDelay = const Duration(milliseconds: 20);
    final app = appWith(MemoryTokenStore(const Tokens(access: 'access-1', refresh: 'refresh-1'), kate));

    await Future<void>.delayed(Duration.zero);
    // Straight from what was saved — before the server has answered.
    expect((app.read(accountProvider) as SignedIn).user.email, 'kate@example.com');

    await settle();
    expect((app.read(accountProvider) as SignedIn).user.email, 'kate.new@example.com');
  });

  test('no internet at launch keeps the account signed in', () async {
    server.down = true;
    final app = appWith(MemoryTokenStore(const Tokens(access: 'access-1', refresh: 'refresh-1'), kate));

    await settle();

    expect((app.read(accountProvider) as SignedIn).user.email, 'kate@example.com');
  });

  test('a session ended on the server shows as signed out', () async {
    final store = MemoryTokenStore(const Tokens(access: 'expired', refresh: 'revoked'), kate);
    final app = appWith(store);

    await settle();

    expect(app.read(accountProvider), isA<SignedOut>());
    expect(await store.read(), isNull);
  });

  test('signing in and out', () async {
    final store = MemoryTokenStore();
    final app = appWith(store);
    await settle();

    await app.read(accountProvider.notifier).login('kate@example.com', 'right password');
    expect((app.read(accountProvider) as SignedIn).user.email, 'kate@example.com');
    // Remembered for next launch.
    expect((await store.readUser())?.email, 'kate@example.com');

    await app.read(accountProvider.notifier).logout();
    expect(app.read(accountProvider), isA<SignedOut>());
    expect(await store.readUser(), isNull);
  });

  test('a failed sign-in stays signed out and tells why', () async {
    final app = appWith(MemoryTokenStore());
    await settle();

    await expectLater(
      app.read(accountProvider.notifier).login('kate@example.com', 'wrong'),
      throwsA(isA<ApiException>()),
    );
    expect(app.read(accountProvider), isA<SignedOut>());
  });

  test('signing up takes the emailed code: nothing before it, signed in after', () async {
    final store = MemoryTokenStore();
    final app = appWith(store);
    await settle();

    await app.read(apiClientProvider).startRegistration('kate@example.com', 'my password', language: 'ru');
    expect(server.signupEmails, 1);
    expect(app.read(accountProvider), isA<SignedOut>());
    expect(await store.read(), isNull);

    await expectLater(
      app.read(accountProvider.notifier).confirmRegistration('kate@example.com', '000000'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_code')),
    );
    expect(app.read(accountProvider), isA<SignedOut>());

    await app.read(accountProvider.notifier).confirmRegistration('kate@example.com', FakeServer.signupCode);
    expect((app.read(accountProvider) as SignedIn).user.email, 'kate@example.com');
    expect(await store.read(), isNotNull);
  });

  test('the name can be set and cleared, and is remembered for offline', () async {
    final store = MemoryTokenStore(const Tokens(access: 'access-1', refresh: 'refresh-1'), kate);
    final app = appWith(store);
    await settle();

    await app.read(accountProvider.notifier).updateName('Катя');
    expect((app.read(accountProvider) as SignedIn).user.name, 'Катя');
    expect((await store.readUser())?.name, 'Катя');

    await app.read(accountProvider.notifier).updateName(null);
    expect((app.read(accountProvider) as SignedIn).user.name, isNull);
  });
}
