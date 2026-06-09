import '../core/crawl_mode.dart';

/// HTTP 请求规格。
class RequestSpec {
  const RequestSpec({
    required this.method,
    required this.url,
    this.headers = const {},
    this.body,
    this.timeout = const Duration(seconds: 30),
    this.endpointName = 'default',
  });

  final HttpMethod method;
  final Uri url;
  final Map<String, String> headers;
  final Object? body;
  final Duration timeout;

  /// 对应 [EndpointSpec.name]，用于响应索引。
  final String endpointName;
}
