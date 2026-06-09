import '../core/crawl_item.dart';

/// 爬取事件基类。
sealed class CrawlEvent {}

/// 新记录写入。
class RecordCreated extends CrawlEvent {
  RecordCreated(this.record);
  final CrawlRecord record;
}

/// 记录内容变更。
class RecordUpdated extends CrawlEvent {
  RecordUpdated(this.record, this.previous);
  final CrawlRecord record;
  final CrawlRecord? previous;
}

/// 记录标记为已删除。
class RecordDeleted extends CrawlEvent {
  RecordDeleted(this.id);
  final ResourceId id;
}

/// 一批管道处理完成。
class BatchCompleted extends CrawlEvent {
  BatchCompleted(this.processed, this.upserted, this.skipped);
  final int processed;
  final int upserted;
  final int skipped;
}

typedef CrawlEventListener = void Function(CrawlEvent event);

/// 事件总线，用于下游索引、通知等。
class EventBus {
  final _listeners = <CrawlEventListener>[];

  void listen(CrawlEventListener listener) => _listeners.add(listener);

  void emit(CrawlEvent event) {
    for (final listener in List<CrawlEventListener>.from(_listeners)) {
      listener(event);
    }
  }
}
