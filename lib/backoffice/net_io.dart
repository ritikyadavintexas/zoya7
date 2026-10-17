import 'dart:convert';
import 'dart:io';

Future<({int status, String body})> request(String method, String url, String? body,
    {String? contentType, Map<String, String>? headers}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client.openUrl(method, Uri.parse(url));
    headers?.forEach(req.headers.set);
    if (body != null) {
      req.headers.contentType = contentType == null ? ContentType.json : ContentType.parse(contentType);
      req.add(utf8.encode(body));
    }
    final res = await req.close().timeout(const Duration(seconds: 20));
    final text = await res.transform(utf8.decoder).join();
    return (status: res.statusCode, body: text);
  } finally {
    client.close();
  }
}
