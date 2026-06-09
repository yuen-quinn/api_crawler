import '../adapter/api_adapter.dart';
import '../core/crawl_context.dart';
import '../core/crawl_lifecycle.dart';
import '../core/crawl_mode.dart';

/// 定时爬取任务配置。
class CrawlSchedule {
  const CrawlSchedule._({
    required this.name,
    required this.adapter,
    this.mode = CrawlMode.full,
    this.options = const CrawlOptions(),
    this.lifecycle,
    this.runOnStart = false,
    this.cron,
    this.interval,
  }) : assert(
          cron != null || interval != null,
          'cron 与 interval 至少提供一个',
        );

  /// Cron 表达式调度（标准 5 段或带秒的 6 段）。
  ///
  /// 示例：
  /// - `0 */6 * * *` — 每 6 小时
  /// - `0 2 * * *` — 每天凌晨 2 点
  /// - `*/30 * * * * *` — 每 30 秒（6 段，含秒）
  factory CrawlSchedule.cron({
    required String name,
    required String expression,
    required ApiAdapter adapter,
    CrawlMode mode = CrawlMode.full,
    CrawlOptions options = const CrawlOptions(),
    CrawlLifecycle? lifecycle,
    bool runOnStart = false,
  }) =>
      CrawlSchedule._(
        name: name,
        adapter: adapter,
        mode: mode,
        options: options,
        lifecycle: lifecycle,
        runOnStart: runOnStart,
        cron: expression,
      );

  /// 固定间隔调度。
  factory CrawlSchedule.every({
    required String name,
    required Duration interval,
    required ApiAdapter adapter,
    CrawlMode mode = CrawlMode.full,
    CrawlOptions options = const CrawlOptions(),
    CrawlLifecycle? lifecycle,
    bool runOnStart = false,
  }) =>
      CrawlSchedule._(
        name: name,
        adapter: adapter,
        mode: mode,
        options: options,
        lifecycle: lifecycle,
        runOnStart: runOnStart,
        interval: interval,
      );

  /// 任务名称，用于日志与并发锁。
  final String name;
  final ApiAdapter adapter;
  final CrawlMode mode;
  final CrawlOptions options;
  final CrawlLifecycle? lifecycle;

  /// 调度器 [CrawlScheduler.start] 时是否立即执行一次。
  final bool runOnStart;

  /// Cron 表达式；与 [interval] 二选一。
  final String? cron;

  /// 固定间隔；与 [cron] 二选一。
  final Duration? interval;
}
