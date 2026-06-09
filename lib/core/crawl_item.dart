import '../core/crawl_mode.dart';

/// 资源唯一标识：`namespace:key`。
class ResourceId {
  const ResourceId({required this.namespace, required this.key});

  final String namespace;
  final String key;

  String get canonical => '$namespace:$key';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceId &&
          namespace == other.namespace &&
          key == other.key;

  @override
  int get hashCode => Object.hash(namespace, key);

  @override
  String toString() => canonical;

  Map<String, Object?> toJson() => {'namespace': namespace, 'key': key};

  factory ResourceId.fromJson(Map<String, Object?> json) {
    return ResourceId(
      namespace: json['namespace']! as String,
      key: json['key']! as String,
    );
  }
}

/// 管道中传递的条目元数据。
class ItemMeta {
  const ItemMeta({
    this.retryCount = 0,
    this.source,
    this.trace = const {},
    this.lastError,
  });

  final int retryCount;
  final String? source;
  final Map<String, Object?> trace;
  final String? lastError;

  ItemMeta copyWith({
    int? retryCount,
    String? source,
    Map<String, Object?>? trace,
    String? lastError,
  }) {
    return ItemMeta(
      retryCount: retryCount ?? this.retryCount,
      source: source ?? this.source,
      trace: trace ?? this.trace,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// HTTP 原始响应。
class RawPayload {
  const RawPayload({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.fetchedAt,
    required this.requestUrl,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Object? body;
  final DateTime fetchedAt;
  final String requestUrl;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// 标准化存储记录。
class CrawlRecord {
  const CrawlRecord({
    required this.id,
    required this.fields,
    required this.contentHash,
    required this.extractedAt,
    this.status = SyncStatus.active,
  });

  final ResourceId id;
  final Map<String, Object?> fields;
  final String contentHash;
  final DateTime extractedAt;
  final SyncStatus status;

  CrawlRecord copyWith({
    Map<String, Object?>? fields,
    String? contentHash,
    DateTime? extractedAt,
    SyncStatus? status,
  }) {
    return CrawlRecord(
      id: id,
      fields: fields ?? this.fields,
      contentHash: contentHash ?? this.contentHash,
      extractedAt: extractedAt ?? this.extractedAt,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id.toJson(),
        'fields': fields,
        'contentHash': contentHash,
        'extractedAt': extractedAt.toIso8601String(),
        'status': status.name,
      };

  factory CrawlRecord.fromJson(Map<String, Object?> json) {
    return CrawlRecord(
      id: ResourceId.fromJson(json['id']! as Map<String, Object?>),
      fields: Map<String, Object?>.from(json['fields']! as Map),
      contentHash: json['contentHash']! as String,
      extractedAt: DateTime.parse(json['extractedAt']! as String),
      status: SyncStatus.values.byName(json['status']! as String),
    );
  }
}

/// 管道阶段间传递的爬取条目。
class CrawlItem {
  const CrawlItem({
    required this.id,
    this.rawByEndpoint = const {},
    this.record,
    this.meta = const ItemMeta(),
  });

  final ResourceId id;

  /// 各端点原始响应，键为 [EndpointSpec.name]。
  final Map<String, RawPayload> rawByEndpoint;
  final CrawlRecord? record;
  final ItemMeta meta;

  CrawlItem copyWith({
    Map<String, RawPayload>? rawByEndpoint,
    CrawlRecord? record,
    ItemMeta? meta,
    bool clearRecord = false,
  }) {
    return CrawlItem(
      id: id,
      rawByEndpoint: rawByEndpoint ?? this.rawByEndpoint,
      record: clearRecord ? null : (record ?? this.record),
      meta: meta ?? this.meta,
    );
  }
}
