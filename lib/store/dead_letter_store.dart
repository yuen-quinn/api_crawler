import '../core/crawl_item.dart';

/// 死信队列条目：管道某阶段处理失败时记录。
class DeadLetterItem {
  const DeadLetterItem({
    required this.id,
    required this.stage,
    required this.error,
    required this.attemptedAt,
    this.retryCount = 0,
  });

  final ResourceId id;
  final String stage;
  final String error;
  final DateTime attemptedAt;
  final int retryCount;
}

/// 死信队列存储抽象。
abstract class DeadLetterStore {
  Future<void> push(DeadLetterItem item);

  Stream<DeadLetterItem> list({int? limit});

  Future<void> clear(ResourceId id);
}
