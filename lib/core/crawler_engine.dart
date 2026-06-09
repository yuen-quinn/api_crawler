import '../adapter/api_adapter.dart';
import '../util/crawl_logging.dart';
import '../core/crawl_context.dart';
import '../core/crawl_item.dart';
import '../core/crawl_job.dart';
import '../core/crawl_lifecycle.dart';
import '../core/crawl_mode.dart';
import '../core/event_bus.dart';
import '../core/pipeline.dart';
import '../metrics/crawl_metrics.dart';
import '../stages/dedupe_stage.dart';
import '../stages/emit_stage.dart';
import '../stages/fetch_stage.dart';
import '../stages/persist_stage.dart';
import '../stages/transform_stage.dart';
import '../store/checkpoint_store.dart';
import '../store/dead_letter_store.dart';
import '../store/record_store.dart';
import '../transport/transport.dart';

/// 爬虫引擎：编排发现、分批、管道执行与检查点。
class CrawlerEngine {
  CrawlerEngine({
    required this.recordStore,
    required this.checkpointStore,
    required this.deadLetterStore,
    required this.transport,
    Pipeline? pipeline,
    EventBus? events,
    this.logging = const CrawlLoggingOptions(),
  })  : pipeline = pipeline ?? defaultPipeline(),
        events = events ?? EventBus() {
    applyCrawlLogging(logging);
  }

  final RecordStore recordStore;
  final CheckpointStore checkpointStore;
  final DeadLetterStore deadLetterStore;
  final Transport transport;
  final Pipeline pipeline;
  final EventBus events;

  /// 日志配置。
  final CrawlLoggingOptions logging;

  /// 默认管道：抓取 → 解析 → 去重 → 持久化 → 发射。
  static Pipeline defaultPipeline() => Pipeline([
        FetchStage(),
        TransformStage(),
        DedupeStage(),
        PersistStage(),
        EmitStage(),
      ]);

  Future<CrawlResult> run({
    required ApiAdapter adapter,
    required CrawlMode mode,
    CrawlOptions options = const CrawlOptions(),
    CrawlLifecycle? lifecycle,
  }) async {
    final job = CrawlJob(
      id: '${adapter.namespace}-${DateTime.now().toUtc().millisecondsSinceEpoch}',
      mode: mode,
      adapter: adapter,
      options: options,
    );

    final checkpoint =
        await checkpointStore.load(adapter.namespace, mode) ??
            CrawlCheckpoint.empty(adapter.namespace, mode);

    final ctx = CrawlContext(
      job: job,
      adapter: adapter,
      transport: transport,
      recordStore: recordStore,
      checkpointStore: checkpointStore,
      deadLetterStore: deadLetterStore,
      metrics: CrawlMetrics(),
      events: events,
      logging: logging,
      checkpoint: checkpoint,
    );

    final log = crawlLog('engine');
    log.info(
      '任务开始 id=${job.id} mode=${mode.name} '
      'adapter=${adapter.namespace} batchSize=${options.batchSize}',
    );
    if (checkpoint.state['last_cursor'] != null) {
      log.info('检查点游标=${checkpoint.state['last_cursor']} processed=${checkpoint.processed}');
    }

    try {
      await lifecycle?.onStart?.call(ctx);
      await adapter.onStart(ctx);

      var processedInJob = 0;
      await for (final batch in _discoverBatches(ctx, mode, options)) {
        ctx.metrics.discovered += batch.length;
        await lifecycle?.onBatchStart?.call(ctx, batch);
        final result = await pipeline.run(ctx, batch);
        await lifecycle?.onBatchComplete?.call(ctx, batch, result);
        processedInJob += batch.length;

        ctx.checkpoint = ctx.checkpoint.copyWith(
          processed: ctx.checkpoint.processed + batch.length,
          cursor: ctx.checkpoint.state['last_cursor'] as String? ??
              ctx.checkpoint.cursor,
        );
        await checkpointStore.save(ctx.checkpoint);

        events.emit(
          BatchCompleted(
            batch.length,
            result.items.length,
            batch.length - result.items.length,
          ),
        );

        log.info(
          '批次完成 size=${batch.length} '
          'discovered=${ctx.metrics.discovered} fetched=${ctx.metrics.fetched} '
          'upserted=${ctx.metrics.upserted} skipped=${ctx.metrics.skipped} '
          'failed=${ctx.metrics.failed}',
        );

        if (options.limit != null && processedInJob >= options.limit!) {
          log.info('已达 limit=${options.limit}，停止发现');
          break;
        }
      }

      final snapshot = ctx.metrics.snapshot();
      log.info('任务完成 $snapshot');
      final crawlResult = CrawlResult.success(job.id, snapshot);
      await lifecycle?.onComplete?.call(ctx, crawlResult);
      await adapter.onComplete(ctx, crawlResult);
      return crawlResult;
    } on Object catch (error, stack) {
      log.severe('任务失败', error, stack);
      final crawlResult = CrawlResult.failure(job.id, ctx.metrics.snapshot(), error);
      await lifecycle?.onError?.call(ctx, error, stack);
      return crawlResult;
    } finally {
      await lifecycle?.onFinally?.call(ctx);
      await adapter.onDispose(ctx);
      crawlLog('engine').fine('任务清理完成');
    }
  }

  /// 将发现流按 [CrawlOptions.batchSize] 分批产出。
  Stream<List<CrawlItem>> _discoverBatches(
    CrawlContext ctx,
    CrawlMode mode,
    CrawlOptions options,
  ) async* {
    final buffer = <CrawlItem>[];
    await for (final item in ctx.adapter.discover(ctx: ctx, mode: mode)) {
      buffer.add(item);
      if (buffer.length >= options.batchSize) {
        yield List<CrawlItem>.from(buffer);
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) {
      yield buffer;
    }
  }
}
