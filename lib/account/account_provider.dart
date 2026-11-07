import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'token_store.dart';

/// Accounts and sync are built and tested but switched off for now: the app
/// ships local-only until the server runs somewhere real (decided
/// 2026-11-07). Turned on per build — for a demo, or once deployed — with
/// `--dart-define=ACCOUNTS=true`. Off, nobody is ever signed in: Profile shows
/// no account, nothing talks to the server. A provider so tests can flip it.
final accountsEnabledProvider = Provider<bool>((ref) => const bool.fromEnvironment('ACCOUNTS'));

/// Where the session is kept. Overridden in tests with a [MemoryTokenStore].
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// The one connection to the server the whole app shares — sharing it is
/// what lets token renewal happen once for everyone (see [ApiClient]).
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(tokens: ref.watch(tokenStoreProvider)));

/// Is anyone signed in on this phone, and who.
sealed class AccountState {
  const AccountState();
}

/// Just launched, looking in the safe — a moment, before the first frame
/// that needs to know.
class AccountChecking extends AccountState {
  const AccountChecking();
}

class SignedOut extends AccountState {
  const SignedOut();
}

class SignedIn extends AccountState {
  const SignedIn(this.user);

  final AccountUser user;
}

/// Who's signed in, for every screen that cares: Profile shows it, sync
/// (stage 13) runs only while [SignedIn].
final accountProvider = NotifierProvider<AccountNotifier, AccountState>(AccountNotifier.new);

class AccountNotifier extends Notifier<AccountState> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  AccountState build() {
    if (!ref.watch(accountsEnabledProvider)) return const SignedOut();
    // The server ended the session on its own (password changed on another
    // phone, account deleted elsewhere, 30 days unused) — show it.
    _api.onSessionExpired = () {
      if (ref.mounted) state = const SignedOut();
    };
    Future.microtask(_restore);
    return const AccountChecking();
  }

  /// At launch: signed in last time? Then show it straight away from what's
  /// saved, and quietly ask the server in the background — no internet at
  /// launch must not look like being signed out.
  Future<void> _restore() async {
    final store = ref.read(tokenStoreProvider);
    final saved = await store.read() != null ? await store.readUser() : null;
    if (!ref.mounted) return;
    if (saved == null) {
      // No session — or tokens without a saved account, which only an
      // interrupted sign-in leaves. Ask the server who they belong to.
      if (await store.read() == null) {
        state = const SignedOut();
        return;
      }
    } else {
      state = SignedIn(saved);
    }
    await refresh();
  }

  /// Asks the server for the latest (an email changed, …). Offline or the
  /// server is down: keeps what's shown.
  Future<void> refresh() async {
    try {
      final user = await _api.me();
      if (ref.mounted) state = SignedIn(user);
    } on SessionExpiredException {
      if (ref.mounted) state = const SignedOut();
    } on NetworkException {
      if (ref.mounted && state is AccountChecking) state = const SignedOut();
    } on ApiException {
      if (ref.mounted && state is AccountChecking) state = const SignedOut();
    }
  }

  // Each of these throws ApiException / NetworkException for the screen to
  // show; on success the whole app sees "signed in".

  Future<void> login(String email, String password) async => state = SignedIn(await _api.login(email, password));

  /// The second step of sign-up (the first, emailing the code, signs no one
  /// in — screens call [ApiClient.startRegistration] directly).
  Future<void> confirmRegistration(String email, String code) async =>
      state = SignedIn(await _api.confirmRegistration(email, code));

  /// Sets or clears the name; shown right away everywhere.
  Future<void> updateName(String? name) async => state = SignedIn(await _api.updateName(name));

  Future<void> resetPassword(String email, String code, String newPassword) async =>
      state = SignedIn(await _api.confirmPasswordReset(email, code, newPassword));

  /// Signs out on this phone. Gear and trips stay — they were the phone's to
  /// begin with.
  Future<void> logout() async {
    await _api.logout();
    state = const SignedOut();
  }

  Future<void> deleteAccount({String? password}) async {
    await _api.deleteAccount(password: password);
    state = const SignedOut();
  }
}
