import '../adapter/api_adapter.dart';
import '../resilience/rate_limiter.dart';
import '../store/file_stores.dart';
import '../store/in_memory_stores.dart';
import '../store/record_store.dart';
import '../transport/http_transport.dart';
import '../util/crawl_logging.dart';
import 'crawl_context.dart';
import 'crawl_item.dart';
import 'crawl_job.dart';
import 'crawl_lifecycle.dart';
import 'crawl_mode.dart';
import 'crawler_engine.dart';

/// 高层入口，提供开箱即用的默认配置。
class Crawler {
  Crawler._(this._engine, this._recordStore);

  final CrawlerEngine _engine;
  final RecordStore _recordStore;

  /// 记录存储，可用于统计或自定义查询。
  RecordStore get recordStore => _recordStore;

  /// 使用自定义引擎，保留简化的 [run] API。
  factory Crawler.withEngine({
    required CrawlerEngine engine,
    required RecordStore recordStore,
  }) =>
      Crawler._(engine, recordStore);

  /// 文件存储 + 检查点，支持分页断点续爬。
  factory Crawler.persistent({
    String dataDir = './data',
    Duration requestInterval = const Duration(milliseconds: 200),
    CrawlLoggingOptions logging = const CrawlLoggingOptions.console(),
  }) {
    final recordStore = FileRecordStore('$dataDir/records');
    return Crawler._(
      CrawlerEngine(
        recordStore: recordStore,
        checkpointStore: FileCheckpointStore('$dataDir/checkpoints'),
        deadLetterStore: InMemoryDeadLetterStore(),
        transport: HttpTransport(
          rateLimiter: RateLimiter(minInterval: requestInterval),
        ),
        logging: logging,
      ),
      recordStore,
    );
  }

  /// 内存存储 + HTTP 传输 + 限速，适合本地开发与示例。
  factory Crawler.local({
    Duration requestInterval = const Duration(milliseconds: 200),
    CrawlLoggingOptions logging = const CrawlLoggingOptions.console(),
  }) {
    final recordStore = InMemoryRecordStore();
    return Crawler._(
      CrawlerEngine(
        recordStore: recordStore,
        checkpointStore: InMemoryCheckpointStore(),
        deadLetterStore: InMemoryDeadLetterStore(),
        transport: HttpTransport(
          rateLimiter: RateLimiter(minInterval: requestInterval),
        ),
        logging: logging,
      ),
      recordStore,
    );
  }

  /// 执行一次爬取，仅返回任务结果（适合定时任务，不加载全部记录）。
  Future<CrawlResult> runOnce({
    required ApiAdapter adapter,
    CrawlMode mode = CrawlMode.full,
    CrawlOptions? options,
    CrawlLifecycle? lifecycle,
  }) =>
      _engine.run(
        adapter: adapter,
        mode: mode,
        options: options ?? const CrawlOptions(),
        lifecycle: lifecycle,
      );

  /// 执行爬取并返回结果与全部记录。
  Future<CrawlRun> run({
    required ApiAdapter adapter,
    CrawlMode mode = CrawlMode.full,
    CrawlOptions? options,
    CrawlLifecycle? lifecycle,
  }) async {
    final result = await runOnce(
      adapter: adapter,
      mode: mode,
      options: options,
      lifecycle: lifecycle,
    );

    final records = <CrawlRecord>[];
    await for (final id in _recordStore.listIds()) {
      final record = await _recordStore.get(id);
      if (record != null) records.add(record);
    }

    return CrawlRun(result: result, records: records);
  }
}

/// [Crawler.run] 的返回值，包含任务结果与存储中的记录列表。
class CrawlRun {
  const CrawlRun({required this.result, required this.records});

  final CrawlResult result;
  final List<CrawlRecord> records;
}
