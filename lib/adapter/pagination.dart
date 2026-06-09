import '../util/crawl_logging.dart';
import '../core/crawl_context.dart';
import '../core/crawl_mode.dart';
import '../transport/http_request.dart';
import '../transport/transport.dart';

/// 从分页响应体中解析下一页 URL。
typedef PageParser = Uri? Function(Object? body, Uri currentUrl);

/// 从检查点恢复分页起始 URL；无检查点时返回 [firstUrl]。
Uri resumePageUrl(CrawlContext ctx, Uri firstUrl) {
  final cursor = ctx.checkpoint.state['last_cursor'] as String?;
  if (cursor == null || cursor.isEmpty) return firstUrl;
  return Uri.parse(cursor);
}

/// 从 `next_url` 风格的分页列表 API 中提取主键。
///
/// [limit] 为 null 且 [CrawlOptions.limit] 未设置时，会一直翻到 `next_url` 为空。
///
/// 响应格式示例（pub.dev）：
/// `{ "next_url": "...", "<itemsField>": [ { "<keyField>": "..." } ] }`
Stream<String> keysFromNextUrlPages({
  required CrawlContext ctx,
  required Uri firstUrl,
  required String itemsField,
  required String keyField,
  int? limit,
}) async* {
  final maxItems = limit ?? ctx.options.limit;
  var count = 0;
  final pagination = CursorPagination(
    firstUrl: resumePageUrl(ctx, firstUrl),
    transport: ctx.transport,
    parseNextUrl: (body, _) {
      if (body is! Map) return null;
      final next = body['next_url'];
      return next is String ? Uri.parse(next) : null;
    },
  );

  await for (final page in pagination.pages(ctx: ctx)) {
    if (page is! Map) continue;
    final items = page[itemsField];
    if (items is! List) continue;

    for (final item in items) {
      if (item is! Map) continue;
      final key = item[keyField];
      if (key is! String) continue;

      yield key;
      count++;
      if (maxItems != null && count >= maxItems) return;
    }
  }
}

/// 游标分页：逐页请求并将响应体作为流产出。
class CursorPagination {
  static final _log = crawlLog('pagination');

  CursorPagination({
    required this.firstUrl,
    required this.transport,
    required this.parseNextUrl,
    this.pageSize = 100,
  });

  final Uri firstUrl;
  final Transport transport;
  final PageParser parseNextUrl;
  final int pageSize;

  Stream<Object?> pages({required CrawlContext ctx}) async* {
    var url = firstUrl;
    var page = 0;
    while (true) {
      page++;
      _log.info('请求分页 page=$page url=$url');
      final payload = await transport.send(
        RequestSpec(method: HttpMethod.get, url: url),
        ctx,
      );
      if (!payload.isSuccess) {
        throw StateError('Pagination failed: ${payload.statusCode} $url');
      }

      yield payload.body;

      final next = parseNextUrl(payload.body, url);
      if (next == null) {
        _log.info('分页结束，共 $page 页');
        break;
      }
      url = next;

      ctx.checkpoint = ctx.checkpoint.copyWith(
        state: {...ctx.checkpoint.state, 'last_cursor': url.toString()},
      );
      _log.fine('下一页游标=$url');
    }
  }
}
