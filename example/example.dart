import 'package:api_crawler/api_crawler.dart';

/// pub.dev 全量分页爬取：列表 → 详情 + 得分，直到没有下一页。
///
/// ```bash
/// dart run example/example.dart
/// ```
Future<void> main() async {
  final crawler = Crawler.persistent(
    dataDir: './data',
    logging: const CrawlLoggingOptions.console(logRequests: true),
  );

  final run = await crawler.run(
    adapter: MultiSimpleAdapter(
      namespace: 'pubdev',
      discoverKeys: (ctx, _) => keysFromNextUrlPages(
        ctx: ctx,
        firstUrl: Uri.parse('https://pub.dev/api/packages'),
        itemsField: 'packages',
        keyField: 'name',
      ),
      endpoints: {
        'package': (name) => Uri.parse('https://pub.dev/api/packages/$name'),
        'score': (name) => Uri.parse('https://pub.dev/api/packages/$name/score'),
      },
      parseResponses: (name, bodies) {
        final detail = bodies['package'];
        final score = bodies['score'];
        if (detail is! Map) return null;

        final latest = detail['latest'];
        final pubspec = latest is Map ? latest['pubspec'] : null;
        final versions = detail['versions'];

        return {
          'name': detail['name'] ?? name,
          'latest_version': latest is Map ? latest['version'] : null,
          'description': pubspec is Map ? pubspec['description'] : null,
          'version_count': versions is List ? versions.length : null,
          if (score is Map) ...{
            'granted_points': score['grantedPoints'],
            'max_points': score['maxPoints'],
            'likes': score['likeCount'],
            'downloads_30d': score['downloadCount30Days'],
          },
        };
      },
    ),
    options: const CrawlOptions(batchSize: 50, concurrency: 2),
  );

  final total = await crawler.recordStore.count();
  crawlLog('example').info(
    '完成 success=${run.result.success} records=$total metrics=${run.result.metrics}',
  );
}
