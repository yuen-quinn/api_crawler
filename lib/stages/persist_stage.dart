import '../util/crawl_logging.dart';
import '../core/crawl_context.dart';
import '../core/crawl_item.dart';
import '../core/event_bus.dart';
import '../core/pipeline.dart';
import '../store/dead_letter_store.dart';

/// 持久化阶段：写入 [RecordStore] 并发射创建/更新事件。
class PersistStage implements PipelineStage {
  static final _log = crawlLog('persist');

  @override
  String get name => 'persist';

  @override
  Future<List<CrawlItem>> process(
    CrawlContext ctx,
    List<CrawlItem> batch,
  ) async {
    if (ctx.options.dryRun) {
      ctx.metrics.upserted += batch.length;
      _log.info('dryRun 跳过写入 ${batch.length} 条');
      return batch;
    }

    final results = <CrawlItem>[];

    for (final item in batch) {
      final record = item.record;
      if (record == null) continue;

      try {
        final existing = await ctx.recordStore.get(item.id);
        await ctx.recordStore.upsert(record);
        ctx.metrics.upserted++;

        if (existing == null) {
          ctx.events.emit(RecordCreated(record));
        } else if (existing.contentHash != record.contentHash ||
            existing.status != record.status) {
          ctx.events.emit(RecordUpdated(record, existing));
        }

        results.add(item);
      } on Object catch (error) {
        ctx.metrics.failed++;
        _log.warning('持久化失败 ${item.id.key}: $error');
        await ctx.deadLetterStore.push(
          DeadLetterItem(
            id: item.id,
            stage: name,
            error: error.toString(),
            attemptedAt: DateTime.now().toUtc(),
          ),
        );
      }
    }

    return results;
  }
}
