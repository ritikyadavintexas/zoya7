import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'net.dart';

typedef HttpCall = Future<({int status, String body})> Function(String method, String url,
    [String? body, Map<String, String>? headers]);

/// The repository the site is built from: a commit to [branch] rebuilds and
/// republishes it (.github/workflows/preview.yml).
class GitHubRepo {
  const GitHubRepo({this.owner = 'ritikyadavintexas', this.name = 'zoya7', this.branch = 'main'});
  final String owner, name, branch;

  @override
  String toString() => '$owner/$name';
}

class GitHubError implements Exception {
  GitHubError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Commits files to the repository through GitHub's API, as one commit, with
/// a token the owner gives (a fine-grained token with Contents: Read and write
/// on the repository). Nothing else is needed: the push rebuilds the site.
class GitHubPublisher {
  GitHubPublisher(this.token, {this.repo = const GitHubRepo(), HttpCall? http}) : _http = http ?? httpRequest;

  final String token;
  final GitHubRepo repo;
  final HttpCall _http;

  Future<dynamic> _api(String method, String path, [Object? body]) async {
    ({int status, String body}) r;
    try {
      r = await _http(method, 'https://api.github.com/repos/${repo.owner}/${repo.name}$path', body == null ? null : jsonEncode(body), {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        if (body != null) 'Content-Type': 'application/json',
      });
    } catch (_) {
      throw GitHubError('Couldn’t reach GitHub. Check the connection.');
    }
    if (r.status >= 200 && r.status < 300) return r.body.isEmpty ? null : jsonDecode(r.body);
    String? detail;
    try {
      detail = (jsonDecode(r.body) as Map)['message'] as String?;
    } catch (_) {}
    throw switch (r.status) {
      401 => GitHubError('GitHub refused the token. Check it, or make a new one.'),
      403 || 404 => GitHubError('This token can’t write to $repo. It needs “Contents: Read and write” on that repository.'),
      _ => GitHubError('GitHub said: ${detail ?? r.status}'),
    };
  }

  /// Checks the token can reach the repository.
  Future<void> check() => _api('GET', '');

  /// Puts [files] in [folder] and deletes everything else under [clear] (old
  /// versions), as one commit. [progress] hears how far it got. Returns the
  /// commit's id.
  Future<String> publish({
    required String folder,
    required Map<String, Uint8List> files,
    required String clear,
    required String message,
    void Function(String step)? progress,
  }) async {
    final shas = <String, String>{};
    final paths = files.keys.toList();
    var done = 0;
    progress?.call('Uploading files 0/${paths.length}');
    Future<void> worker() async {
      while (paths.isNotEmpty) {
        final p = paths.removeLast();
        final blob = await _api('POST', '/git/blobs', {'content': base64Encode(files[p]!), 'encoding': 'base64'}) as Map;
        shas['$folder/$p'] = blob['sha'] as String;
        progress?.call('Uploading files ${++done}/${files.length}');
      }
    }

    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
    progress?.call('Saving to GitHub');
    return _commit(shas, clear, message);
  }

  /// Deletes everything under [folder], as one commit.
  Future<String> remove({required String folder, required String message}) => _commit(const {}, folder, message);

  Future<String> _commit(Map<String, String> add, String clear, String message) async {
    final prefix = clear.endsWith('/') ? clear : '$clear/';
    for (var attempt = 0;; attempt++) {
      final ref = await _api('GET', '/git/ref/heads/${repo.branch}') as Map;
      final head = (ref['object'] as Map)['sha'] as String;
      final commit = await _api('GET', '/git/commits/$head') as Map;
      final base = (commit['tree'] as Map)['sha'] as String;
      final tree = await _api('GET', '/git/trees/$base?recursive=1') as Map;
      final gone = [
        for (final e in (tree['tree'] as List).cast<Map>())
          if (e['type'] == 'blob' && (e['path'] as String).startsWith(prefix) && !add.containsKey(e['path'])) e['path'] as String,
      ];
      if (add.isEmpty && gone.isEmpty) return head;
      final newTree = await _api('POST', '/git/trees', {
        'base_tree': base,
        'tree': [
          for (final e in add.entries) {'path': e.key, 'mode': '100644', 'type': 'blob', 'sha': e.value},
          for (final p in gone) {'path': p, 'mode': '100644', 'type': 'blob', 'sha': null},
        ],
      }) as Map;
      final c = await _api('POST', '/git/commits', {
        'message': message,
        'tree': newTree['sha'],
        'parents': [head],
      }) as Map;
      try {
        await _api('PATCH', '/git/refs/heads/${repo.branch}', {'sha': c['sha'], 'force': false});
        return c['sha'] as String;
      } on GitHubError {
        // Someone else committed meanwhile: build on theirs (the files are already up).
        if (attempt >= 2) rethrow;
      }
    }
  }
}
