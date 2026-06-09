import '../core/crawl_mode.dart';

/// 爬取检查点，用于断点续爬。
class CrawlCheckpoint {
  const CrawlCheckpoint({
    required this.namespace,
    required this.mode,
    this.cursor = '',
    this.watermark,
    this.processed = 0,
    this.state = const {},
  });

  final String namespace;
  final CrawlMode mode;

  /// 分页游标或最后处理位置。
  final String cursor;

  /// 增量同步水位线。
  final DateTime? watermark;

  /// 已处理资源总数。
  final int processed;

  /// 扩展状态（如 `last_cursor` 分页 URL）。
  final Map<String, Object?> state;

  CrawlCheckpoint copyWith({
    String? cursor,
    DateTime? watermark,
    int? processed,
    Map<String, Object?>? state,
  }) {
    return CrawlCheckpoint(
      namespace: namespace,
      mode: mode,
      cursor: cursor ?? this.cursor,
      watermark: watermark ?? this.watermark,
      processed: processed ?? this.processed,
      state: state ?? this.state,
    );
  }

  factory CrawlCheckpoint.empty(String namespace, CrawlMode mode) {
    return CrawlCheckpoint(namespace: namespace, mode: mode);
  }

  Map<String, Object?> toJson() => {
        'namespace': namespace,
        'mode': mode.name,
        'cursor': cursor,
        'watermark': watermark?.toIso8601String(),
        'processed': processed,
        'state': state,
      };

  factory CrawlCheckpoint.fromJson(Map<String, Object?> json) {
    return CrawlCheckpoint(
      namespace: json['namespace']! as String,
      mode: CrawlMode.values.byName(json['mode']! as String),
      cursor: json['cursor'] as String? ?? '',
      watermark: json['watermark'] != null
          ? DateTime.parse(json['watermark']! as String)
          : null,
      processed: json['processed'] as int? ?? 0,
      state: Map<String, Object?>.from(json['state'] as Map? ?? {}),
    );
  }
}

/// 检查点存储抽象。
abstract class CheckpointStore {
  Future<CrawlCheckpoint?> load(String namespace, CrawlMode mode);

  Future<void> save(CrawlCheckpoint checkpoint);
}
