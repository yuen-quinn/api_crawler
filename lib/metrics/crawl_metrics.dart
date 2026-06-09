/// 爬取过程计数器（可变，任务内累积）。
class CrawlMetrics {
  /// 发现的资源数。
  int discovered = 0;

  /// 成功发起的 HTTP 请求数。
  int fetched = 0;

  /// 成功解析的记录数。
  int parsed = 0;

  /// 写入存储的记录数。
  int upserted = 0;

  /// 跳过的资源数（无需抓取或内容未变）。
  int skipped = 0;

  /// 失败的资源数。
  int failed = 0;

  /// 标记删除的资源数。
  int deleted = 0;

  final DateTime startedAt = DateTime.now().toUtc();

  CrawlMetricsSnapshot snapshot() => CrawlMetricsSnapshot(
        discovered: discovered,
        fetched: fetched,
        parsed: parsed,
        upserted: upserted,
        skipped: skipped,
        failed: failed,
        deleted: deleted,
        elapsed: DateTime.now().toUtc().difference(startedAt),
      );
}

/// 指标快照（不可变，任务结束时产出）。
class CrawlMetricsSnapshot {
  const CrawlMetricsSnapshot({
    required this.discovered,
    required this.fetched,
    required this.parsed,
    required this.upserted,
    required this.skipped,
    required this.failed,
    required this.deleted,
    required this.elapsed,
  });

  final int discovered;
  final int fetched;
  final int parsed;
  final int upserted;
  final int skipped;
  final int failed;
  final int deleted;
  final Duration elapsed;

  Map<String, Object?> toJson() => {
        'discovered': discovered,
        'fetched': fetched,
        'parsed': parsed,
        'upserted': upserted,
        'skipped': skipped,
        'failed': failed,
        'deleted': deleted,
        'elapsed_ms': elapsed.inMilliseconds,
      };

  @override
  String toString() => jsonLike(toJson());

  static String jsonLike(Map<String, Object?> map) => map.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join(', ');
}
