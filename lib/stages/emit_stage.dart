import '../core/crawl_context.dart';
import '../core/crawl_item.dart';
import '../core/pipeline.dart';

/// 发射阶段占位；事件由 [PersistStage] 发出，可扩展为外部 sink。
class EmitStage implements PipelineStage {
  @override
  String get name => 'emit';

  @override
  Future<List<CrawlItem>> process(
    CrawlContext ctx,
    List<CrawlItem> batch,
  ) async =>
      batch;
}
