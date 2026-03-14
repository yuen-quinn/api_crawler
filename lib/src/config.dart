import 'logger.dart';

/// 爬虫全局配置。
class CrawlOptions {
  final int concurrency; // 并发数
  final int maxRetries; // 单请求最大重试次数
  final bool logRequests; // 是否打印请求
  final bool logResponses; // 是否打印响应（状态码）
  final Duration perRequestDelay; // 每个请求前的固定延时
  final Logger logger; // 日志记录器

  const CrawlOptions({
    this.concurrency = 8,
    this.maxRetries = 3,
    this.logRequests = true,
    this.logResponses = false,
    this.perRequestDelay = Duration.zero,
    this.logger = const ConsoleLogger(LogLevel.info),
  });
}
