import '../util/crawl_logging.dart';

/// HTTP 重试策略，支持指数退避与 Retry-After。
class RetryPolicy {
  static final _log = crawlLog('retry');
  RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.retryStatusCodes = const {408, 429, 500, 502, 503, 504},
  });

  /// 最大尝试次数。
  final int maxAttempts;

  /// 基础退避延迟。
  final Duration baseDelay;

  /// 触发重试的 HTTP 状态码。
  final Set<int> retryStatusCodes;

  Future<T> run<T>(Future<T> Function() action) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } on RetryableHttpException catch (error) {
        lastError = error;
        if (attempt == maxAttempts) break;
        final delay = error.retryAfter ?? baseDelay * attempt;
        _log.info(
          'HTTP ${error.statusCode} 第 $attempt/$maxAttempts 次重试，'
          '等待 ${delay.inMilliseconds}ms',
        );
        await Future<void>.delayed(delay);
      }
    }
    throw lastError ?? StateError('Retry failed without error');
  }

  bool shouldRetry(int statusCode) => retryStatusCodes.contains(statusCode);
}

/// 可重试的 HTTP 错误。
class RetryableHttpException implements Exception {
  RetryableHttpException(this.statusCode, {this.retryAfter});

  final int statusCode;
  final Duration? retryAfter;

  @override
  String toString() => 'RetryableHttpException($statusCode)';
}
