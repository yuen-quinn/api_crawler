import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../util/crawl_logging.dart';
import '../core/crawl_context.dart';
import '../core/crawl_item.dart';
import '../core/crawl_mode.dart';
import '../resilience/rate_limiter.dart';
import '../resilience/retry_policy.dart';
import 'http_request.dart';
import 'transport.dart';

/// 基于 `package:http` 的传输实现，内置限速与重试。
class HttpTransport implements Transport {
  static final _log = crawlLog('http');

  HttpTransport({
    http.Client? client,
    RateLimiter? rateLimiter,
    RetryPolicy? retryPolicy,
    this.middlewares = const [],
  })  : _client = client ?? http.Client(),
        rateLimiter = rateLimiter ?? RateLimiter(),
        retryPolicy = retryPolicy ?? RetryPolicy();

  final http.Client _client;
  final RateLimiter rateLimiter;
  final RetryPolicy retryPolicy;
  final List<HttpMiddleware> middlewares;

  @override
  Future<RawPayload> send(RequestSpec spec, CrawlContext ctx) async {
    Future<RawPayload> execute(RequestSpec request) async {
      return rateLimiter.run(request.url.host, () async {
        return retryPolicy.run(() => _sendOnce(request, ctx));
      });
    }

    NextMiddleware next = execute;
    for (final middleware in middlewares.reversed) {
      final inner = next;
      next = (request) => middleware.handle(request, ctx, inner);
    }
    return next(spec);
  }

  Future<RawPayload> _sendOnce(RequestSpec spec, CrawlContext ctx) async {
    final headers = Map<String, String>.from(spec.headers);
    headers.putIfAbsent('Accept', () => 'application/json');

    if (ctx.logging.logRequests) {
      _log.info('→ ${spec.method.name.toUpperCase()} ${spec.url} [${spec.endpointName}]');
    }

    http.Response response;
    switch (spec.method) {
      case HttpMethod.get:
        response = await _client
            .get(spec.url, headers: headers)
            .timeout(spec.timeout);
      case HttpMethod.post:
        response = await _client
            .post(
              spec.url,
              headers: headers,
              body: spec.body is String
                  ? spec.body as String
                  : jsonEncode(spec.body),
            )
            .timeout(spec.timeout);
      case HttpMethod.put:
        response = await _client
            .put(
              spec.url,
              headers: headers,
              body: spec.body is String
                  ? spec.body as String
                  : jsonEncode(spec.body),
            )
            .timeout(spec.timeout);
      case HttpMethod.patch:
        response = await _client
            .patch(
              spec.url,
              headers: headers,
              body: spec.body is String
                  ? spec.body as String
                  : jsonEncode(spec.body),
            )
            .timeout(spec.timeout);
      case HttpMethod.delete:
        response = await _client
            .delete(spec.url, headers: headers)
            .timeout(spec.timeout);
    }

    Object? body;
    final text = response.body;
    if (text.isNotEmpty) {
      try {
        body = jsonDecode(text);
      } on FormatException {
        body = text;
      }
    }

    if (retryPolicy.shouldRetry(response.statusCode)) {
      Duration? retryAfter;
      final header = response.headers['retry-after'];
      if (header != null) {
        final seconds = int.tryParse(header);
        if (seconds != null) {
          retryAfter = Duration(seconds: seconds);
        }
      }
      throw RetryableHttpException(
        response.statusCode,
        retryAfter: retryAfter,
      );
    }

    if (ctx.logging.logRequests) {
      _log.info('← ${response.statusCode} ${spec.url} [${spec.endpointName}]');
    }

    return RawPayload(
      statusCode: response.statusCode,
      headers: Map<String, String>.from(response.headers),
      body: body,
      fetchedAt: DateTime.now().toUtc(),
      requestUrl: spec.url.toString(),
    );
  }

  void close() => _client.close();
}
