import '../adapter/api_adapter.dart';
import '../metrics/crawl_metrics.dart';
import '../store/checkpoint_store.dart';
import '../store/dead_letter_store.dart';
import '../store/record_store.dart';
import '../transport/transport.dart';
import '../util/crawl_logging.dart';
import 'crawl_job.dart';
import 'event_bus.dart';

/// 单次爬取任务的运行参数。
class CrawlOptions {
  const CrawlOptions({
    this.batchSize = 50,
    this.concurrency = 4,
    this.requestInterval = const Duration(milliseconds: 100),
    this.dryRun = false,
    this.limit,
    this.params = const {},
    this.singleIds = const [],
    this.since,
  });

  /// 每批处理的资源数量。
  final int batchSize;

  /// 批内并发请求数。
  final int concurrency;

  /// 请求间隔（供传输层参考）。
  final Duration requestInterval;

  /// 为 true 时不写入存储，仅统计。
  final bool dryRun;

  /// 最多处理的资源数；为 null 时不限制（分页将一直爬到没有下一页）。
  final int? limit;

  /// 自定义参数，可在适配器或生命周期中共享。
  final Map<String, Object?> params;

  /// [CrawlMode.single] 模式下要抓取的 ID 列表。
  final List<String> singleIds;

  /// 增量同步的起始时间（由适配器解释）。
  final DateTime? since;
}

/// 爬取上下文：贯穿发现、管道、存储的共享状态。
class CrawlContext {
  CrawlContext({
    required this.job,
    required this.adapter,
    required this.transport,
    required this.recordStore,
    required this.checkpointStore,
    required this.deadLetterStore,
    required this.metrics,
    required this.events,
    this.logging = const CrawlLoggingOptions(),
    CrawlCheckpoint? checkpoint,
  }) : checkpoint = checkpoint ?? CrawlCheckpoint.empty(adapter.namespace, job.mode);

  final CrawlJob job;
  final ApiAdapter adapter;
  final Transport transport;
  final RecordStore recordStore;
  final CheckpointStore checkpointStore;
  final DeadLetterStore deadLetterStore;
  final CrawlMetrics metrics;
  final EventBus events;

  /// 日志配置（含 [CrawlLoggingOptions.logRequests]）。
  final CrawlLoggingOptions logging;

  /// 当前检查点，分页游标等状态保存在此。
  CrawlCheckpoint checkpoint;

  CrawlOptions get options => job.options;
}
