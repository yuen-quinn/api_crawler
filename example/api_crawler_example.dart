import 'dart:convert';
import 'dart:io';

import 'package:api_crawler/api_crawler.dart';

/// 示例：从 pub.dev 抓取包列表（带分页）+ 每个包的详情。
///
/// 入口：`https://pub.dev/api/packages?page=1`
/// - 解析 `next_url` 字段继续翻页
/// - 对每个包发起 `https://pub.dev/api/packages/<name>` 详情请求
Future<void> main() async {
  final outFile = File('pubdev_packages.jsonl');
  if (await outFile.exists()) {
    await outFile.delete();
  }

  await crawlApis(
    seeds: [ApiCall(url: Uri.parse('https://pub.dev/api/packages?page=1'))],
    parse: (response) async {
      if (response.statusCode != 200) {
        return const ParseResult();
      }

      final uri = response.call.url;
      final data = response.json();

      final items = <Object?>[];
      final nextCalls = <ApiCall>[];

      // 列表页：/api/packages?page=1...
      if (uri.path == '/api/packages' && data is Map<String, dynamic>) {
        final nextUrl = data['next_url'] as String?;
        if (nextUrl != null && nextUrl.isNotEmpty) {
          nextCalls.add(ApiCall(url: Uri.parse(nextUrl)));
        }

        final packages = data['packages'] as List<dynamic>? ?? [];
        for (final pkg in packages) {
          if (pkg is Map<String, dynamic>) {
            final name = pkg['name'] as String?;
            if (name != null && name.isNotEmpty) {
              // 为每个包请求详情
              nextCalls.add(
                ApiCall(url: Uri.parse('https://pub.dev/api/packages/$name')),
              );
            }
          }
        }
      }
      // 详情页：/api/packages/dio
      else if (uri.path.startsWith('/api/packages/') &&
          data is Map<String, dynamic>) {
        final name = data['name'] as String?;
        final latest =
            (data['latest'] as Map<String, dynamic>?)?['version'] as String?;

        items.add({'name': name, 'latest': latest});
      }

      return ParseResult(items: items, next: nextCalls);
    },
    options: const CrawlOptions(
      concurrency: 2, 
      maxRetries: 2,
      logRequests: true,
      logResponses: true,
      perRequestDelay: Duration(milliseconds: 1000), // 每个请求之间间隔 500ms
    ),
    onItem: (item) async {
      // 逐行写入 JSONL 文件，便于后续分析
      await outFile.writeAsString('${jsonEncode(item)}\n',
          mode: FileMode.append, flush: true);
    },
  );
}
