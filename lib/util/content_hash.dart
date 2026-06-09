import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 根据字段内容计算稳定 SHA-256 哈希，用于去重（字段顺序无关）。
String computeContentHash(Map<String, Object?> fields) {
  final keys = fields.keys.toList()..sort();
  final buffer = StringBuffer();
  for (final key in keys) {
    buffer
      ..write(key)
      ..write('=')
      ..write(jsonEncode(fields[key]))
      ..write('|');
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}
