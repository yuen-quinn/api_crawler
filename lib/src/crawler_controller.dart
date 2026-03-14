import 'dart:async';

/// 爬虫控制器，用于控制爬虫的运行状态
class CrawlerController {
  bool _isStopped = false;
  final List<Completer<void>> _workers = [];

  /// 检查是否应该停止
  bool get shouldStop => _isStopped;

  /// 停止爬虫
  void stop() {
    _isStopped = true;
    for (final worker in _workers) {
      if (!worker.isCompleted) {
        worker.complete();
      }
    }
  }

  /// 添加工作线程
  void addWorker(Completer<void> worker) {
    _workers.add(worker);
  }

  /// 重置控制器状态
  void reset() {
    _isStopped = false;
    _workers.clear();
  }

  /// 等待所有工作线程完成
  Future<void> waitForWorkers() {
    return Future.wait(_workers.map((w) => w.future));
  }
}
