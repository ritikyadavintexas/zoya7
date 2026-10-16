import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoya7_gold/app/state.dart';
import 'package:zoya7_gold/backoffice/casino.dart';
import 'package:zoya7_gold/backoffice/sync.dart';
import 'package:zoya7_gold/games/gold/src/math.dart';

/// Firebase Realtime Database's REST API, in memory: GET the tree, PATCH a
/// multi-path update (null removes), PUT the whole tree. Numbers come back the
/// way Firebase sends them (2.0 as 2).
class FakeFirebase {
  Map<String, dynamic>? tree;
  int writes = 0;
  bool down = false;

  Future<({int status, String body})> call(String method, String url, [String? body]) async {
    if (down) throw 'offline';
    expect(url, 'https://zoya7-test-default-rtdb.firebaseio.com/zoya7.json');
    switch (method) {
      case 'GET':
        return (status: 200, body: jsonEncode(_firebaseNumbers(tree)));
      case 'PATCH':
        writes++;
        final t = tree ??= {};
        for (final e in (jsonDecode(body!) as Map<String, dynamic>).entries) {
          final parts = e.key.split('/');
          final group = (t[parts[0]] ??= <String, dynamic>{}) as Map<String, dynamic>;
          if (e.value == null) {
            group.remove(parts[1]);
          } else {
            group[parts[1]] = e.value;
          }
        }
        return (status: 200, body: body);
      case 'PUT':
        writes++;
        tree = jsonDecode(body!) as Map<String, dynamic>;
        return (status: 200, body: body);
    }
    return (status: 405, body: '');
  }

  static Object? _firebaseNumbers(Object? v) => switch (v) {
        Map() => {for (final e in v.entries) e.key: _firebaseNumbers(e.value)},
        List() => [for (final x in v) _firebaseNumbers(x)],
        double() when v == v.truncateToDouble() => v.toInt(),
        _ => v,
      };
}

const dbUrl = 'https://zoya7-test-default-rtdb.firebaseio.com/';

void main() {
  late FakeFirebase db;
  var device = 0;

  /// A device: its own copy of the back office, synced to [db].
  Future<(Casino, CasinoSync)> join({Casino? casino}) async {
    final c = casino ?? Casino.demo(now: DateTime.now().subtract(Duration(minutes: device * 7)));
    final s = CasinoSync(c, transport: db.call, autoSync: false, storagePrefix: 'test.${device++}');
    await s.connect(dbUrl);
    return (c, s);
  }

  setUp(() => db = FakeFirebase());

  test('the first device fills an empty database; the next one takes what is there', () async {
    final (a, sa) = await join();
    expect(sa.state, SyncState.live, reason: sa.error);
    expect((db.tree!['players'] as Map).length, a.players.length);

    final (b, sb) = await join();
    expect(sb.state, SyncState.live, reason: sb.error);
    expect(b.players.map((p) => p.id).toSet(), a.players.map((p) => p.id).toSet());
    expect(b.txns.length, a.txns.length);
    expect(b.player('Z7-100101')!.sc, a.player('Z7-100101')!.sc);
  });

  test('a player ID made on the admin computer can log in on a phone and play', () async {
    final (admin, sAdmin) = await join();
    admin.signIn('1234');
    final (phone, sPhone) = await join();

    final p = admin.createPlayer(username: 'newphone', startGc: 1000, startSc: 10);
    admin.coinIn(p, sc: 20, gc: 200000);
    await sAdmin.syncNow();
    await sPhone.syncNow();

    final app = AppState(casino: phone);
    expect(app.logIn('newphone', 'wrong'), 'Wrong password');
    expect(app.logIn(p.id, p.password), isNull);
    expect(app.sc, 30);

    app.recordRound('classic777', Currency.sc, 5, 12);
    expect(app.sc, 37);
    await sPhone.syncNow();
    await sAdmin.syncNow();
    expect(admin.player(p.id)!.sc, 37);
    expect(admin.plays.values.where((x) => x.playerId == p.id).single.rounds, 1);
  });

  test('changes made on two devices at once both survive', () async {
    final (admin, sAdmin) = await join();
    admin.signIn('1234');
    final (phone, sPhone) = await join();
    const id = 'Z7-100101';

    final before = admin.player(id)!.sc;
    // Neither has synced: the cashier adds coins while the player plays.
    admin.coinIn(admin.player(id)!, sc: 50);
    phone.recordRound('fruitspin', id, Currency.sc, 10, 4);
    final out = admin.coinOut(admin.player(id)!, sc: 5);

    await sPhone.syncNow();
    await sAdmin.syncNow();
    await sPhone.syncNow();

    expect(admin.player(id)!.sc, phone.player(id)!.sc);
    expect(admin.player(id)!.sc, closeTo(before + 50 - 5 - 6, .001));
    expect(phone.txns.any((t) => t.id == out.id), isTrue);
  });

  test('removing a player and closing an account reach the other devices', () async {
    final (admin, sAdmin) = await join();
    admin.signIn('1234');
    final (phone, sPhone) = await join();
    final app = AppState(casino: phone);
    final p = admin.player('Z7-100102')!;
    expect(app.logIn(p.username, p.password), isNull);

    admin.setPlayerStatus(p, PlayerStatus.banned);
    await sAdmin.syncNow();
    await sPhone.syncNow();
    expect(app.signedIn, isFalse);
    expect(app.kickedOut, 'This account is closed');
    expect(app.logIn(p.username, p.password), 'This account is closed');

    admin.deletePlayer(admin.player('Z7-100103')!);
    await sAdmin.syncNow();
    await sPhone.syncNow();
    expect(phone.player('Z7-100103'), isNull);
  });

  test('settings, games and staff changes sync; nothing is re-sent once settled', () async {
    final (admin, sAdmin) = await join();
    admin.signIn('1234');
    final (phone, sPhone) = await join();

    admin.setGameStatus('blackjack', GameStatus.maintenance);
    admin.updateSettings('starting amount', (s) => s.newPlayerSc = 7.5);
    admin.addStaff('Nia', StaffRole.cashier, '4321');
    await sAdmin.syncNow();
    await sPhone.syncNow();
    expect(phone.statusOf('blackjack'), GameStatus.maintenance);
    expect(phone.settings.newPlayerSc, 7.5);
    expect(phone.staff.map((s) => s.name), contains('Nia'));

    final writes = db.writes;
    await sAdmin.syncNow();
    await sPhone.syncNow();
    await sAdmin.syncNow();
    expect(db.writes, writes, reason: 'settled copies must not keep writing');
  });

  test('offline changes are kept and sent when the database is back', () async {
    final (admin, sAdmin) = await join();
    admin.signIn('1234');
    db.down = true;
    final p = admin.createPlayer(username: 'offline1');
    await sAdmin.syncNow();
    expect(sAdmin.state, SyncState.offline);
    db.down = false;
    await sAdmin.syncNow();
    expect(sAdmin.state, SyncState.live);
    expect((db.tree!['players'] as Map).containsKey(p.id), isTrue);
  });
}
