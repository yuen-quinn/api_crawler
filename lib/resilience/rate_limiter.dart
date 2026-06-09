import 'dart:async';

/// 按主机限速，避免请求过于频繁。
class RateLimiter {
  RateLimiter({
    this.minInterval = const Duration(milliseconds: 100),
    this.perHostIntervals = const {},
  });

  /// 默认最小请求间隔。
  final Duration minInterval;

  /// 按主机覆盖间隔，如 `{'pub.dev': Duration(milliseconds: 200)}`。
  final Map<String, Duration> perHostIntervals;

  final _lastRequest = <String, DateTime>{};
  final _locks = <String, Future<void>>{};

  Future<T> run<T>(String host, Future<T> Function() action) async {
    await _acquire(host);
    try {
      return await action();
    } finally {
      _lastRequest[host] = DateTime.now();
    }
  }

  Future<void> _acquire(String host) async {
    final previous = _locks[host] ?? Future.value();
    final completer = Completer<void>();
    _locks[host] = completer.future;

    await previous;
    final interval = perHostIntervals[host] ?? minInterval;
    final last = _lastRequest[host];
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      final wait = interval - elapsed;
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait);
      }
    }
    completer.complete();
  }
}
