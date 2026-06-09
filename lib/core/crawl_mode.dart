/// 爬取模式。
enum CrawlMode {
  /// 全量同步。
  full,

  /// 增量更新（由适配器定义发现逻辑）。
  incremental,

  /// 历史回填（由适配器定义范围）。
  backfill,

  /// 按 ID 抓取，配合 [CrawlOptions.singleIds]。
  single,

  /// 对账：修复漂移、处理已删除资源。
  reconcile,
}

/// 资源对账时的处置方式。
enum ItemDisposition {
  keep,
  delete,
  retry,
  skip,
}

/// HTTP 方法。
enum HttpMethod {
  get,
  post,
  put,
  patch,
  delete,
}

/// 记录在存储中的同步状态。
enum SyncStatus {
  active,
  deleted,
  failed,
}
