import 'dart:convert';

import 'package:http/http.dart' as http;

import 'types.dart';

/// 执行 HTTP 请求
Future<ApiResponse> doRequest(http.Client client, ApiCall call) async {
  final method = call.method.toUpperCase();
  final url = call.url;

  http.Response raw;
  switch (method) {
    case 'GET':
      raw = await client.get(url, headers: call.headers);
      break;
    case 'POST':
      raw = await client.post(url, headers: call.headers, body: call.body);
      break;
    case 'PUT':
      raw = await client.put(url, headers: call.headers, body: call.body);
      break;
    case 'PATCH':
      raw = await client.patch(url, headers: call.headers, body: call.body);
      break;
    case 'DELETE':
      raw = await client.delete(url, headers: call.headers, body: call.body);
      break;
    default:
      final req = http.Request(method, url)..headers.addAll(call.headers);
      if (call.body != null) {
        if (call.body is List<int>) {
          req.bodyBytes = call.body as List<int>;
        } else if (call.body is String) {
          req.body = call.body as String;
        } else {
          req.body = jsonEncode(call.body);
        }
      }
      raw = await http.Response.fromStream(await client.send(req));
  }

  return ApiResponse(
    call: call,
    statusCode: raw.statusCode,
    headers: raw.headers,
    bodyBytes: raw.bodyBytes,
  );
}
