import '../core/crawl_item.dart';
import '../core/crawl_mode.dart';

/// 记录查询过滤条件。
class ResourceFilter {
  const ResourceFilter({
    this.namespace,
    this.status,
    this.updatedBefore,
  });

  final String? namespace;
  final SyncStatus? status;
  final DateTime? updatedBefore;
}

/// 爬取记录存储抽象。
abstract class RecordStore {
  Future<CrawlRecord?> get(ResourceId id);

  Future<void> upsert(CrawlRecord record);

  Future<void> markDeleted(ResourceId id, {String? reason});

  Stream<ResourceId> listIds({ResourceFilter? filter});

  Future<int> count({ResourceFilter? filter});
}
