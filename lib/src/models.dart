import 'types.dart';

/// 抽象解析器基类
abstract class ApiResponseParser<T> {
  ParseResult parse(ApiResponse response);
}

/// 模型解析器接口
abstract class ModelParser<T> {
  T fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson(T model);
}

/// 自动 JSON 转模型解析器
class AutoModelParser<T> extends ApiResponseParser<T> {
  final ModelParser<T> modelParser;
  final T Function(Map<String, dynamic> json)? fromJsonOverride;
  final Map<String, dynamic> Function(T model)? toJsonOverride;

  AutoModelParser({
    required this.modelParser,
    this.fromJsonOverride,
    this.toJsonOverride,
  });

  @override
  ParseResult parse(ApiResponse response) {
    // 检查响应状态码
    if (response.statusCode != 200) {
      return const ParseResult();
    }

    final data = response.json();
    if (data is! Map<String, dynamic>) return const ParseResult();

    final model = fromJsonOverride?.call(data) ?? modelParser.fromJson(data);
    final result = toJsonOverride?.call(model) ?? modelParser.toJson(model);
    
    return ParseResult(items: [result]);
  }
}

/// 列表页自动解析器
class AutoListParser<T> extends ApiResponseParser<void> {
  final ModelParser<T> modelParser;
  final String Function(T model) idExtractor;
  final String Function(String id) detailUrlBuilder;
  final String Function(Map<String, dynamic> json) nextPageUrlExtractor;
  final String listKey;

  AutoListParser({
    required this.modelParser,
    required this.idExtractor,
    required this.detailUrlBuilder,
    required this.nextPageUrlExtractor,
    this.listKey = 'items',
  });

  @override
  ParseResult parse(ApiResponse response) {
    // 检查响应状态码
    if (response.statusCode != 200) {
      return const ParseResult();
    }

    final data = response.json();
    if (data is! Map<String, dynamic>) return const ParseResult();

    final items = (data[listKey] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((json) => modelParser.fromJson(json))
        .toList();

    final nextCalls = <ApiCall>[];

    // 添加分页请求
    final nextPageUrl = nextPageUrlExtractor(data);
    if (nextPageUrl.isNotEmpty) {
      nextCalls.add(ApiCall(url: Uri.parse(nextPageUrl)));
    }

    // 添加详情请求
    for (final item in items) {
      final id = idExtractor(item);
      if (id.isNotEmpty) {
        nextCalls.add(ApiCall(url: Uri.parse(detailUrlBuilder(id))));
      }
    }

    return ParseResult(next: nextCalls);
  }
}

/// 多解析器管理器
class MultiParser extends ApiResponseParser<Map<String, dynamic>> {
  final List<ApiResponseParser> parsers;

  MultiParser(this.parsers);

  @override
  ParseResult parse(ApiResponse response) {
    for (final parser in parsers) {
      final result = parser.parse(response);
      if (result.items.isNotEmpty || result.next.isNotEmpty) {
        return result;
      }
    }
    return const ParseResult();
  }
}
