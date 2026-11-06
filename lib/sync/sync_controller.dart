import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/account_provider.dart';
import '../account/api_client.dart';
import '../data/providers.dart';
import 'sync_engine.dart';

/// How the last sync went — for the line under the account in Профиль.
sealed class SyncStatus {
  const SyncStatus();
}

/// Not signed in: nothing to sync with.
class SyncOff extends SyncStatus {
  const SyncOff();
}

/// The first sync since signing in or launching is on its way.
class Syncing extends SyncStatus {
  const Syncing();
}

class SyncDone extends SyncStatus {
  const SyncDone(this.at);

  final DateTime at;
}

/// No connection (or the server is down) — it tries again by itself.
class SyncOffline extends SyncStatus {
  const SyncOffline();
}

/// The server refused — also retried, on the next change or launch.
class SyncFailed extends SyncStatus {
  const SyncFailed();
}

/// When syncs happen. A provider so tests can make the waits short.
class SyncTiming {
  const SyncTiming({this.afterEdit = const Duration(seconds: 2), this.whileOpen = const Duration(seconds: 30)});

  /// After an edit, how long to wait for more before sending — typing a
  /// name, ticking several items: one sync, not ten.
  final Duration afterEdit;

  /// While the app is open, how often to ask for changes made elsewhere.
  final Duration whileOpen;
}

final syncTimingProvider = Provider<SyncTiming>((ref) => const SyncTiming());

/// Runs sync on its own while someone is signed in: right away (signing
/// in, launching), shortly after any edit, when the app comes back to the
/// screen, and every so often while it's open. Silent when offline — the
/// changes wait on the phone and go next time.
final syncProvider = NotifierProvider<SyncController, SyncStatus>(SyncController.new);

class SyncController extends Notifier<SyncStatus> {
  String? _accountId;
  StreamSubscription<void>? _edits;
  Timer? _debounce;
  Timer? _ticker;
  AppLifecycleListener? _lifecycle;

  @override
  SyncStatus build() {
    ref.listen(accountProvider, (_, account) => _follow(account));
    ref.onDispose(() => _stop(disposing: true));
    Future.microtask(() => _follow(ref.read(accountProvider)));
    return const SyncOff();
  }

  void _follow(AccountState account) {
    if (!ref.mounted) return;
    final id = account is SignedIn ? account.user.id : null;
    // The account refreshing itself from the server is the same account.
    if (id == _accountId) return;
    _stop();
    if (id != null) _start(id);
  }

  void _start(String accountId) {
    _accountId = accountId;
    final db = ref.read(databaseProvider);
    final timing = ref.read(syncTimingProvider);

    // Any write to the synced tables may be an edit to send. (The queue
    // itself is filled by database triggers, which this can't see.) Sync's
    // own writes land here too, but leave the queue empty — so the check
    // below skips them rather than starting another round.
    _edits = db.tableUpdates(TableUpdateQuery.onAllTables([db.categories, db.items, db.trips, db.tripItems])).listen((
      _,
    ) {
      _debounce?.cancel();
      _debounce = Timer(timing.afterEdit, _syncIfQueued);
    });
    _lifecycle = AppLifecycleListener(
      onResume: () {
        syncNow();
        _tick(timing);
      },
      onPause: () => _ticker?.cancel(),
    );
    _tick(timing);
    state = const Syncing();
    syncNow();
  }

  void _tick(SyncTiming timing) {
    _ticker?.cancel();
    _ticker = Timer.periodic(timing.whileOpen, (_) => syncNow());
  }

  void _stop({bool disposing = false}) {
    _accountId = null;
    _edits?.cancel();
    _edits = null;
    _debounce?.cancel();
    _ticker?.cancel();
    _lifecycle?.dispose();
    _lifecycle = null;
    if (!disposing) state = const SyncOff();
  }

  Future<void> _syncIfQueued() async {
    final db = ref.read(databaseProvider);
    final queued = await db.select(db.syncOutbox).get();
    final deleted = await db.select(db.syncDeletions).get();
    if (queued.isNotEmpty || deleted.isNotEmpty) await syncNow();
  }

  /// Syncs now, if signed in. Never throws: how it went is the [state].
  Future<void> syncNow() async {
    final accountId = _accountId;
    if (accountId == null) return;
    try {
      await ref.read(syncEngineProvider).sync(accountId: accountId);
      if (ref.mounted && _accountId == accountId) state = SyncDone(DateTime.now());
    } on NetworkException {
      if (ref.mounted && _accountId == accountId) state = const SyncOffline();
    } on SessionExpiredException {
      // Signed out by the server — the account state shows it.
    } on Object catch (e, stack) {
      debugPrint('Sync failed: $e\n$stack');
      if (ref.mounted && _accountId == accountId) state = const SyncFailed();
    }
  }
}
