import '../util/crawl_logging.dart';
import '../core/crawl_context.dart';
import '../core/crawl_item.dart';
import '../core/crawl_mode.dart';
import '../core/pipeline.dart';
import '../store/dead_letter_store.dart';
import '../transport/http_request.dart';

/// 抓取阶段：并发请求各资源的 HTTP 端点。
class FetchStage implements PipelineStage {
  static final _log = crawlLog('fetch');

  @override
  String get name => 'fetch';

  @override
  Future<List<CrawlItem>> process(
    CrawlContext ctx,
    List<CrawlItem> batch,
  ) async {
    final results = <CrawlItem>[];

    for (final chunk in _chunks(batch, ctx.options.concurrency)) {
      final fetched = await Future.wait(
        chunk.map((item) => _fetchOne(ctx, item)),
      );
      results.addAll(fetched.whereType<CrawlItem>());
    }

    return results;
  }

  Future<CrawlItem?> _fetchOne(CrawlContext ctx, CrawlItem item) async {
    try {
      final existing = await ctx.recordStore.get(item.id);
      if (!await ctx.adapter.shouldFetch(item, existing)) {
        ctx.metrics.skipped++;
        _log.fine('跳过抓取 ${item.id.key}（无需更新）');
        return null;
      }

      final specs = await ctx.adapter.buildRequests(item);
      specs.sort((a, b) => a.priority.compareTo(b.priority));

      final authHeaders = await ctx.adapter.auth?.headers() ?? {};
      final responses = <String, RawPayload>{};

      for (final spec in specs) {
        final headers = {...authHeaders, ...spec.headers};
        final payload = await ctx.transport.send(
          RequestSpec(
            method: spec.method,
            url: spec.url,
            headers: headers,
            body: spec.body,
            endpointName: spec.name,
          ),
          ctx,
        );

        if (payload.statusCode == 404) {
          _log.warning('404 ${item.id.key} endpoint=${spec.name}');
          final disposition = await ctx.adapter.reconcile(item, payload);
          if (disposition == ItemDisposition.delete) {
            await ctx.recordStore.markDeleted(item.id);
            ctx.metrics.deleted++;
            _log.info('标记删除 ${item.id.key}');
          }
          return null;
        }

        if (!payload.isSuccess) {
          throw HttpStatusException(payload.statusCode, payload.requestUrl);
        }

        responses[spec.name] = payload;
        ctx.metrics.fetched++;
      }

      return item.copyWith(rawByEndpoint: responses);
    } on Object catch (error) {
      ctx.metrics.failed++;
      _log.warning('抓取失败 ${item.id.key}: $error');
      await ctx.deadLetterStore.push(
        DeadLetterItem(
          id: item.id,
          stage: name,
          error: error.toString(),
          attemptedAt: DateTime.now().toUtc(),
          retryCount: item.meta.retryCount,
        ),
      );
      return null;
    }
  }

  Iterable<List<CrawlItem>> _chunks(List<CrawlItem> items, int size) sync* {
    for (var i = 0; i < items.length; i += size) {
      yield items.sublist(i, i + size > items.length ? items.length : i + size);
    }
  }
}

/// 非成功 HTTP 状态码异常。
class HttpStatusException implements Exception {
  HttpStatusException(this.statusCode, this.url);
  final int statusCode;
  final String url;

  @override
  String toString() => 'HttpStatusException($statusCode, $url)';
}
