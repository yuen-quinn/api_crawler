import 'dart:convert';

import 'types.dart';

/// 队列条目
class QueueEntry {
  final ApiCall call;
  final int retries;

  QueueEntry(this.call, this.retries);
}

/// 生成请求指纹用于去重
String fingerprint(ApiCall call) {
  final buffer = StringBuffer()
    ..write(call.method.toUpperCase())
    ..write(' ')
    ..write(call.url.toString());

  if (call.body != null) {
    if (call.body is String) {
      buffer.write(' body:${call.body as String}');
    } else {
      buffer.write(' body:${jsonEncode(call.body)}');
    }
  }

  return buffer.toString();
}
