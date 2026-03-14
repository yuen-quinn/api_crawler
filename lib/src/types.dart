import 'dart:convert';

/// 一次 API 调用的描述。
class ApiCall {
  final Uri url;
  final String method;
  final Map<String, String> headers;
  final Object? body;
  final Object? tag; // 自定义携带的上下文（页码等）

  const ApiCall({
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    this.body,
    this.tag,
  });
}

/// 单次响应（方便解析时使用）。
class ApiResponse {
  final ApiCall call;
  final int statusCode;
  final Map<String, String> headers;
  final List<int> bodyBytes;

  const ApiResponse({
    required this.call,
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
  });

  String get bodyText => utf8.decode(bodyBytes);

  dynamic json() => jsonDecode(bodyText);
}

/// 解析一次响应的结果：
/// - items：你要产出的数据
/// - next：接下来要继续请求的 API
class ParseResult {
  final List<Object?> items;
  final List<ApiCall> next;

  const ParseResult({this.items = const [], this.next = const []});
}

/// 解析函数：从响应中解析数据，并决定下一步要请求什么。
typedef ParseFn = Future<ParseResult> Function(ApiResponse response);
