import '../adapter/api_adapter.dart';
import '../core/crawl_mode.dart';
import '../metrics/crawl_metrics.dart';
import 'crawl_context.dart';

/// 一次爬取任务的描述。
class CrawlJob {
  CrawlJob({
    required this.id,
    required this.mode,
    required this.adapter,
    required this.options,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now().toUtc();

  final String id;
  final CrawlMode mode;
  final ApiAdapter adapter;
  final CrawlOptions options;
  final DateTime startedAt;
}

/// 任务执行结果。
class CrawlResult {
  CrawlResult({
    required this.jobId,
    required this.success,
    required this.metrics,
    this.error,
  });

  final String jobId;
  final bool success;
  final CrawlMetricsSnapshot metrics;
  final Object? error;

  factory CrawlResult.success(String jobId, CrawlMetricsSnapshot metrics) {
    return CrawlResult(jobId: jobId, success: true, metrics: metrics);
  }

  factory CrawlResult.failure(
    String jobId,
    CrawlMetricsSnapshot metrics,
    Object error,
  ) {
    return CrawlResult(
      jobId: jobId,
      success: false,
      metrics: metrics,
      error: error,
    );
  }
}
