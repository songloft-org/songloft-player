import 'package:flutter/foundation.dart';

final _tokenPattern = RegExp(
  r'((?:access_token|refresh_token|token)=)[^&\s<>"\x27]+',
  caseSensitive: false,
);

String redactDlnaTokens(String message) =>
    message.replaceAllMapped(_tokenPattern, (match) => '${match[1]}***');

/// debugPrint is captured by FileLogger at startup and included in log exports.
void dlnaLog(String message) {
  final redacted = redactDlnaTokens(
    message,
  ).replaceAll('\r', r'\r').replaceAll('\n', r'\n');
  const limit = 8192;
  debugPrint(
    '[DLNA] ${redacted.length > limit ? '${redacted.substring(0, limit)}…' : redacted}',
  );
}
