import 'package:api_crawler/api_crawler.dart';

/// 定时爬取 pub.dev 示例。
///
/// ```bash
/// dart run example/cron_example.dart
/// ```
///
/// 演示两种调度方式：
/// - Cron：`0 */6 * * *` 每 6 小时
/// - 间隔：每 30 分钟（示例中改为 2 分钟便于观察，实际使用请调大）
Future<void> main() async {
  final crawler = Crawler.persistent(
    dataDir: './data',
    logging: const CrawlLoggingOptions.console(logRequests: true),
  );

  final adapter = MultiSimpleAdapter(
    namespace: 'pubdev',
    discoverKeys: (ctx, _) => keysFromNextUrlPages(
      ctx: ctx,
      firstUrl: Uri.parse('https://pub.dev/api/packages'),
      itemsField: 'packages',
      keyField: 'name',
      limit: ctx.options.limit,
    ),
    endpoints: {
      'package': (name) => Uri.parse('https://pub.dev/api/packages/$name'),
      'score': (name) => Uri.parse('https://pub.dev/api/packages/$name/score'),
    },
    parseResponses: (name, bodies) {
      final detail = bodies['package'];
      if (detail is! Map) return null;
      final latest = detail['latest'];
      return {
        'name': detail['name'] ?? name,
        'latest_version': latest is Map ? latest['version'] : null,
      };
    },
  );

  final scheduler = CrawlScheduler(crawler: crawler);

  // 每 6 小时增量爬取（启动时先跑一次）
  scheduler.add(
    CrawlSchedule.cron(
      name: 'pubdev-6h',
      expression: '0 */6 * * *',
      adapter: adapter,
      mode: CrawlMode.incremental,
      options: const CrawlOptions(limit: 20, batchSize: 20),
      runOnStart: true,
    ),
  );

  // 固定间隔（演示用 2 分钟，生产环境请改为 Duration(hours: 1) 等）
  scheduler.add(
    CrawlSchedule.every(
      name: 'pubdev-interval',
      interval: const Duration(minutes: 2),
      adapter: adapter,
      mode: CrawlMode.incremental,
      options: const CrawlOptions(limit: 5, batchSize: 5),
    ),
  );

  await scheduler.start();
  crawlLog('cron_example').info('调度器运行中，调用 scheduler.stop() 结束');

  await scheduler.join();
}
