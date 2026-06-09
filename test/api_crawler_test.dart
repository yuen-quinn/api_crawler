import 'package:api_crawler/api_crawler.dart';
import 'package:test/test.dart';

void main() {
  group('computeContentHash', () {
    test('is stable regardless of field order', () {
      expect(
        computeContentHash({'a': 1, 'b': 'two'}),
        computeContentHash({'b': 'two', 'a': 1}),
      );
    });
  });

  group('MultiSimpleAdapter', () {
    test('fetches and merges multiple endpoints', () async {
      final transport = _MockTransport({
        'pubdev:http': {
          'package': RawPayload(
            statusCode: 200,
            headers: const {},
            body: {
              'name': 'http',
              'latest': {'version': '1.6.0', 'pubspec': {'description': 'HTTP lib'}},
              'versions': [{'version': '1.0.0'}, {'version': '1.6.0'}],
            },
            fetchedAt: DateTime.now().toUtc(),
            requestUrl: 'https://pub.dev/api/packages/http',
          ),
          'score': RawPayload(
            statusCode: 200,
            headers: const {},
            body: {
              'grantedPoints': 160,
              'maxPoints': 160,
              'likeCount': 100,
              'downloadCount30Days': 1000,
            },
            fetchedAt: DateTime.now().toUtc(),
            requestUrl: 'https://pub.dev/api/packages/http/score',
          ),
        },
      });

      final recordStore = InMemoryRecordStore();
      final crawler = Crawler.withEngine(
        engine: CrawlerEngine(
          recordStore: recordStore,
          checkpointStore: InMemoryCheckpointStore(),
          deadLetterStore: InMemoryDeadLetterStore(),
          transport: transport,
        ),
        recordStore: recordStore,
      );

      final run = await crawler.run(
        adapter: MultiSimpleAdapter(
          namespace: 'pubdev',
          discoverKeys: (_, __) => Stream.value('http'),
          endpoints: {
            'package': (name) => Uri.parse('https://pub.dev/api/packages/$name'),
            'score': (name) => Uri.parse('https://pub.dev/api/packages/$name/score'),
          },
          parseResponses: (name, bodies) {
            final detail = bodies['package'];
            final score = bodies['score'];
            if (detail is! Map || score is! Map) return null;
            return {
              'name': detail['name'],
              'latest_version': (detail['latest'] as Map)['version'],
              'version_count': (detail['versions'] as List).length,
              'granted_points': score['grantedPoints'],
            };
          },
        ),
        mode: CrawlMode.single,
        options: const CrawlOptions(singleIds: ['http'], batchSize: 1),
      );

      expect(run.result.success, isTrue);
      expect(run.result.metrics.fetched, 2);
      expect(run.records.single.fields['version_count'], 2);
      expect(run.records.single.fields['granted_points'], 160);
    });
  });

  group('SimpleAdapter', () {
    test('runs with callback adapter', () async {
      final transport = _MockTransport({
        'test:1': {
          'main': RawPayload(
            statusCode: 200,
            headers: const {},
            body: {'id': 1, 'title': 'Hello'},
            fetchedAt: DateTime.now().toUtc(),
            requestUrl: 'https://example.com/1',
          ),
        },
      });

      final recordStore = InMemoryRecordStore();
      final crawler = Crawler.withEngine(
        engine: CrawlerEngine(
          recordStore: recordStore,
          checkpointStore: InMemoryCheckpointStore(),
          deadLetterStore: InMemoryDeadLetterStore(),
          transport: transport,
        ),
        recordStore: recordStore,
      );

      final run = await crawler.run(
        adapter: SimpleAdapter(
          namespace: 'test',
          discoverKeys: (_, __) => Stream.value('1'),
          urlForKey: (key) => Uri.parse('https://example.com/$key'),
          parseFields: (_, body) {
            if (body is! Map) return null;
            return Map<String, Object?>.from(body);
          },
        ),
        mode: CrawlMode.single,
        options: const CrawlOptions(singleIds: ['1'], batchSize: 1),
      );

      expect(run.result.success, isTrue);
      expect(run.records, hasLength(1));
      expect(run.records.first.fields['title'], 'Hello');
    });
  });

  group('CrawlScheduler', () {
    test('runOnStart executes once', () async {
      final transport = _MockTransport({
        'test:1': {
          'main': RawPayload(
            statusCode: 200,
            headers: const {},
            body: {'id': 1},
            fetchedAt: DateTime.now().toUtc(),
            requestUrl: 'https://example.com/1',
          ),
        },
      });

      final recordStore = InMemoryRecordStore();
      final crawler = Crawler.withEngine(
        engine: CrawlerEngine(
          recordStore: recordStore,
          checkpointStore: InMemoryCheckpointStore(),
          deadLetterStore: InMemoryDeadLetterStore(),
          transport: transport,
        ),
        recordStore: recordStore,
      );

      final scheduler = CrawlScheduler(crawler: crawler);
      scheduler.add(
        CrawlSchedule.every(
          name: 'on-start',
          interval: const Duration(hours: 24),
          adapter: SimpleAdapter(
            namespace: 'test',
            discoverKeys: (_, __) => Stream.value('1'),
            urlForKey: (k) => Uri.parse('https://example.com/$k'),
            parseFields: (_, body) =>
                body is Map ? Map<String, Object?>.from(body) : null,
          ),
          mode: CrawlMode.single,
          options: const CrawlOptions(singleIds: ['1'], batchSize: 1),
          runOnStart: true,
        ),
      );

      await scheduler.start();
      await scheduler.stop();

      expect(await recordStore.count(), 1);
    });

    test('registers cron expression', () async {
      final crawler = Crawler.local(
        logging: const CrawlLoggingOptions(enabled: false),
      );
      final scheduler = CrawlScheduler(crawler: crawler);
      scheduler.add(
        CrawlSchedule.cron(
          name: 'cron-test',
          expression: '0 */6 * * *',
          adapter: _OneItemAdapter(),
        ),
      );

      await scheduler.start();
      await scheduler.stop();
    });
  });

  group('CrawlLifecycle', () {
    test('setup factory runs teardown even on success', () async {
      final phases = <String>[];
      final db = _FakeDb(phases);

      final transport = _MockTransport({
        'jsonplaceholder:1': {
          'post': RawPayload(
            statusCode: 200,
            headers: const {},
            body: {'id': 1, 'title': 'Hello'},
            fetchedAt: DateTime.now().toUtc(),
            requestUrl: 'https://example.com/1',
          ),
        },
      });

      final engine = CrawlerEngine(
        recordStore: InMemoryRecordStore(),
        checkpointStore: InMemoryCheckpointStore(),
        deadLetterStore: InMemoryDeadLetterStore(),
        transport: transport,
      );

      await engine.run(
        adapter: _OneItemAdapter(),
        mode: CrawlMode.single,
        options: const CrawlOptions(singleIds: ['1'], batchSize: 1),
        lifecycle: CrawlLifecycle.setup(
          setup: (_) async {
            await db.open();
            phases.add('db.open');
          },
          teardown: (_) async {
            await db.close();
            phases.add('db.close');
          },
        ),
      );

      expect(phases, ['db.open', 'db.close']);
      expect(db.isOpen, isFalse);
    });

    test('invokes hooks in order', () async {
      final phases = <String>[];

      final transport = _MockTransport({
        'jsonplaceholder:1': {
          'post': RawPayload(
            statusCode: 200,
            headers: const {},
            body: {'id': 1, 'title': 'Hello'},
            fetchedAt: DateTime.now().toUtc(),
            requestUrl: 'https://example.com/1',
          ),
        },
      });

      final engine = CrawlerEngine(
        recordStore: InMemoryRecordStore(),
        checkpointStore: InMemoryCheckpointStore(),
        deadLetterStore: InMemoryDeadLetterStore(),
        transport: transport,
      );

      await engine.run(
        adapter: _LifecycleAdapter(phases),
        mode: CrawlMode.single,
        options: const CrawlOptions(singleIds: ['1'], batchSize: 1),
        lifecycle: CrawlLifecycle(
          onStart: (_) => phases.add('lifecycle.onStart'),
          onBatchStart: (_, __) => phases.add('lifecycle.onBatchStart'),
          onBatchComplete: (_, __, ___) =>
              phases.add('lifecycle.onBatchComplete'),
          onComplete: (_, __) => phases.add('lifecycle.onComplete'),
          onFinally: (_) => phases.add('lifecycle.onFinally'),
        ),
      );

      expect(
        phases,
        [
          'lifecycle.onStart',
          'adapter.onStart',
          'lifecycle.onBatchStart',
          'lifecycle.onBatchComplete',
          'lifecycle.onComplete',
          'adapter.onComplete',
          'lifecycle.onFinally',
          'adapter.onDispose',
        ],
      );
    });
  });

  group('CrawlerEngine', () {
    test('runs pipeline with mock transport', () async {
      final transport = _MockTransport({
        'jsonplaceholder:1': {
          'post': RawPayload(
            statusCode: 200,
            headers: const {},
            body: {'id': 1, 'title': 'Hello'},
            fetchedAt: DateTime.now().toUtc(),
            requestUrl: 'https://example.com/1',
          ),
        },
      });

      final recordStore = InMemoryRecordStore();
      final engine = CrawlerEngine(
        recordStore: recordStore,
        checkpointStore: InMemoryCheckpointStore(),
        deadLetterStore: InMemoryDeadLetterStore(),
        transport: transport,
      );

      final result = await engine.run(
        adapter: _OneItemAdapter(),
        mode: CrawlMode.single,
        options: const CrawlOptions(singleIds: ['1'], batchSize: 1),
      );

      expect(result.success, isTrue);
      expect(result.metrics.upserted, 1);

      final stored = await recordStore.get(
        const ResourceId(namespace: 'jsonplaceholder', key: '1'),
      );
      expect(stored?.fields['title'], 'Hello');
    });
  });

  group('DedupeStage', () {
    test('skips unchanged records', () async {
      const id = ResourceId(namespace: 'test', key: 'a');
      final fields = {'x': 1};
      final hash = computeContentHash(fields);
      final record = CrawlRecord(
        id: id,
        fields: fields,
        contentHash: hash,
        extractedAt: DateTime.now().toUtc(),
      );

      final recordStore = InMemoryRecordStore();
      await recordStore.upsert(record);

      final ctx = CrawlContext(
        job: CrawlJob(
          id: 'test',
          mode: CrawlMode.single,
          adapter: _OneItemAdapter(),
          options: const CrawlOptions(),
        ),
        adapter: _OneItemAdapter(),
        transport: _MockTransport({}),
        recordStore: recordStore,
        checkpointStore: InMemoryCheckpointStore(),
        deadLetterStore: InMemoryDeadLetterStore(),
        metrics: CrawlMetrics(),
        events: EventBus(),
      );

      final stage = DedupeStage();
      final out = await stage.process(
        ctx,
        [CrawlItem(id: id, record: record)],
      );

      expect(out, isEmpty);
      expect(ctx.metrics.skipped, 1);
    });
  });
}

