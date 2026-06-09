import '../adapter/api_adapter.dart';

typedef AdapterFactory = ApiAdapter Function();

/// 适配器注册表，用于按名称创建适配器（CLI、多租户场景）。
class CrawlerRegistry {
  CrawlerRegistry();

  final _factories = <String, AdapterFactory>{};

  void register(String name, AdapterFactory factory) {
    _factories[name] = factory;
  }

  ApiAdapter create(String name) {
    final factory = _factories[name];
    if (factory == null) {
      throw ArgumentError('Unknown adapter: $name');
    }
    return factory();
  }

  Iterable<String> get names => _factories.keys;
}
