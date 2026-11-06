import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'account_user.dart';

/// The two keys to the account: a short-lived access token sent with every
/// request, and a long-lived refresh token that gets a new one.
class Tokens {
  const Tokens({required this.access, required this.refresh});

  final String access;
  final String refresh;
}

/// Where the session is kept between app launches: the tokens, and who they
/// belong to (so the app can show "signed in as …" offline). An interface so
/// tests can keep it in memory instead.
abstract class TokenStore {
  Future<Tokens?> read();
  Future<void> write(Tokens tokens);
  Future<AccountUser?> readUser();
  Future<void> writeUser(AccountUser user);

  /// Forgets everything: tokens and the account.
  Future<void> clear();
}

/// The phone's secure storage — Android Keystore under the hood: encrypted
/// with a key that never leaves the phone's security chip, unreadable to
/// other apps. Not the app's SQLite database or settings: a refresh token is
/// as good as the password for 30 days, so it gets the safe, not a drawer.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _userKey = 'account_user';

  @override
  Future<Tokens?> read() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    return Tokens(access: access, refresh: refresh);
  }

  @override
  Future<void> write(Tokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.access);
    await _storage.write(key: _refreshKey, value: tokens.refresh);
  }

  @override
  Future<AccountUser?> readUser() async {
    final saved = await _storage.read(key: _userKey);
    if (saved == null) return null;
    try {
      return AccountUser.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } on Object {
      return null; // Saved by an older version in another shape — ask again.
    }
  }

  @override
  Future<void> writeUser(AccountUser user) => _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
  }
}

/// For tests: forgets everything when the test ends.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._tokens, this._user]);

  Tokens? _tokens;
  AccountUser? _user;

  @override
  Future<Tokens?> read() async => _tokens;

  @override
  Future<void> write(Tokens tokens) async => _tokens = tokens;

  @override
  Future<AccountUser?> readUser() async => _user;

  @override
  Future<void> writeUser(AccountUser user) async => _user = user;

  @override
  Future<void> clear() async {
    _tokens = null;
    _user = null;
  }
}
