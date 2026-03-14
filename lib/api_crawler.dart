library api_crawler;

export 'src/models.dart';

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// 一次 API 调用的描述。
class ApiCall {
  final Uri url;
  final String method;
  final Map<String, String> headers;
  final Object? body;
  final Object? tag; // 自定义携带的上下文（页码等）

  const ApiCall({
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    this.body,
    this.tag,
  });
}

/// 爬虫全局配置。
class CrawlOptions {
  final int concurrency; // 并发数
  final int maxRetries; // 单请求最大重试次数
  final bool logRequests; // 是否打印请求
  final bool logResponses; // 是否打印响应（状态码）
  final Duration perRequestDelay; // 每个请求前的固定延时

  const CrawlOptions({
    this.concurrency = 8,
    this.maxRetries = 3,
    this.logRequests = false,
    this.logResponses = false,
    this.perRequestDelay = Duration.zero,
  });
}

/// 单次响应（方便解析时使用）。
class ApiResponse {
  final ApiCall call;
  final int statusCode;
  final Map<String, String> headers;
  final List<int> bodyBytes;

  const ApiResponse({
    required this.call,
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
  });

  String get bodyText => utf8.decode(bodyBytes);

  dynamic json() => jsonDecode(bodyText);
}

/// 解析一次响应的结果：
/// - items：你要产出的数据
/// - next：接下来要继续请求的 API
class ParseResult {
  final List<Object?> items;
  final List<ApiCall> next;

  const ParseResult({this.items = const [], this.next = const []});
}

/// 解析函数：从响应中解析数据，并决定下一步要请求什么。
typedef ParseFn = Future<ParseResult> Function(ApiResponse response);

/// 运行一个简单的 API 爬虫。
///
/// 示例：
/// ```dart
/// await crawlApis(
///   seeds: [ApiCall(url: Uri.parse('https://api.example.com/users?page=1'))],
///   parse: (res) async {
///     final data = res.json() as Map<String, dynamic>;
///     final users = data['data'] as List<dynamic>;
///     final page = data['page'] as int;
///
///     final next = <ApiCall>[];
///     if (data['has_more'] == true) {
///       next.add(ApiCall(
///         url: Uri.parse('https://api.example.com/users?page=${page + 1}'),
///       ));
///     }
///
///     return ParseResult(items: users, next: next);
///   },
/// );
/// ```
Future<void> crawlApis({
  required List<ApiCall> seeds,
  required ParseFn parse,
  CrawlOptions options = const CrawlOptions(),
  Future<void> Function(Object? item)? onItem,
}) async {
  if (seeds.isEmpty) return;

  final client = http.Client();
  final queue = ListQueue<_QueueEntry>();
  final seen = <String>{};

  void enqueue(ApiCall call, {int retries = 0}) {
    final key = _fingerprint(call);
    if (!seen.add(key)) return;
    queue.add(_QueueEntry(call, retries));
  }

  for (final call in seeds) {
    enqueue(call);
  }

  onItem ??= (item) async {
    // ignore: avoid_print
    print(item);
  };

  final workers = <Future<void>>[];
  final concurrency = options.concurrency.clamp(1, 64);

  for (var i = 0; i < concurrency; i++) {
    workers.add(
      _workerLoop(
        client: client,
        queue: queue,
        options: options,
        parse: parse,
        enqueue: enqueue,
        onItem: onItem,
      ),
    );
  }

  await Future.wait(workers);
  client.close();
}

Future<void> _workerLoop({
  required http.Client client,
  required ListQueue<_QueueEntry> queue,
  required CrawlOptions options,
  required ParseFn parse,
  required void Function(ApiCall call, {int retries}) enqueue,
  required Future<void> Function(Object? item) onItem,
}) async {
  while (true) {
    if (queue.isEmpty) return;

    final entry = queue.removeFirst();
    final call = entry.call;

    try {
      if (options.perRequestDelay > Duration.zero) {
        await Future<void>.delayed(options.perRequestDelay);
      }

      if (options.logRequests) {
        // ignore: avoid_print
        print('[REQ] ${call.method.toUpperCase()} ${call.url}');
      }

      final response = await _doRequest(client, call);

      if (options.logResponses) {
        print(
          '[RES] ${response.statusCode} ${call.method.toUpperCase()} ${call.url}',
        );
      }

      if (response.statusCode != 200) {
        print(
          '[ERR] ${response.statusCode} ${call.method.toUpperCase()} ${call.url}',
        );
        return;
      }
      final parsed = await parse(response);

      for (final item in parsed.items) {
        await onItem(item);
      }
      for (final nextCall in parsed.next) {
        enqueue(nextCall);
      }
    } catch (_) {
      if (entry.retries < options.maxRetries) {
        enqueue(call, retries: entry.retries + 1);
      }
    }
  }
}

Future<ApiResponse> _doRequest(http.Client client, ApiCall call) async {
  final method = call.method.toUpperCase();
  final url = call.url;

  http.Response raw;
  switch (method) {
    case 'GET':
      raw = await client.get(url, headers: call.headers);
      break;
    case 'POST':
      raw = await client.post(url, headers: call.headers, body: call.body);
      break;
    case 'PUT':
      raw = await client.put(url, headers: call.headers, body: call.body);
      break;
    case 'PATCH':
      raw = await client.patch(url, headers: call.headers, body: call.body);
      break;
    case 'DELETE':
      raw = await client.delete(url, headers: call.headers, body: call.body);
      break;
    default:
      final req = http.Request(method, url)..headers.addAll(call.headers);
      if (call.body != null) {
        if (call.body is List<int>) {
          req.bodyBytes = call.body as List<int>;
        } else if (call.body is String) {
          req.body = call.body as String;
        } else {
          req.body = jsonEncode(call.body);
        }
      }
      raw = await http.Response.fromStream(await client.send(req));
  }

  return ApiResponse(
    call: call,
    statusCode: raw.statusCode,
    headers: raw.headers,
    bodyBytes: raw.bodyBytes,
  );
}

class _QueueEntry {
  final ApiCall call;
  final int retries;

  _QueueEntry(this.call, this.retries);
}

String _fingerprint(ApiCall call) {
  final buffer = StringBuffer()
    ..write(call.method.toUpperCase())
    ..write(' ')
    ..write(call.url.toString());

  if (call.body != null) {
    if (call.body is String) {
      buffer.write(' body:${call.body as String}');
    } else {
      buffer.write(' body:${jsonEncode(call.body)}');
    }
  }

  return buffer.toString();
}
