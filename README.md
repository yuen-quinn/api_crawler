# api_crawler

A generic, extensible **API crawler framework** for Dart. Build data pipelines for any REST/JSON API with pluggable adapters, checkpointed sync, rate limiting, and dead-letter handling.

## Features

- **Adapter pattern** — implement one class per API (`discover`, `buildRequests`, `parse`)
- **Pipeline stages** — Fetch → Transform → Dedupe → Persist → Emit
- **Resilience** — rate limiter, retry with backoff, dead-letter queue
- **Storage** — in-memory (tests) and file-based (local dev) stores
- **Checkpoints** — resume full/incremental crawls after interruption
- **Events** — `RecordCreated`, `RecordUpdated`, `RecordDeleted` for downstream indexing

## Installation

```yaml
dependencies:
  api_crawler: ^0.1.0
```

For local development against this repository:

```yaml
dependencies:
  api_crawler:
    path: ../api_crawler
```

## Quick start

### 1. Implement an adapter

```dart
import 'package:api_crawler/api_crawler.dart';

class PostsAdapter extends ApiAdapter {
  @override
  String get namespace => 'posts-api';

  @override
  Stream<CrawlItem> discover({
    required CrawlContext ctx,
    required CrawlMode mode,
  }) async* {
    for (var i = 1; i <= (ctx.options.limit ?? 10); i++) {
      yield CrawlItem(id: ResourceId(namespace: namespace, key: '$i'));
    }
  }

  @override
  Future<List<EndpointSpec>> buildRequests(CrawlItem item) async {
    return [
      EndpointSpec(
        name: 'post',
        method: HttpMethod.get,
        url: Uri.parse('https://jsonplaceholder.typicode.com/posts/${item.id.key}'),
      ),
    ];
  }

  @override
  CrawlRecord? parse(CrawlItem item, Map<String, RawPayload> responses) {
    final body = responses['post']?.body;
    if (body is! Map) return null;

    final fields = Map<String, Object?>.from(body);
    return CrawlRecord(
      id: item.id,
      fields: fields,
      contentHash: computeContentHash(fields),
      extractedAt: DateTime.now().toUtc(),
    );
  }
}
```

### 2. Run the engine

```dart
final engine = CrawlerEngine(
  recordStore: FileRecordStore('./data/records'),
  checkpointStore: FileCheckpointStore('./data/checkpoints'),
  deadLetterStore: InMemoryDeadLetterStore(),
  transport: HttpTransport(
    rateLimiter: RateLimiter(minInterval: Duration(milliseconds: 100)),
  ),
);

final result = await engine.run(
  adapter: PostsAdapter(),
  mode: CrawlMode.full,
  options: const CrawlOptions(limit: 5, batchSize: 5),
);

print(result.metrics);
```

See [`example/example.dart`](example/example.dart) for a runnable sample.

## Architecture

```
ApiAdapter.discover()
       ↓ batches
┌──────────────────────────────────────┐
│ Fetch → Transform → Dedupe → Persist │
└──────────────────────────────────────┘
       ↓
 RecordStore + CrawlEvent
```

## Core types

| Type | Role |
|------|------|
| `ApiAdapter` | Define how to discover, fetch, and parse an API |
| `CrawlerEngine` | Orchestrate discovery, batching, checkpointing |
| `Pipeline` / `PipelineStage` | Composable processing chain |
| `CrawlItem` | Envelope passed between stages |
| `CrawlRecord` | Normalized stored document |
| `Transport` | HTTP layer (swap for mocks in tests) |
| `RecordStore` | Persistence abstraction |

## Crawl modes

| Mode | Use case |
|------|----------|
| `full` | Initial sync |
| `incremental` | Daily updates (adapter-defined) |
| `single` | One or more IDs via `CrawlOptions.singleIds` |
| `reconcile` | Fix drift / deleted resources |
| `backfill` | Historical range (adapter-defined) |

## Custom pipeline

```dart
final engine = CrawlerEngine(
  // ...
  pipeline: Pipeline([
    FetchStage(),
    TransformStage(),
    MyEnrichStage(), // custom
    DedupeStage(),
    PersistStage(),
    EmitStage(),
  ]),
);
```

## Testing

Use `InMemoryRecordStore` and a mock `Transport`:

```dart
final engine = CrawlerEngine(
  recordStore: InMemoryRecordStore(),
  checkpointStore: InMemoryCheckpointStore(),
  deadLetterStore: InMemoryDeadLetterStore(),
  transport: mockTransport,
);
```

## Related projects

Application-layer adapters (e.g. pub.dev) and CLI tools can live in separate packages that depend on `api_crawler`.

## License

MIT
