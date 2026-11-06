/// The server's POST /sync, in memory — the same rules as its
/// `src/sync/sync.ts`: the later edit wins, a deletion leaves a tombstone,
/// changes are numbered and fetched "after number N", and a device's own
/// changes aren't sent back to it.
class FakeSyncServer {
  int _seq = 0;

  /// "entity:key" → the row as sent, plus its number under 'seq'.
  final rows = <String, Map<String, dynamic>>{};
  final tombstones = <String, ({int deletedAt, int seq})>{};
  int requests = 0;

  /// Runs while a request is "on its way" — to change things meanwhile.
  Future<void> Function()? whileHandling;

  static const _lists = {'categories': 'categories', 'items': 'items', 'trips': 'trips', 'tripItems': 'trip_items'};

  static String _key(String entity, Map<String, dynamic> row) =>
      entity == 'trip_items' ? '${row['tripUuid']}/${row['itemUuid']}' : row['uuid'] as String;

  /// Rows of one kind currently stored.
  List<Map<String, dynamic>> stored(String entity) => [
        for (final MapEntry(:key, :value) in rows.entries)
          if (key.startsWith('$entity:')) value,
      ];

  Future<Map<String, dynamic>> handle(Map<String, dynamic> body) async {
    requests++;
    await whileHandling?.call();
    final sent = <String>{};
    final changes = (body['changes'] as Map<String, dynamic>?) ?? const {};

    for (final MapEntry(key: list, value: entity) in _lists.entries) {
      for (final row in (changes[list] as List? ?? const []).cast<Map<String, dynamic>>()) {
        final id = '$entity:${_key(entity, row)}';
        final at = row['updatedAt'] as int;
        final tomb = tombstones[id];
        if (tomb != null && at <= tomb.deletedAt) continue;
        tombstones.remove(id);
        sent.add('$id:$at');
        final existing = rows[id];
        if (existing != null && (existing['updatedAt'] as int) >= at) continue;
        rows[id] = {...row, 'seq': ++_seq};
      }
    }

    for (final d in (body['deletions'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final id = '${d['entity']}:${(d['key'] as String).toLowerCase()}';
      final at = d['deletedAt'] as int;
      final existing = rows[id];
      if (existing != null && (existing['updatedAt'] as int) > at) continue;
      rows.remove(id);
      sent.add('deleted:$id:$at');
      final tomb = tombstones[id];
      if (tomb == null || tomb.deletedAt < at) tombstones[id] = (deletedAt: at, seq: ++_seq);
    }

    final cursor = body['cursor'] as int;
    final limit = body['limit'] as int? ?? 500;
    final all = [
      for (final MapEntry(:key, :value) in rows.entries)
        if ((value['seq'] as int) > cursor) (seq: value['seq'] as int, id: key, row: value, deletedAt: null),
      for (final MapEntry(:key, :value) in tombstones.entries)
        if (value.seq > cursor) (seq: value.seq, id: key, row: null, deletedAt: value.deletedAt),
    ]..sort((a, b) => a.seq.compareTo(b.seq));
    final page = all.take(limit).toList();

    final out = {for (final list in _lists.keys) list: <Map<String, dynamic>>[]};
    final deletions = <Map<String, dynamic>>[];
    for (final e in page) {
      final [entity, key] = e.id.split(RegExp(r':(?=[^:]*$)'));
      if (e.row case final row?) {
        if (sent.contains('${e.id}:${row['updatedAt']}')) continue;
        final list = _lists.entries.firstWhere((l) => l.value == entity).key;
        out[list]!.add({...row}..remove('seq'));
      } else if (!sent.contains('deleted:${e.id}:${e.deletedAt}')) {
        deletions.add({'entity': entity, 'key': key, 'deletedAt': e.deletedAt});
      }
    }
    return {
      'cursor': page.isEmpty ? cursor : page.last.seq,
      'hasMore': all.length > limit,
      'changes': out,
      'deletions': deletions,
    };
  }
}
