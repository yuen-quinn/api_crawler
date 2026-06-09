import 'dart:async';

import 'package:cron/cron.dart';

import '../core/crawl_job.dart';
import '../core/crawler.dart';
import '../util/crawl_logging.dart';
import 'crawl_schedule.dart';

/// 定时爬取调度器，支持 cron 表达式与固定间隔。
///
/// ```dart
/// final scheduler = CrawlScheduler(crawler: crawler);
/// scheduler.add(CrawlSchedule.cron(
///   name: 'pubdev',
///   expression: '0 */6 * * *',
///   adapter: myAdapter,
///   runOnStart: true,
/// ));
/// await scheduler.start();
/// await scheduler.join(); // 阻塞直到 stop()
/// ```
class CrawlScheduler {
  CrawlScheduler({required this.crawler});

  final Crawler crawler;
  final _schedules = <CrawlSchedule>[];
  final _running = <String>{};
  final _timers = <Timer>[];
  final _cron = Cron();
  final _log = crawlLog('scheduler');

  Completer<void>? _joinCompleter;
  var _started = false;

  /// 注册一个定时任务。
  void add(CrawlSchedule schedule) {
    if (_started) {
      throw StateError('调度器已启动，不能再添加任务');
    }
    _schedules.add(schedule);
  }

  /// 启动所有已注册任务。
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _joinCompleter = Completer<void>();

    for (final schedule in _schedules) {
      if (schedule.runOnStart) {
        await _run(schedule);
      }

      if (schedule.cron != null) {
        _cron.schedule(Schedule.parse(schedule.cron!), () => _run(schedule));
        _log.info('已注册 cron 任务 ${schedule.name}: ${schedule.cron}');
      } else if (schedule.interval != null) {
        _timers.add(
          Timer.periodic(schedule.interval!, (_) => _run(schedule)),
        );
        _log.info(
          '已注册间隔任务 ${schedule.name}: 每 ${schedule.interval}',
        );
      }
    }

    _log.info('调度器已启动，共 ${_schedules.length} 个任务');
  }

  /// 阻塞直到 [stop] 被调用。
  Future<void> join() => _joinCompleter?.future ?? Future.value();

  /// 停止调度并释放资源。
  Future<void> stop() async {
    if (!_started) return;

    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    await _cron.close();

    _started = false;
    _log.info('调度器已停止');
    if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
      _joinCompleter!.complete();
    }
  }

  Future<void> _run(CrawlSchedule schedule) async {
    if (_running.contains(schedule.name)) {
      _log.warning('任务 ${schedule.name} 仍在执行，跳过本次调度');
      return;
    }

    _running.add(schedule.name);
    _log.info('定时任务开始 ${schedule.name} mode=${schedule.mode.name}');

    try {
      final result = await crawler.runOnce(
        adapter: schedule.adapter,
        mode: schedule.mode,
        options: schedule.options,
        lifecycle: schedule.lifecycle,
      );

      if (result.success) {
        _log.info('定时任务完成 ${schedule.name} metrics=${result.metrics}');
      } else {
        _log.warning(
          '定时任务失败 ${schedule.name} error=${result.error}',
        );
      }
    } on Object catch (error, stack) {
      _log.severe('定时任务异常 ${schedule.name}', error, stack);
    } finally {
      _running.remove(schedule.name);
    }
  }
}
