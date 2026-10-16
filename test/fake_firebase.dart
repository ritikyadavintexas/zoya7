import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

/// Firebase in memory: the Realtime Database's REST API (GET / PUT a path,
/// PATCH a multi-path update where null removes; numbers come back the way
/// Firebase sends them, 2.0 as 2) and Authentication's email sign-in.
class FakeFirebase {
  Map<String, dynamic>? tree;
  int writes = 0;
  bool down = false;
  final accounts = <String, ({String uid, String password})>{};

  static const host = 'https://zoya7-test-default-rtdb.firebaseio.com/';

  Future<({int status, String body})> call(String method, String url, [String? body]) async {
    if (down) throw 'offline';
    expect(url, startsWith(host));
    // The app keeps everything under /zoya7; [tree] is that node.
    final path = Uri.parse(url).path.replaceFirst(RegExp(r'\.json$'), '').split('/').where((s) => s.isNotEmpty).skip(1).toList();
    switch (method) {
      case 'GET':
        Object? node = tree;
        for (final s in path) {
          node = node is Map ? node[s] : null;
        }
        return (status: 200, body: jsonEncode(_firebaseNumbers(node)));
      case 'PATCH':
        writes++;
        for (final e in (jsonDecode(body!) as Map<String, dynamic>).entries) {
          _set([...path, ...e.key.split('/')], e.value);
        }
        return (status: 200, body: body);
      case 'PUT':
        writes++;
        _set(path, jsonDecode(body!));
        return (status: 200, body: body);
    }
    return (status: 405, body: '');
  }

  void _set(List<String> path, Object? value) {
    if (path.isEmpty) {
      tree = value as Map<String, dynamic>?;
      return;
    }
    Map<String, dynamic> node = tree ??= {};
    for (final s in path.take(path.length - 1)) {
      node = (node[s] ??= <String, dynamic>{}) as Map<String, dynamic>;
    }
    value == null ? node.remove(path.last) : node[path.last] = value;
  }

  /// Authentication's REST API.
  Future<({int status, String body})> post(String url, String body, String type) async {
    if (down) throw 'offline';
    ({int status, String body}) err(String m) => (status: 400, body: jsonEncode({'error': {'message': m}}));
    ({int status, String body}) ok(String uid) =>
        (status: 200, body: jsonEncode({'localId': uid, 'idToken': 'tok-$uid', 'refreshToken': 'ref-$uid', 'expiresIn': '3600'}));
    if (url.contains('accounts:signUp')) {
      final j = jsonDecode(body) as Map;
      if (accounts.containsKey(j['email'])) return err('EMAIL_EXISTS');
      if ((j['password'] as String).length < 6) return err('WEAK_PASSWORD : Password should be at least 6 characters');
      final uid = 'u${accounts.length + 1}';
      accounts[j['email'] as String] = (uid: uid, password: j['password'] as String);
      return ok(uid);
    }
    if (url.contains('accounts:signInWithPassword')) {
      final j = jsonDecode(body) as Map;
      final a = accounts[j['email']];
      return a == null || a.password != j['password'] ? err('INVALID_LOGIN_CREDENTIALS') : ok(a.uid);
    }
    final uid = Uri.splitQueryString(body)['refresh_token']!.substring(4);
    return (status: 200, body: jsonEncode({'user_id': uid, 'id_token': 'tok-$uid', 'refresh_token': 'ref-$uid', 'expires_in': '3600'}));
  }

  static Object? _firebaseNumbers(Object? v) => switch (v) {
        Map() => {for (final e in v.entries) e.key: _firebaseNumbers(e.value)},
        List() => [for (final x in v) _firebaseNumbers(x)],
        double() when v == v.truncateToDouble() => v.toInt(),
        _ => v,
      };
}
