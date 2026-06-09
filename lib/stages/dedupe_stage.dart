import '../core/crawl_context.dart';
import '../core/crawl_item.dart';
import '../core/pipeline.dart';

/// 去重阶段：跳过内容哈希未变的记录。
class DedupeStage implements PipelineStage {
  @override
  String get name => 'dedupe';

  @override
  Future<List<CrawlItem>> process(
    CrawlContext ctx,
    List<CrawlItem> batch,
  ) async {
    final results = <CrawlItem>[];

    for (final item in batch) {
      final record = item.record;
      if (record == null) continue;

      final existing = await ctx.recordStore.get(item.id);
      if (existing != null && existing.contentHash == record.contentHash) {
        ctx.metrics.skipped++;
        continue;
      }

      results.add(item);
    }

    return results;
  }
}
