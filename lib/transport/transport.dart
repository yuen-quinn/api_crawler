import '../core/crawl_context.dart';
import '../core/crawl_item.dart';
import '../transport/http_request.dart';

/// HTTP 传输层抽象，测试时可替换为 mock。
abstract class Transport {
  Future<RawPayload> send(RequestSpec spec, CrawlContext ctx);
}

typedef NextMiddleware = Future<RawPayload> Function(RequestSpec spec);

/// HTTP 中间件，可插入日志、代理等逻辑。
abstract class HttpMiddleware {
  Future<RawPayload> handle(
    RequestSpec spec,
    CrawlContext ctx,
    NextMiddleware next,
  );
}
