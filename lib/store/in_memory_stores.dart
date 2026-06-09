import '../core/crawl_item.dart';
import '../core/crawl_mode.dart';
import 'checkpoint_store.dart';
import 'dead_letter_store.dart';
import 'record_store.dart';

/// 内存记录存储，适用于测试与快速原型。
class InMemoryRecordStore implements RecordStore {
  final _records = <String, CrawlRecord>{};

  String _key(ResourceId id) => id.canonical;

  @override
  Future<CrawlRecord?> get(ResourceId id) async => _records[_key(id)];

  @override
  Future<void> upsert(CrawlRecord record) async {
    _records[_key(record.id)] = record;
  }

  @override
  Future<void> markDeleted(ResourceId id, {String? reason}) async {
    final existing = _records[_key(id)];
    if (existing != null) {
      _records[_key(id)] = existing.copyWith(status: SyncStatus.deleted);
    }
  }

  @override
  Stream<ResourceId> listIds({ResourceFilter? filter}) async* {
    for (final record in _records.values) {
      if (_matches(record, filter)) {
        yield record.id;
      }
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
    if (filter.updatedBefore != null &&
        record.extractedAt.isAfter(filter.updatedBefore!)) {
      return false;
    }
    return true;
  }
}

/// 内存检查点存储。
class InMemoryCheckpointStore implements CheckpointStore {
  final _checkpoints = <String, CrawlCheckpoint>{};

  String _key(String namespace, CrawlMode mode) => '$namespace:${mode.name}';

  @override
  Future<CrawlCheckpoint?> load(String namespace, CrawlMode mode) async {
    return _checkpoints[_key(namespace, mode)];
  }

  @override
  Future<void> save(CrawlCheckpoint checkpoint) async {
    _checkpoints[_key(checkpoint.namespace, checkpoint.mode)] = checkpoint;
  }
}

/// 内存死信队列。
class InMemoryDeadLetterStore implements DeadLetterStore {
  final _items = <String, DeadLetterItem>{};

  @override
  Future<void> push(DeadLetterItem item) async {
    _items[item.id.canonical] = item;
  }

  @override
  Stream<DeadLetterItem> list({int? limit}) async* {
    var count = 0;
    for (final item in _items.values) {
      yield item;
      count++;
      if (limit != null && count >= limit) break;
    }
  }

  @override
  Future<void> clear(ResourceId id) async {
    _items.remove(id.canonical);
  }
}
