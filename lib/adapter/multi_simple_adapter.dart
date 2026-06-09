import '../core/crawl_context.dart';
import '../core/crawl_item.dart';
import '../core/crawl_mode.dart';
import '../util/content_hash.dart';
import 'adapter_types.dart';
import 'api_adapter.dart';

/// 多 API 简化适配器：发现主键 → 多个 GET → 合并解析。
///
/// 适用于「先拉列表，再拉详情/得分/版本」等场景。
class MultiSimpleAdapter extends ApiAdapter {
  MultiSimpleAdapter({
    required this.namespace,
    required this.discoverKeys,
    required this.endpoints,
    required this.parseResponses,
    this.setup,
    this.teardown,
  });

  @override
  final String namespace;

  /// 端点名称 → URL 构建器，插入顺序即请求顺序。
  final Map<String, EndpointUrl> endpoints;
  final DiscoverKeys discoverKeys;
  final ParseResponses parseResponses;

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
      for (final entry in endpoints.entries)
        EndpointSpec(
          name: entry.key,
          method: HttpMethod.get,
          url: entry.value(item.id.key),
        ),
    ];
  }

  @override
  CrawlRecord? parse(CrawlItem item, Map<String, RawPayload> responses) {
    final bodies = {
      for (final name in endpoints.keys) name: responses[name]?.body,
    };
    final fields = parseResponses(item.id.key, bodies);
    if (fields == null) return null;

    return CrawlRecord(
      id: item.id,
      fields: fields,
      contentHash: computeContentHash(fields),
      extractedAt: DateTime.now().toUtc(),
    );
  }
}
