import '../core/crawl_context.dart';
import '../core/crawl_mode.dart';

/// 发现资源主键（如包名、ID）的回调。
typedef DiscoverKeys = Stream<String> Function(
  CrawlContext ctx,
  CrawlMode mode,
);

/// 根据主键构建请求 URL。
typedef EndpointUrl = Uri Function(String key);

/// 合并多个端点响应体并解析为字段映射。
typedef ParseResponses = Map<String, Object?>? Function(
  String key,
  Map<String, Object?> bodies,
);
