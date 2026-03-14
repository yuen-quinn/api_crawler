import 'dart:convert';
import 'dart:io';

import 'package:api_crawler/api_crawler.dart';

/// 包列表页模型
class PubPageListModel {
  final String? nextUrl;
  final List<PackageItem> packages;

  const PubPageListModel({this.nextUrl, this.packages = const []});

  Map<String, dynamic> toJson() => {
    'next_url': nextUrl,
    'packages': packages.map((pkg) => pkg.toJson()).toList(),
  };
}

/// 包项目模型
class PackageItem {
  final String name;

  const PackageItem({required this.name});

  Map<String, dynamic> toJson() => {'name': name};
}

/// 包详情模型
class PackageDetailModel {
  final String name;
  final String? latestVersion;

  const PackageDetailModel({required this.name, this.latestVersion});

  Map<String, dynamic> toJson() => {'name': name, 'latest': latestVersion};
}

/// 包列表模型解析器
class PubPageListModelParser extends ModelParser<PubPageListModel> {
  @override
  PubPageListModel fromJson(Map<String, dynamic> json) {
    return PubPageListModel(
      nextUrl: json['next_url'] as String?,
      packages: (json['packages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((pkg) => PackageItem(name: pkg['name'] as String))
          .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson(PubPageListModel model) {
    return model.toJson();
  }
}

/// 包详情模型解析器
class PackageDetailModelParser extends ModelParser<PackageDetailModel> {
  @override
  PackageDetailModel fromJson(Map<String, dynamic> json) {
    return PackageDetailModel(
      name: json['name'] as String,
      latestVersion:
          (json['latest'] as Map<String, dynamic>?)?['version'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson(PackageDetailModel model) {
    return model.toJson();
  }
}

/// 包项目模型解析器
class PackageItemModelParser extends ModelParser<PackageItem> {
  @override
  PackageItem fromJson(Map<String, dynamic> json) {
    return PackageItem(name: json['name'] as String);
  }

  @override
  Map<String, dynamic> toJson(PackageItem model) {
    return model.toJson();
  }
}

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

  // 创建控制器
  final controller = CrawlerController();

  // 创建模型解析器
  final detailModelParser = PackageDetailModelParser();
  final packageItemParser = PackageItemModelParser();

  // 创建自动解析器
  final listParser = AutoListParser<PackageItem>(
    modelParser: packageItemParser,
    idExtractor: (pkg) => pkg.name,
    detailUrlBuilder: (name) => 'https://pub.dev/api/packages/$name',
    nextPageUrlExtractor: (json) => json['next_url']?.toString() ?? '',
    listKey: 'packages',
  );

  final detailParser = AutoModelParser<PackageDetailModel>(
    modelParser: detailModelParser,
  );

  // 启动爬虫任务
  final crawlerFuture = crawlApis(
    controller: controller,
    seeds: [ApiCall(url: Uri.parse('https://pub.dev/api/packages?page=771'))],
    parse: (response) async {
      return MultiParser([listParser, detailParser]).parse(response);
    },
    options: const CrawlOptions(
      concurrency: 2,
      maxRetries: 2,
      logRequests: true,
      logResponses: false,
      perRequestDelay: Duration(milliseconds: 2000),
      logger: ConsoleLogger(LogLevel.debug),
    ),
    onItem: (item) async {
      await outFile.writeAsString(
        '${jsonEncode(item)}\n',
        mode: FileMode.append,
        flush: true,
      );

      controller.stop();
    },
  );

  // 示例：10秒后主动停止爬虫
  // Timer(const Duration(seconds: 10), () {
  //   print('主动停止爬虫...');
  //   controller.stop();
  // });

  await crawlerFuture;
  print('爬虫完成');
}
