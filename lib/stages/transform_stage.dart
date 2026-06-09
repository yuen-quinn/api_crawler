import '../core/crawl_context.dart';
import '../core/crawl_item.dart';
import '../core/pipeline.dart';
import '../store/dead_letter_store.dart';

/// 解析阶段：调用适配器 [ApiAdapter.parse] 将原始响应转为 [CrawlRecord]。
class TransformStage implements PipelineStage {
  @override
  String get name => 'transform';

  @override
  Future<List<CrawlItem>> process(
    CrawlContext ctx,
    List<CrawlItem> batch,
  ) async {
    final results = <CrawlItem>[];

    for (final item in batch) {
      try {
        final record = ctx.adapter.parse(item, item.rawByEndpoint);
        if (record == null) {
          ctx.metrics.skipped++;
          continue;
        }
        ctx.metrics.parsed++;
        results.add(item.copyWith(record: record));
      } on Object catch (error) {
        ctx.metrics.failed++;
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
