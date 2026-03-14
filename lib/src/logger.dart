/// 日志级别
enum LogLevel {
  none,
  error,
  info,
  debug,
}

/// 日志接口
abstract class Logger {
  void log(String message, LogLevel level);
}

/// 默认控制台日志实现
class ConsoleLogger implements Logger {
  final LogLevel level;

  const ConsoleLogger(this.level);

  @override
  void log(String message, LogLevel level) {
    if (level.index <= this.level.index) {
      // ignore: avoid_print
      print(message);
    }
  }
}

/// 空日志实现（静默模式）
class SilentLogger implements Logger {
  const SilentLogger();

  @override
  void log(String message, LogLevel level) {
    // 不打印任何内容
  }
}
