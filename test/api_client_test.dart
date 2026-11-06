import 'dart:async';

import 'package:backpack/account/api_client.dart';
import 'package:backpack/account/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fake_server.dart';

void main() {
  late FakeServer server;
  late MemoryTokenStore tokens;
  late ApiClient api;

  setUp(() {
    server = FakeServer();
    tokens = MemoryTokenStore();
    api = ApiClient(tokens: tokens, httpClient: server.client, baseUrl: 'http://server');
  });

  test('signing in saves the tokens and returns the account', () async {
    final user = await api.login('kate@example.com', 'right password');

    expect(user.email, 'kate@example.com');
    expect((await tokens.read())?.refresh, 'refresh-1');
  });

  test('a wrong password is an ApiException with the server\'s reason', () async {
    await expectLater(
      api.login('kate@example.com', 'wrong'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_credentials')),
    );
    expect(await tokens.read(), isNull);
  });

  test('an expired access token is renewed and the request repeated', () async {
    tokens.write(const Tokens(access: 'expired', refresh: 'refresh-1'));

    final user = await api.me();

    expect(user.id, 'u1');
    expect(server.refreshCalls, 1);
    expect((await tokens.read())?.refresh, 'refresh-2');
  });

  test('many requests at once renew only once', () async {
    tokens.write(const Tokens(access: 'expired', refresh: 'refresh-1'));

    await Future.wait([api.me(), api.me(), api.me(), api.me()]);

    // Spending one refresh token twice would look like theft to the server.
    expect(server.refreshCalls, 1);
  });

  test('a refused refresh token ends the session', () async {
    tokens.write(const Tokens(access: 'expired', refresh: 'revoked'));
    var expired = false;
    api.onSessionExpired = () => expired = true;

    await expectLater(api.me(), throwsA(isA<SessionExpiredException>()));
    expect(expired, isTrue);
    expect(await tokens.read(), isNull);
  });

  test('no connection is a NetworkException, and the session stays', () async {
    tokens.write(const Tokens(access: 'access-1', refresh: 'refresh-1'));
    server.down = true;

    await expectLater(api.me(), throwsA(isA<NetworkException>()));
    expect(await tokens.read(), isNotNull);
  });

  test('signing out works offline too', () async {
    await api.login('kate@example.com', 'right password');
    server.down = true;

    await api.logout();

    expect(await tokens.read(), isNull);
  });

  test('"too many attempts" says how long to wait', () async {
    await expectLater(
      api.requestPasswordReset('kate@example.com', language: 'ru'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 429)
          .having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 42))),
    );
  });

  test('a server that never answers times out', () async {
    final slow = ApiClient(
      tokens: tokens,
      baseUrl: 'http://server',
      timeout: const Duration(milliseconds: 50),
      httpClient: MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(slow.login('a@b.c', 'x'), throwsA(isA<NetworkException>()));
  });
}
