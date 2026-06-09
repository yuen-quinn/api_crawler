import 'dart:async';

import 'package:logging/logging.dart';

/// 爬虫日志配置，在 [Crawler] / [CrawlerEngine] 上设置。
class CrawlLoggingOptions {
  const CrawlLoggingOptions({
    this.enabled = false,
    this.level = Level.INFO,
    this.logRequests = false,
    this.onRecord,
  });

  /// 是否输出日志；为 false 时不注册监听器。
  final bool enabled;

  /// 常规日志级别（任务、批次、分页等）。
  final Level level;

  /// 是否记录每一次 HTTP 请求与响应（INFO 级别，可单独开启）。
  final bool logRequests;

  /// 自定义输出处理器；为 null 时输出到控制台。
  final void Function(LogRecord record)? onRecord;

  /// 开启控制台日志的便捷构造。
  const CrawlLoggingOptions.console({
    Level level = Level.INFO,
    bool logRequests = false,
    void Function(LogRecord record)? onRecord,
  })  : enabled = true,
        level = level,
        logRequests = logRequests,
        onRecord = onRecord;
}

/// 获取框架子模块 Logger，命名空间为 `api_crawler.<name>`。
Logger crawlLog(String name) => Logger('api_crawler.$name');

StreamSubscription<LogRecord>? _subscription;

/// 根据 [CrawlLoggingOptions] 应用日志配置（全局单例监听器）。
void applyCrawlLogging(CrawlLoggingOptions options) {
  _subscription?.cancel();
  _subscription = null;

  if (!options.enabled) {
    Logger.root.level = Level.OFF;
    return;
  }

  Logger.root.level = options.level;
  _subscription = Logger.root.onRecord.listen(
    options.onRecord ?? _defaultHandler,
  );
}

void _defaultHandler(LogRecord record) {
  final time = record.time.toIso8601String().substring(11, 19);
  final line = '$time ${record.level.name.padRight(7)} '
      '${record.loggerName}: ${record.message}';
  // ignore: avoid_print
  print(line);
  if (record.error != null) {
    // ignore: avoid_print
    print('  └─ ${record.error}');
  }
  if (record.stackTrace != null &&
      record.level >= Level.SEVERE &&
      record.stackTrace.toString().isNotEmpty) {
    // ignore: avoid_print
    print(record.stackTrace);
  }
}
