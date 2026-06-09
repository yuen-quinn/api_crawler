import 'dart:async';

import '../core/crawl_context.dart';
import '../core/crawl_item.dart';
import '../core/crawl_job.dart';
import '../core/pipeline.dart';

typedef CrawlContextCallback = FutureOr<void> Function(CrawlContext ctx);

typedef BatchCallback = FutureOr<void> Function(
  CrawlContext ctx,
  List<CrawlItem> batch,
);

typedef BatchCompleteCallback = FutureOr<void> Function(
  CrawlContext ctx,
  List<CrawlItem> batch,
  BatchResult result,
);

typedef CompleteCallback = FutureOr<void> Function(
  CrawlContext ctx,
  CrawlResult result,
);

typedef ErrorCallback = FutureOr<void> Function(
  CrawlContext ctx,
  Object error,
  StackTrace stack,
);

/// 爬取生命周期钩子，在任务关键节点被调用。
class CrawlLifecycle {
  const CrawlLifecycle({
    this.onStart,
    this.onBatchStart,
    this.onBatchComplete,
    this.onComplete,
    this.onError,
    this.onFinally,
  });

  /// 上下文就绪后、发现开始前调用。
  final CrawlContextCallback? onStart;

  /// 每批进入管道前调用。
  final BatchCallback? onBatchStart;

  /// 每批管道完成后调用。
  final BatchCompleteCallback? onBatchComplete;

  /// 任务成功结束时调用。
  final CompleteCallback? onComplete;

  /// 任务失败时调用。
  final ErrorCallback? onError;

  /// 始终在 `finally` 中调用，适合关闭数据库等资源。
  final CrawlContextCallback? onFinally;

  /// 资源初始化/清理的简写构造，如打开/关闭数据库。
  factory CrawlLifecycle.setup({
    required CrawlContextCallback setup,
    required CrawlContextCallback teardown,
    BatchCallback? onBatchStart,
    BatchCompleteCallback? onBatchComplete,
    CompleteCallback? onComplete,
    ErrorCallback? onError,
  }) =>
      CrawlLifecycle(
        onStart: setup,
        onFinally: teardown,
        onBatchStart: onBatchStart,
        onBatchComplete: onBatchComplete,
        onComplete: onComplete,
        onError: onError,
      );
}
