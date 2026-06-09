import '../core/crawl_context.dart';
import '../core/crawl_item.dart';

/// 管道阶段：接收一批 [CrawlItem]，处理后返回下一阶段的条目。
abstract class PipelineStage {
  String get name;

  Future<List<CrawlItem>> process(
    CrawlContext ctx,
    List<CrawlItem> batch,
  );
}

/// 可组合的处理管道。
class Pipeline {
  Pipeline(this.stages);

  final List<PipelineStage> stages;

  Future<BatchResult> run(CrawlContext ctx, List<CrawlItem> batch) async {
    var items = batch;
    for (final stage in stages) {
      if (items.isEmpty) break;
      items = await stage.process(ctx, items);
    }
    return BatchResult(items);
  }
}

/// 单批管道执行结果。
class BatchResult {
  BatchResult(this.items);
  final List<CrawlItem> items;
}
