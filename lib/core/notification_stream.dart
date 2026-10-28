import 'dart:convert';

/// SSE frames can arrive split across arbitrary UTF-8 network chunks. Ignore
/// comments, unknown events and invalid JSON without ending a healthy stream.
Stream<Map<String, dynamic>> decodeNotificationStream(
  Stream<List<int>> bytes,
) async* {
  var event = '';
  final data = <String>[];
  await for (final line
      in bytes
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (event == 'inbox' && data.isNotEmpty) {
        try {
          final payload = jsonDecode(data.join('\n'));
          if (payload is Map<String, dynamic>) yield payload;
        } on FormatException {
          /* Wait for the next complete event. */
        }
      }
      event = '';
      data.clear();
    } else if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      data.add(line.substring(5).trimLeft());
    }
  }
}
