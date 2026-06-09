/// 通用、可扩展的 Dart API 爬虫框架。
///
/// 核心流程：适配器发现资源 → 管道阶段处理 → 存储与事件。
library;

export 'adapter/adapter_types.dart';
export 'adapter/api_adapter.dart';
export 'adapter/pagination.dart';
export 'adapter/multi_simple_adapter.dart';
export 'adapter/simple_adapter.dart';
export 'core/crawl_context.dart';
export 'core/crawl_item.dart';
export 'core/crawl_job.dart';
export 'core/crawl_lifecycle.dart';
export 'core/crawl_mode.dart';
export 'core/crawler.dart';
export 'core/crawler_engine.dart';
export 'core/crawler_registry.dart';
export 'core/event_bus.dart';
export 'core/pipeline.dart';
export 'metrics/crawl_metrics.dart';
export 'schedule/crawl_schedule.dart';
export 'schedule/crawl_scheduler.dart';
export 'resilience/rate_limiter.dart';
export 'resilience/retry_policy.dart';
export 'stages/dedupe_stage.dart';
export 'stages/emit_stage.dart';
export 'stages/fetch_stage.dart';
export 'stages/persist_stage.dart';
export 'stages/transform_stage.dart';
export 'store/checkpoint_store.dart';
export 'store/dead_letter_store.dart';
export 'store/file_stores.dart';
export 'store/in_memory_stores.dart';
export 'store/record_store.dart';
export 'transport/http_request.dart';
export 'transport/http_transport.dart';
export 'transport/transport.dart';
export 'util/content_hash.dart';
export 'util/crawl_logging.dart';
