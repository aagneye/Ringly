import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'local_memo.dart';

/// Memos on disk: one `<id>.json` metadata file per memo, plus `<id>.wav`
/// for voice memos, all under a single directory.
///
/// Plain files rather than a database: the data is small, append-mostly, and
/// this keeps the store trivially inspectable and dependency-free. Writes go
/// through a temp file and a rename so a crash mid-write never leaves a
/// half-written memo.
class LocalMemoStore {
  LocalMemoStore(this.root);

  final Directory root;

  static final _random = Random.secure();

  /// A sortable, collision-resistant id: timestamp plus random suffix.
  static String newId([DateTime? now]) {
    final stamp = (now ?? DateTime.now()).millisecondsSinceEpoch.toRadixString(36);
    final suffix = List.generate(6, (_) => _random.nextInt(36).toRadixString(36)).join();
    return '$stamp$suffix';
  }

  Future<Directory> _dir() => root.create(recursive: true);

  /// Where the recorder should write audio for memo [id].
  Future<String> audioPathFor(String id) async => '${(await _dir()).path}/$id.wav';

  File _metaFile(Directory dir, String id) => File('${dir.path}/$id.json');

  Future<void> save(LocalMemo memo) async {
    final dir = await _dir();
    final target = _metaFile(dir, memo.id);
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(memo.toJson()), flush: true);
    await temp.rename(target.path);
  }

  Future<LocalMemo?> get(String id) async {
    final file = _metaFile(await _dir(), id);
    if (!await file.exists()) return null;
    return _read(file);
  }

  /// All memos, newest first. Unreadable files are skipped, not fatal.
  Future<List<LocalMemo>> list() async {
    final dir = await _dir();
    final memos = <LocalMemo>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final memo = await _read(entity);
        if (memo != null) memos.add(memo);
      }
    }
    memos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return memos;
  }

  /// Read-modify-write one memo. Returns the updated memo, or null if absent.
  Future<LocalMemo?> update(String id, LocalMemo Function(LocalMemo) change) async {
    final current = await get(id);
    if (current == null) return null;
    final next = change(current);
    await save(next);
    return next;
  }

  /// Remove a memo's metadata and its audio file.
  Future<void> delete(String id) async {
    final memo = await get(id);
    final dir = await _dir();
    final meta = _metaFile(dir, id);
    if (await meta.exists()) await meta.delete();
    final audio = memo?.audioPath;
    if (audio != null && await File(audio).exists()) await File(audio).delete();
  }

  Future<LocalMemo?> _read(File file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? LocalMemo.fromJson(decoded) : null;
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }
}
