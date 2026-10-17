import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zoya7_gold/admin/admin_app.dart';
import 'package:zoya7_gold/admin/upload.dart';
import 'package:zoya7_gold/app/assets.dart';
import 'package:zoya7_gold/app/html_host.dart';
import 'package:zoya7_gold/app/screens/lobby.dart';
import 'package:zoya7_gold/app/state.dart';
import 'package:zoya7_gold/backoffice/casino.dart';
import 'package:zoya7_gold/backoffice/github.dart';
import 'package:zoya7_gold/backoffice/sync.dart';
import 'package:zoya7_gold/games/html/model.dart';

import 'fake_firebase.dart';
import 'html_game_test.dart' show goodFiles, zip;

HtmlGame lanterns({int version = 1, bool live = true}) => HtmlGame(
      name: 'Lantern Drift',
      version: version,
      live: live,
      options: const [
        BetOption(id: 'main', outcomes: [
          Outcome(id: 'dark', multiplier: 0),
          Outcome(id: 'rose', label: 'Rose', multiplier: 2),
          Outcome(id: 'gold', label: 'Golden', multiplier: 30),
        ]),
      ],
    );

/// GitHub's API, as far as the publisher uses it.
class FakeGitHub {
  FakeGitHub(this.existing);
  final List<String> existing;
  final blobs = <String, String>{};
  List<Map>? tree;
  String? message;
  final calls = <String>[];

  Future<({int status, String body})> call(String method, String url, [String? body, Map<String, String>? headers]) async {
    final path = url.replaceFirst('https://api.github.com/repos/ritikyadavintexas/zoya7', '');
    calls.add('$method $path');
    if (headers?['Authorization'] != 'Bearer tok') return (status: 401, body: '{"message":"Bad credentials"}');
    final j = body == null ? null : jsonDecode(body) as Map;
    String ok(Object o) => jsonEncode(o);
    return switch ((method, path)) {
      ('POST', '/git/blobs') => (status: 201, body: ok({'sha': 'b${blobs.length}'}..also((m) => blobs[m['sha']!] = j!['content'] as String))),
      ('GET', '') => (status: 200, body: ok({'full_name': 'ritikyadavintexas/zoya7'})),
      ('GET', '/git/ref/heads/main') => (status: 200, body: ok({'object': {'sha': 'c1'}})),
      ('GET', '/git/commits/c1') => (status: 200, body: ok({'tree': {'sha': 't1'}})),
      ('GET', '/git/trees/t1?recursive=1') => (status: 200, body: ok({'tree': [for (final p in existing) {'path': p, 'type': 'blob', 'sha': 'x'}]})),
      ('POST', '/git/trees') => (status: 201, body: ok({'sha': 't2'}..also((_) => tree = (j!['tree'] as List).cast<Map>()))),
      ('POST', '/git/commits') => (status: 201, body: ok({'sha': 'c2'}..also((_) => message = j!['message'] as String))),
      ('PATCH', '/git/refs/heads/main') => (status: 200, body: ok({'object': {'sha': j!['sha']}})),
      _ => (status: 404, body: ok({'message': 'Not Found'})),
    };
  }
}

extension<T> on T {
  T also(void Function(T) f) {
    f(this);
    return this;
  }
}

