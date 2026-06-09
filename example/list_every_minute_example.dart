import 'package:api_crawler/api_crawler.dart';

/// 每分钟拉取一次 pub.dev 包列表（仅列表 API，不抓详情）。
///
/// ```bash
/// dart run example/list_every_minute_example.dart
/// ```
///
/// 每次请求 `GET https://pub.dev/api/packages`，保存当前页包名快照。
/// 按 Ctrl+C 结束进程（或调用 `scheduler.stop()`）。
Future<void> main() async {
  final crawler = Crawler.persistent(
    dataDir: './data-list-minute',
    logging: const CrawlLoggingOptions.console(logRequests: true),
  );

  final scheduler = CrawlScheduler(crawler: crawler);

  scheduler.add(
    CrawlSchedule.every(
      name: 'pubdev-list',
      interval: const Duration(minutes: 1),
      adapter: _PubDevListAdapter(),
      runOnStart: true,
      lifecycle: CrawlLifecycle(
        onFinally: (_) => crawlLog('list').info('本轮列表抓取结束'),
      ),
    ),
  );

  await scheduler.start();
  crawlLog('list').info('每分钟拉取列表，scheduler.stop() 或 Ctrl+C 结束');

  await scheduler.join();
}

/// 只请求列表接口，将包名列表存为一条快照记录。
class _PubDevListAdapter extends ApiAdapter {
  static final _listUrl = Uri.parse('https://pub.dev/api/packages');

  @override
  String get namespace => 'pubdev-list';

  @override
  Stream<CrawlItem> discover({
    required CrawlContext ctx,
    required CrawlMode mode,
  }) async* {
    yield const CrawlItem(
      id: ResourceId(namespace: 'pubdev-list', key: 'latest'),
    );
  }

  @override
  Future<List<EndpointSpec>> buildRequests(CrawlItem item) async {
    return [
      EndpointSpec(
        name: 'list',
        method: HttpMethod.get,
        url: _listUrl,
      ),
    ];
  }

  @override
  CrawlRecord? parse(CrawlItem item, Map<String, RawPayload> responses) {
    final body = responses['list']?.body;
    if (body is! Map) return null;

    final rawPackages = body['packages'];
    if (rawPackages is! List) return null;

    final names = <String>[];
    for (final pkg in rawPackages) {
      if (pkg is Map && pkg['name'] is String) {
        names.add(pkg['name'] as String);
      }
    }

    final fields = <String, Object?>{
      'package_count': names.length,
      'packages': names,
      'next_url': body['next_url'],
      'fetched_at': DateTime.now().toUtc().toIso8601String(),
    };

    return CrawlRecord(
      id: item.id,
      fields: fields,
      contentHash: computeContentHash(fields),
      extractedAt: DateTime.now().toUtc(),
    );
  }
}
