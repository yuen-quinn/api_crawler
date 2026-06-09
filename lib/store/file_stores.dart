import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/crawl_item.dart';
import '../core/crawl_mode.dart';
import 'checkpoint_store.dart';
import 'record_store.dart';

/// 基于 JSON 文件的记录存储，适用于本地开发。
class FileRecordStore implements RecordStore {
  FileRecordStore(this.root) {
    Directory(root).createSync(recursive: true);
  }

  final String root;

  File _file(ResourceId id) =>
      File(p.join(root, '${id.namespace}__${id.key}.json'));

  @override
  Future<CrawlRecord?> get(ResourceId id) async {
    final file = _file(id);
    if (!file.existsSync()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return CrawlRecord.fromJson(json);
  }

  @override
  Future<void> upsert(CrawlRecord record) async {
    await _file(record.id).writeAsString(jsonEncode(record.toJson()));
  }

  @override
  Future<void> markDeleted(ResourceId id, {String? reason}) async {
    final existing = await get(id);
    if (existing != null) {
      await upsert(existing.copyWith(status: SyncStatus.deleted));
    }
  }

  @override
  Stream<ResourceId> listIds({ResourceFilter? filter}) async* {
    final dir = Directory(root);
    if (!dir.existsSync()) return;
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final record = CrawlRecord.fromJson(
        jsonDecode(await entity.readAsString()) as Map<String, Object?>,
      );
      if (_matches(record, filter)) yield record.id;
    }
  }

  @override
  Future<int> count({ResourceFilter? filter}) async {
    var total = 0;
    await for (final _ in listIds(filter: filter)) {
      total++;
    }
    return total;
  }

  bool _matches(CrawlRecord record, ResourceFilter? filter) {
    if (filter == null) return true;
    if (filter.namespace != null && record.id.namespace != filter.namespace) {
      return false;
    }
    if (filter.status != null && record.status != filter.status) {
      return false;
    }
    return true;
  }
}

/// 基于 JSON 文件的检查点存储。
class FileCheckpointStore implements CheckpointStore {
  FileCheckpointStore(this.root) {
    Directory(root).createSync(recursive: true);
  }

  final String root;

  File _file(String namespace, CrawlMode mode) =>
      File(p.join(root, '${namespace}_${mode.name}.json'));

  @override
  Future<CrawlCheckpoint?> load(String namespace, CrawlMode mode) async {
    final file = _file(namespace, mode);
    if (!file.existsSync()) return null;
    return CrawlCheckpoint.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, Object?>,
    );
  }

  @override
  Future<void> save(CrawlCheckpoint checkpoint) async {
    await _file(checkpoint.namespace, checkpoint.mode)
        .writeAsString(jsonEncode(checkpoint.toJson()));
  }
}