void main() {
  group('the app’s side of the bridge', () {
    late AppState app;
    late HtmlGameHost host;
    var t = DateTime(2026, 10, 17, 12);

    setUp(() {
      app = AppState();
      app.casino.addUploadedGame('lanterns', lanterns());
      t = DateTime(2026, 10, 17, 12);
      host = HtmlGameHost(gameId: 'lanterns', app: app, random: Random(1), clock: () => t = t.add(const Duration(seconds: 1)));
    });

    Map<String, Object?> ask(String type, [Map<String, Object?> data = const {}]) {
      final (reply, _) = host.handle({'zoya7': 1, 'id': 7, 'type': type, 'data': data});
      expect(reply!['re'], 7);
      return reply;
    }

    test('init: balances, bet steps, and each outcome’s chance at the RTP', () {
      final s = ask('init')['data'] as Map;
      expect((s['balances'] as Map)['GC'], app.gc);
      expect((s['bets'] as Map)['GC'], betSteps(100, 50000));
      final outs = ((s['options'] as List).single as Map)['outcomes'] as List;
      final back = outs.fold<double>(0, (a, o) => a + ((o as Map)['chance'] as double) * (o['multiplier'] as double));
      expect(back, closeTo(.95, 1e-9));
    });

    test('a round takes the bet, pays the drawn outcome and books it', () {
      ask('init');
      final before = app.gc;
      final r = ask('play', {'option': 'main', 'currency': 'GC', 'bet': 500})['data'] as Map;
      final win = r['win'] as double;
      expect(win, 500 * (r['multiplier'] as double));
      expect(app.gc, before - 500 + win);
      expect((r['balances'] as Map)['GC'], app.gc);
      expect(app.casino.plays.values.where((p) => p.gameId == 'lanterns').single.rounds, 1);
    });

    test('the chances follow the RTP set in the admin panel', () {
      app.casino.updateGame('lanterns', 'rtp', (c) => c.targetRtp = .9);
      final outs = (((ask('init')['data'] as Map)['options'] as List).single as Map)['outcomes'] as List;
      final back = outs.fold<double>(0, (a, o) => a + ((o as Map)['chance'] as double) * (o['multiplier'] as double));
      expect(back, closeTo(.9, 1e-9));
    });

    test('refused: a bet not offered, too few coins, a game switched off', () {
      expect(ask('play', {'currency': 'GC', 'bet': 123})['error'], containsPair('code', 'bet'));
      app.casino.coinOut(app.player!, sc: app.sc - 10);
      expect(ask('play', {'currency': 'DC', 'bet': 50})['error'], containsPair('code', 'balance'));
      app.casino.setGameStatus('lanterns', GameStatus.maintenance);
      expect(ask('play', {'currency': 'GC', 'bet': 100})['error'], containsPair('code', 'closed'));
    });

    test('with Gold Coins switched off the game is offered DC only', () {
      app.casino.settings.hidden = {'gc'};
      final s = ask('init')['data'] as Map;
      expect(s['currency'], 'DC');
      expect(s['currencies'], ['DC']);
      expect((s['bets'] as Map)['GC'], isEmpty);
      expect(ask('play', {'option': 'main', 'currency': 'GC', 'bet': 100})['error'], containsPair('code', 'currency'));
      expect(ask('play', {'option': 'main', 'currency': 'DC', 'bet': (s['bets'] as Map)['DC'].first})['data'], isNotNull);
    });

    test('exit, ready and buy tell the screen what to do; coins added elsewhere reach the game', () {
      expect(host.handle({'zoya7': 1, 'type': 'exit'}).$2, HostAction.exit);
      expect(host.handle({'zoya7': 1, 'type': 'ready'}).$2, HostAction.ready);
      expect(host.handle({'zoya7': 1, 'type': 'buy'}).$2, HostAction.buyCoins);
      expect(host.handle({'type': 'exit'}).$2, HostAction.none, reason: 'not a bridge message');
      ask('init');
      expect(host.balanceEvent(), isNull);
      app.casino.coinIn(app.player!, gc: 1000);
      expect(host.balanceEvent()!['event'], 'balance');
    });
  });

  group('in the back office', () {
    test('an upload shows in the lobby once the site has it, survives a sync and can be removed', () {
      final c = Casino.demo();
      c.addUploadedGame('lanterns', lanterns(live: false));
      expect(games.first.id, 'lanterns');
      expect(games.first.image, 'games/lanterns/1/lobby/tile.png');
      expect(visibleGames(c).map((g) => g.id), isNot(contains('lanterns')));
      c.markLive('lanterns', 1);
      expect(visibleGames(c).map((g) => g.id), contains('lanterns'));
      expect(c.config('lanterns').kind, GameKind.html);

      final other = Casino.empty()..loadRecords(c.toRecords());
      expect(other.config('lanterns').html!.options.single.outcomes.map((o) => o.multiplier), [0, 2, 30]);
      expect(other.config('lanterns').html!.live, isTrue);

      c.removeUploadedGame('lanterns');
      other.loadRecords(c.toRecords());
      expect(other.configs.containsKey('lanterns'), isFalse);
      expect(games.map((g) => g.id), isNot(contains('lanterns')));
    });
  });

  test('through the database: published on the admin computer, it reaches the phones; removed, it leaves', () async {
    final db = FakeFirebase();
    final admin = Casino.demo();
    final sAdmin = CasinoSync(admin, transport: db.call, autoSync: false, storagePrefix: 'up.a');
    await sAdmin.connect(FakeFirebase.host);
    admin.signIn('owner');
    final phone = Casino.demo();
    final sPhone = CasinoSync(phone, transport: db.call, autoSync: false, storagePrefix: 'up.b');
    await sPhone.connect(FakeFirebase.host);

    admin.addUploadedGame('lanterns', lanterns(live: false));
    await sAdmin.syncNow();
    await sPhone.syncNow();
    expect(phone.config('lanterns').kind, GameKind.html);
    expect(visibleGames(phone).map((g) => g.id), isNot(contains('lanterns')), reason: 'not on the site yet');

    admin.markLive('lanterns', 1);
    await sAdmin.syncNow();
    await sPhone.syncNow();
    expect(visibleGames(phone).map((g) => g.id), contains('lanterns'));

    admin.removeUploadedGame('lanterns');
    await sAdmin.syncNow();
    await sPhone.syncNow();
    expect(phone.configs.containsKey('lanterns'), isFalse);
  });

  test('the GitHub token is kept beside the records, not with them', () async {
    final db = FakeFirebase();
    final c = Casino.demo();
    final s = CasinoSync(c, transport: db.call, autoSync: false, storagePrefix: 'tok');
    await s.connect(FakeFirebase.host);
    expect(await s.readSecret('github'), isNull);
    await s.writeSecret('github', 'github_pat_abc');
    expect(await s.readSecret('github'), 'github_pat_abc');
    expect(jsonEncode(db.tree), isNot(contains('github_pat_abc')), reason: 'synced records never carry it');
    await s.writeSecret('github', null);
    expect(await s.readSecret('github'), isNull);
  });

  group('GitHub', () {
    test('one commit: the new version’s files in, the old version’s out, nothing else touched', () async {
      final gh = FakeGitHub(['web/games/lanterns/1/index.html', 'web/games/lanterns/1/game.json', 'lib/main.dart']);
      final steps = <String>[];
      final sha = await GitHubPublisher('tok', http: gh.call).publish(
        folder: 'web/games/lanterns/2',
        files: {'index.html': Uint8List.fromList(utf8.encode('<p>hi</p>')), 'game.json': Uint8List.fromList(utf8.encode('{}'))},
        clear: 'web/games/lanterns',
        message: 'Add Lantern Drift (version 2)',
        progress: steps.add,
      );
      expect(sha, 'c2');
      expect(gh.blobs.values.map((b) => utf8.decode(base64Decode(b))), containsAll(['<p>hi</p>', '{}']));
      final byPath = {for (final e in gh.tree!) e['path']: e['sha']};
      expect(byPath.keys, unorderedEquals([
        'web/games/lanterns/2/index.html',
        'web/games/lanterns/2/game.json',
        'web/games/lanterns/1/index.html',
        'web/games/lanterns/1/game.json',
      ]));
      expect(byPath['web/games/lanterns/1/index.html'], isNull);
      expect(gh.calls.last, 'PATCH /git/refs/heads/main');
      expect(steps.last, 'Saving to GitHub');
    });

    test('a bad token gets a plain answer', () async {
      final gh = FakeGitHub([]);
      await expectLater(
        GitHubPublisher('wrong', http: gh.call).remove(folder: 'web/games/x', message: 'x'),
        throwsA(isA<GitHubError>().having((e) => e.message, 'message', contains('refused the token'))),
      );
    });
  });

  group('the admin uploader', () {
    setUpAll(() async {
      GoogleFonts.config.allowRuntimeFetching = false;
      for (final f in Directory('test/fonts').listSync().whereType<File>()) {
        final family = f.uri.pathSegments.last.replaceAll('.ttf', '');
        await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
      }
    });

    testWidgets('choose a zip, check it, publish it: the game is committed and waits for the site', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final gh = FakeGitHub([]);
      GameUpload.canPick = true;
      GameUpload.pick = () async => ('lanterns.zip', zip(goodFiles()));
      GameUpload.publisher = (token) => GitHubPublisher(token, http: gh.call);
      GameUpload.bridge = () async => Uint8List.fromList(utf8.encode('// bridge'));
      GameUpload.isLive = (id, v) async => false;
      String? saved;
      GameUpload.readToken = (_) async => saved;
      GameUpload.saveToken = (_, t) async => saved = t;

      final c = Casino.demo()..signIn('owner');
      await tester.pumpWidget(AdminApp(casino: c, initialSection: Section.games));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Upload a game'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose the game’s zip'));
      await tester.pumpAndSettle();
      expect(find.text('Lantern Drift'), findsWidgets);
      expect(find.textContaining('30×'), findsOneWidget);
      expect(find.textContaining('First time'), findsOneWidget);
      // No token yet: publishing asks for it, checks it with GitHub, saves it and carries on.
      await tester.tap(find.text('Publish to the lobby'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'tok');
      await tester.pump();
      await tester.tap(find.text('Save token'));
      await tester.pumpAndSettle();
      expect(saved, 'tok');
      expect(gh.calls.first, 'GET ');

      expect(gh.message, 'Add Lantern Drift (version 1) from the admin panel');
      expect(gh.tree!.map((e) => e['path']), containsAll(['web/games/lanterns/1/index.html', 'web/games/lanterns/1/zoya7-bridge.js']));
      expect(c.config('lanterns').html!.version, 1);
      expect(c.config('lanterns').html!.live, isFalse);
      expect(find.textContaining('switches on in the lobby by itself'), findsOneWidget);
      GameUpload.stopWatching();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