class _LifecycleAdapter extends _OneItemAdapter {
  _LifecycleAdapter(this.phases);

  final List<String> phases;

  @override
  Future<void> onStart(CrawlContext ctx) async {
    phases.add('adapter.onStart');
  }

  @override
  Future<void> onComplete(CrawlContext ctx, CrawlResult result) async {
    phases.add('adapter.onComplete');
  }

  @override
  Future<void> onDispose(CrawlContext ctx) async {
    phases.add('adapter.onDispose');
  }
}

class _OneItemAdapter extends ApiAdapter {
  @override
  String get namespace => 'jsonplaceholder';

  @override
  Stream<CrawlItem> discover({
    required CrawlContext ctx,
    required CrawlMode mode,
  }) async* {
    for (final id in ctx.options.singleIds) {
      yield CrawlItem(id: ResourceId(namespace: namespace, key: id));
    }
  }

  @override
  Future<List<EndpointSpec>> buildRequests(CrawlItem item) async {
    return [
      EndpointSpec(
        name: 'post',
        method: HttpMethod.get,
        url: Uri.parse('https://example.com/${item.id.key}'),
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

class _FakeDb {
  _FakeDb(this.phases);

  final List<String> phases;
  bool isOpen = false;

  Future<void> open() async {
    isOpen = true;
  }

  Future<void> close() async {
    isOpen = false;
  }
}

class _MockTransport implements Transport {
  _MockTransport(this._responses);

  final Map<String, Map<String, RawPayload>> _responses;

  @override
  Future<RawPayload> send(RequestSpec spec, CrawlContext ctx) async {
    final key = _itemKey(spec, ctx);
    final endpoint = _responses[key]?[spec.endpointName];
    if (endpoint == null) {
      return RawPayload(
        statusCode: 404,
        headers: const {},
        body: null,
        fetchedAt: DateTime.now().toUtc(),
        requestUrl: spec.url.toString(),
      );
    }
    return endpoint;
  }

  String _itemKey(RequestSpec spec, CrawlContext ctx) {
    final segments = spec.url.pathSegments;
    final packagesIndex = segments.indexOf('packages');
    if (packagesIndex >= 0 && packagesIndex + 1 < segments.length) {
      return '${ctx.adapter.namespace}:${segments[packagesIndex + 1]}';
    }
    return '${ctx.adapter.namespace}:${segments.last}';
  }
}
