import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'account_user.dart';
import 'token_store.dart';

export 'account_user.dart';

/// Where the server is. The Android emulator reaches the computer it runs on
/// at 10.0.2.2 — so while developing, the app talks to the server started
/// with `npm run dev` there. A real build passes the VPS address instead:
/// `flutter build appbundle --dart-define=API_URL=https://api.example.ru`.
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');

/// The server said no. [code] is its machine-readable reason
/// (`invalid_credentials`, `email_taken`, `too_many_requests`, …) — the
/// screens turn it into a translated message.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, {this.retryAfter});

  final int statusCode;
  final String code;

  /// For `too_many_requests`: how long until trying again is allowed.
  final Duration? retryAfter;

  @override
  String toString() => 'ApiException($statusCode, $code)';
}

/// The server couldn't be reached at all: no internet, server down, or it
/// took too long. Not the same as "wrong password" — the app keeps working
/// offline and tries later.
class NetworkException implements Exception {
  const NetworkException(this.cause);

  final Object cause;

  @override
  String toString() => 'NetworkException($cause)';
}

/// The server's sign-in session ended (refresh token expired or revoked —
/// e.g. the password was changed on another phone). The app must sign out
/// locally; its data stays on the phone.
class SessionExpiredException implements Exception {
  const SessionExpiredException();
}

/// Talks to the Backpack server: sends requests, adds the access token,
/// renews it when it runs out. Screens never see tokens — only results and
/// exceptions.
class ApiClient {
  ApiClient({
    required this._tokens,
    http.Client? httpClient,
    this._baseUrl = apiUrl,
    this.timeout = const Duration(seconds: 15),
  }) : _http = httpClient ?? http.Client();

  final TokenStore _tokens;
  final http.Client _http;
  final String _baseUrl;
  final Duration timeout;

  /// Called when the session ends on its own (see [SessionExpiredException]),
  /// so the app can show "signed out".
  void Function()? onSessionExpired;

  /// Whether tokens are saved, i.e. someone signed in on this phone.
  Future<bool> get hasSession async => await _tokens.read() != null;

  // --- Signing in and out ---------------------------------------------------

  /// Sign-up, step 1: emails a 6-digit code. No account exists yet — it's
  /// created by [confirmRegistration], once the code proves the address is
  /// real and theirs. Asking again within a minute sends nothing new; the
  /// code already sent keeps working.
  Future<void> startRegistration(String email, String password, {required String language}) => _send(
    'POST',
    '/auth/register',
    body: {'email': email, 'password': password, 'language': language == 'ru' ? 'ru' : 'en'},
  );

  /// Sign-up, step 2: the code from the email → the account, signed in.
  Future<AccountUser> confirmRegistration(String email, String code) =>
      _signIn('/auth/register/confirm', {'email': email, 'code': code});

  Future<AccountUser> login(String email, String password) =>
      _signIn('/auth/login', {'email': email, 'password': password});

  Future<AccountUser> _signIn(String path, Map<String, Object?> body) async {
    final json = await _send('POST', path, body: body);
    await _saveTokens(json);
    final user = AccountUser.fromJson(json['user'] as Map<String, dynamic>);
    await _tokens.writeUser(user);
    return user;
  }

  /// Ends the session on the server too, so the refresh token is useless even
  /// if someone copied it. Signing out locally doesn't wait on the network:
  /// no internet shouldn't mean "can't sign out".
  Future<void> logout() async {
    final saved = await _tokens.read();
    await _tokens.clear();
    if (saved == null) return;
    try {
      await _send('POST', '/auth/logout', body: {'refreshToken': saved.refresh});
    } on Exception {
      // Offline or the server is down — the token simply expires on its own.
    }
  }

  // --- Forgotten password ---------------------------------------------------

  /// Emails a 6-digit code — or, if no account has this email, quietly
  /// nothing: the answer is the same either way, so no one can use this to
  /// check who has an account.
  Future<void> requestPasswordReset(String email, {required String language}) =>
      _send('POST', '/auth/password-reset/request', body: {'email': email, 'language': language == 'ru' ? 'ru' : 'en'});

