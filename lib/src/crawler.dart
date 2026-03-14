import 'dart:async';
import 'dart:collection';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'crawler_controller.dart';
import 'http_client.dart';
import 'logger.dart';
import 'types.dart';
import 'utils.dart';

/// 运行一个简单的 API 爬虫。
///
/// 示例：
/// ```dart
/// final controller = CrawlerController();
/// await crawlApis(
///   controller: controller,
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
  CrawlerController? controller,
  required List<ApiCall> seeds,
  required ParseFn parse,
  CrawlOptions options = const CrawlOptions(),
  Future<void> Function(Object? item)? onItem,
}) async {
  if (seeds.isEmpty) return;

  controller ??= CrawlerController();
  final client = http.Client();
  final queue = ListQueue<QueueEntry>();
  final seen = <String>{};

  void enqueue(ApiCall call, {int retries = 0}) {
    final key = fingerprint(call);
    if (!seen.add(key)) return;
    queue.add(QueueEntry(call, retries));
  }

  for (final call in seeds) {
    enqueue(call);
  }

  onItem ??= (item) async {
    // 默认不处理 item，避免打印
  };

  final workers = <Future<void>>[];
  final concurrency = options.concurrency.clamp(1, 64);

  for (var i = 0; i < concurrency; i++) {
    final workerCompleter = Completer<void>();
    controller.addWorker(workerCompleter);
    
    workers.add(
      workerLoop(
        controller: controller,
        client: client,
        queue: queue,
        options: options,
        parse: parse,
        enqueue: enqueue,
        onItem: onItem,
        completer: workerCompleter,
      ),
    );
  }

  await Future.wait(workers);
  client.close();
}

/// 工作循环
Future<void> workerLoop({
  required CrawlerController controller,
  required http.Client client,
  required ListQueue<QueueEntry> queue,
  required CrawlOptions options,
  required ParseFn parse,
  required void Function(ApiCall call, {int retries}) enqueue,
  required Future<void> Function(Object? item) onItem,
  required Completer<void> completer,
}) async {
  try {
    while (!controller.shouldStop) {
      if (queue.isEmpty) {
        // 等待一小段时间，避免 CPU 占用过高
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      final entry = queue.removeFirst();
      final call = entry.call;

      try {
        if (options.perRequestDelay > Duration.zero) {
          await Future<void>.delayed(options.perRequestDelay);
        }

        if (options.logRequests) {
          options.logger.log('[REQ] ${call.method.toUpperCase()} ${call.url}', LogLevel.debug);
        }

        final response = await doRequest(client, call);

        if (options.logResponses) {
          options.logger.log(
            '[RES] ${response.statusCode} ${call.method.toUpperCase()} ${call.url}',
            LogLevel.debug,
          );
        }

        if (response.statusCode != 200) {
          options.logger.log(
            '[ERR] ${response.statusCode} ${call.method.toUpperCase()} ${call.url}',
            LogLevel.error,
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
  } finally {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }
}
