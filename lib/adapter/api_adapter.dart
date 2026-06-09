import '../core/crawl_context.dart';
import '../core/crawl_item.dart';
import '../core/crawl_job.dart';
import '../core/crawl_mode.dart';

/// 单个 HTTP 端点的请求描述。
class EndpointSpec {
  const EndpointSpec({
    required this.name,
    required this.method,
    required this.url,
    this.headers = const {},
    this.body,
    this.priority = 0,
  });

  /// 端点名称，用于在 [ApiAdapter.parse] 中索引响应。
  final String name;
  final HttpMethod method;
  final Uri url;
  final Map<String, String> headers;
  final Object? body;

  /// 数值越小越先请求。
  final int priority;
}

/// 鉴权头提供者。
abstract class AuthProvider {
  Future<Map<String, String>> headers();
}

/// API 适配器：定义如何发现、请求、解析某个 API。
abstract class ApiAdapter {
  /// 命名空间，用于资源 ID 前缀与检查点隔离。
  String get namespace;

  AuthProvider? get auth => null;

  /// 发现待爬取资源，以流式方式产出 [CrawlItem]。
  Stream<CrawlItem> discover({
    required CrawlContext ctx,
    required CrawlMode mode,
  });

  /// 为单个资源构建一个或多个 HTTP 请求。
  Future<List<EndpointSpec>> buildRequests(CrawlItem item);

  /// 将各端点响应解析为标准化 [CrawlRecord]。
  CrawlRecord? parse(CrawlItem item, Map<String, RawPayload> responses);

  /// 是否跳过抓取（增量同步时可用）。
  Future<bool> shouldFetch(CrawlItem item, CrawlRecord? existing) async =>
      existing == null;

  /// 资源不存在或出错时的处置策略。
  Future<ItemDisposition> reconcile(CrawlItem item, Object? error) async =>
      ItemDisposition.skip;

  /// 任务开始前调用，用于初始化（鉴权、客户端等）。
  Future<void> onStart(CrawlContext ctx) async {}

  /// 任务成功完成后调用。
  Future<void> onComplete(CrawlContext ctx, CrawlResult result) async {}

  /// 任务结束时在 `finally` 中调用，用于清理资源。
  Future<void> onDispose(CrawlContext ctx) async {}
}