  /// Sets the new password with the emailed code — and signs in.
  Future<AccountUser> confirmPasswordReset(String email, String code, String newPassword) =>
      _signIn('/auth/password-reset/confirm', {'email': email, 'code': code, 'newPassword': newPassword});

  // --- The account ----------------------------------------------------------

  /// Asks the server who's signed in — and remembers the answer, so the
  /// app can show it offline next time ([TokenStore.readUser]).
  Future<AccountUser> me() async {
    final user = AccountUser.fromJson(await _sendSignedIn('GET', '/me'));
    await _tokens.writeUser(user);
    return user;
  }

  /// Sets how the app addresses the person; null or blank clears it.
  Future<AccountUser> updateName(String? name) async {
    final user = AccountUser.fromJson(await _sendSignedIn('PATCH', '/me', body: {'name': name}));
    await _tokens.writeUser(user);
    return user;
  }

  /// Deletes the account and everything stored with it on the server.
  Future<void> deleteAccount({String? password}) async {
    await _sendSignedIn('DELETE', '/me', body: {'password': ?password});
    await _tokens.clear();
  }

  /// A signed-in request to any route — /sync uses this (stage 13).
  Future<Map<String, dynamic>> signedIn(String method, String path, {Map<String, Object?>? body}) =>
      _sendSignedIn(method, path, body: body);

  // --- Plumbing -------------------------------------------------------------

  /// Sends with the access token; if the server says it's expired (401),
  /// renews it once and tries again.
  Future<Map<String, dynamic>> _sendSignedIn(String method, String path, {Map<String, Object?>? body}) async {
    final saved = await _tokens.read();
    if (saved == null) throw const SessionExpiredException();
    try {
      return await _send(method, path, body: body, accessToken: saved.access);
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;
    }
    final renewed = await _renew(usedAccessToken: saved.access);
    try {
      return await _send(method, path, body: body, accessToken: renewed.access);
    } on ApiException catch (e) {
      // Still refused with a brand-new token: the account itself is gone.
      if (e.statusCode == 401) await _endSession();
      rethrow;
    }
  }

  Future<Tokens>? _renewing;

  /// Gets a new pair of tokens — once, however many requests need it at the
  /// same moment. Refresh tokens are single-use: if two requests each spent
  /// the same one, the server would take the second for a stolen copy and
  /// sign out every device. So the first caller does the renewing and the
  /// rest wait for its result.
  Future<Tokens> _renew({required String usedAccessToken}) async {
    // Someone else already renewed while this request was on its way.
    final current = await _tokens.read();
    if (current == null) throw const SessionExpiredException();
    if (current.access != usedAccessToken) return current;

    return _renewing ??= () async {
      try {
        final json = await _send('POST', '/auth/refresh', body: {'refreshToken': current.refresh});
        return await _saveTokens(json);
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          await _endSession();
          throw const SessionExpiredException();
        }
        rethrow;
      } finally {
        _renewing = null;
      }
    }();
  }

  Future<void> _endSession() async {
    await _tokens.clear();
    onSessionExpired?.call();
  }

  Future<Tokens> _saveTokens(Map<String, dynamic> json) async {
    final tokens = Tokens(access: json['accessToken'] as String, refresh: json['refreshToken'] as String);
    await _tokens.write(tokens);
    return tokens;
  }

  /// One HTTP request: JSON in, JSON out. A non-2xx answer becomes an
  /// [ApiException]; no answer at all, a [NetworkException].
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? accessToken,
  }) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'));
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (accessToken != null) request.headers['authorization'] = 'Bearer $accessToken';

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(timeout));
    } on TimeoutException catch (e) {
      throw NetworkException(e);
    } on http.ClientException catch (e) {
      // No connection, DNS failure, connection refused — all land here.
      throw NetworkException(e);
    }

    final json = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    throw ApiException(
      response.statusCode,
      json['error'] as String? ?? 'unknown',
      retryAfter: seconds == null ? null : Duration(seconds: seconds),
    );
  }

  static Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return const {};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      // Not JSON — e.g. an error page from something in between.
      return const {};
    }
  }
}
