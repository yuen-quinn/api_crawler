import '../core/crawl_context.dart';
import '../core/crawl_item.dart';
import '../core/crawl_mode.dart';
import '../util/content_hash.dart';
import 'adapter_types.dart';
import 'api_adapter.dart';

typedef UrlForKey = EndpointUrl;

/// 解析单端点 JSON 响应的回调。
typedef ParseFields = Map<String, Object?>? Function(
  String key,
  Object? body,
);

/// 简化适配器：发现主键 → 单个 GET → 解析，适合单 API 场景。
class SimpleAdapter extends ApiAdapter {
  SimpleAdapter({
    required this.namespace,
    required this.discoverKeys,
    required this.urlForKey,
    required this.parseFields,
    this.endpointName = 'main',
    this.setup,
    this.teardown,
  });

  @override
  final String namespace;

  final DiscoverKeys discoverKeys;
  final UrlForKey urlForKey;
  final ParseFields parseFields;
  final String endpointName;

  /// 适配器级初始化（可选）。
  final Future<void> Function(CrawlContext ctx)? setup;

  /// 适配器级清理（可选）。
  final Future<void> Function(CrawlContext ctx)? teardown;

  @override
  Future<void> onStart(CrawlContext ctx) async {
    await setup?.call(ctx);
  }

  @override
  Future<void> onDispose(CrawlContext ctx) async {
    await teardown?.call(ctx);
  }

  @override
  Stream<CrawlItem> discover({
    required CrawlContext ctx,
    required CrawlMode mode,
  }) async* {
    if (mode == CrawlMode.single) {
      for (final key in ctx.options.singleIds) {
        yield CrawlItem(id: ResourceId(namespace: namespace, key: key));
      }
      return;
    }

    await for (final key in discoverKeys(ctx, mode)) {
      yield CrawlItem(id: ResourceId(namespace: namespace, key: key));
    }
  }

  @override
  Future<List<EndpointSpec>> buildRequests(CrawlItem item) async {
    return [
      EndpointSpec(
        name: endpointName,
        method: HttpMethod.get,
        url: urlForKey(item.id.key),
      ),
    ];
  }

  @override
  CrawlRecord? parse(CrawlItem item, Map<String, RawPayload> responses) {
    final fields = parseFields(item.id.key, responses[endpointName]?.body);
    if (fields == null) return null;

    return CrawlRecord(
      id: item.id,
      fields: fields,
      contentHash: computeContentHash(fields),
      extractedAt: DateTime.now().toUtc(),
    );
  }
}
