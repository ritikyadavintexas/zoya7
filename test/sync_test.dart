import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoya7_gold/app/state.dart';
import 'package:zoya7_gold/backoffice/auth.dart';
import 'package:zoya7_gold/backoffice/casino.dart';
import 'package:zoya7_gold/backoffice/sync.dart';
import 'package:zoya7_gold/games/gold/src/math.dart';

import 'fake_firebase.dart';

const dbUrl = FakeFirebase.host;

void main() {
  late FakeFirebase db;
  var device = 0;

  /// A device with its own copy of the back office, synced to [db] — with
  /// everything open (no sign-in), as the tests' staff computer.
  Future<(Casino, CasinoSync)> join({Casino? casino}) async {
    final c = casino ?? Casino.demo(now: DateTime.now().subtract(Duration(minutes: device * 7)));
    final s = CasinoSync(c, transport: db.call, autoSync: false, storagePrefix: 'test.${device++}');
    await s.connect(dbUrl);
    return (c, s);
  }

  /// A player's phone: signs in through Firebase and sees only its own records.
  Future<(Casino, CasinoSync, AppState)> phone() async {
    final c = Casino.demo(now: DateTime.now());
    final s = CasinoSync(c, transport: db.call, auth: FirebaseAuthApi(post: db.post), autoSync: false, storagePrefix: 'test.${device++}');
    await s.connect(dbUrl);
    return (c, s, AppState(casino: c, sync: s));
  }

  /// A new player ID with its sign-in, made on [admin].
  Future<Player> newPlayer(Casino admin, String username, String password, {double startSc = 10}) async {
    final p = admin.createPlayer(username: username, startGc: 1000, startSc: startSc);
    final email = playerEmail(p.id, 0);
    final s = await FirebaseAuthApi(post: db.post).signUp(email, password);
    admin.linkLogin(p, s.uid, email);
    return p;
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
    admin.signIn('owner');
    final p = await newPlayer(admin, 'newphone', 'secret77');
    admin.coinIn(p, sc: 20, gc: 200000);
    await sAdmin.syncNow();
    expect(jsonEncode(db.tree), isNot(contains('secret77')), reason: 'passwords never reach the database');

    final (c, sPhone, app) = await phone();
    expect(await app.logIn('newphone', 'wrong'), 'Wrong password');
    expect(await app.logIn('nobody', 'secret77'), contains('No player'));
    expect(await app.logIn(p.id, 'secret77'), isNull, reason: sPhone.error);
    expect(app.sc, 30);
    // Only this player's records are on the phone.
    expect(c.players.map((x) => x.id), [p.id]);
    expect(c.staff, isEmpty);

    app.recordRound('classic777', Currency.sc, 5, 12);
    expect(app.sc, 37);
    await sPhone.syncNow();
    await sAdmin.syncNow();
    expect(admin.player(p.id)!.sc, 37);
    expect(admin.plays.values.where((x) => x.playerId == p.id).single.rounds, 1);
  });

  test('nothing is kept on the phone: reopened, it signs back in and loads from the server', () async {
    final (admin, sAdmin) = await join();
    admin.signIn('owner');
    final p = await newPlayer(admin, 'returner', 'secret77', startSc: 12);
    await sAdmin.syncNow();
    final prefix = 'test.${device++}';
    final first = CasinoSync(Casino.empty(), transport: db.call, auth: FirebaseAuthApi(post: db.post), autoSync: false, storagePrefix: prefix);
    await first.connect(dbUrl);
    expect(await AppState(casino: first.casino, sync: first).logIn('returner', 'secret77'), isNull);

    // The app is closed and opened again: an empty back office, the sign-in remembered.
    final c = Casino.empty();
    final s = CasinoSync(c, transport: db.call, auth: FirebaseAuthApi(post: db.post), autoSync: false, storagePrefix: prefix);
    await s.connect(dbUrl);
    final id = s.resumePlayer();
    final app = AppState(casino: c, playerId: id, sync: s);
    expect(c.players, isEmpty);
    expect(app.loading, isTrue);
    expect(app.kickedOut, isNull);
    for (var i = 0; i < 50 && !s.ready; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(app.loading, isFalse);
    expect(app.signedIn, isTrue);
    expect(app.sc, 12);
    expect(app.player!.id, p.id);
  });

  test('a phone can’t give itself coins: changes it may not make are undone', () async {
    final (admin, sAdmin) = await join();
    admin.signIn('owner');
    final p = await newPlayer(admin, 'sneaky', 'secret77');
    await sAdmin.syncNow();
    final (c, sPhone, app) = await phone();
    expect(await app.logIn('sneaky', 'secret77'), isNull);
    final before = app.sc;

    c.coinIn(c.player(p.id)!, sc: 500, checkLimit: false);
    c.updatePlayer(c.player(p.id)!, name: 'Hacker');
    app.claimBonus(); // the daily bonus is allowed
    await sPhone.syncNow();
    expect(app.sc, before);
    expect(c.player(p.id)!.name, isNot('Hacker'));
    await sAdmin.syncNow();
    expect(admin.player(p.id)!.sc, before);
    expect(admin.txnsOf(p.id).where((t) => t.type == TxnType.bonus), hasLength(1));
  });

  test('a password reset makes a new sign-in; the old password stops working', () async {
    final (admin, sAdmin) = await join();
    admin.signIn('owner');
    final p = await newPlayer(admin, 'forgetful', 'oldpass1');
    final email = playerEmail(p.id, 1);
    final s = await FirebaseAuthApi(post: db.post).signUp(email, 'newpass1');
    admin.linkLogin(p, s.uid, email, generation: 1);
    await sAdmin.syncNow();

    final (_, _, app) = await phone();
    expect(await app.logIn('forgetful', 'oldpass1'), 'Wrong password');
    expect(await app.logIn('forgetful', 'newpass1'), isNull);
  });

  test('changes made on two devices at once both survive', () async {
    final (admin, sAdmin) = await join();
    admin.signIn('owner');
    final (other, sOther) = await join();
    const id = 'Z7-100101';

    final before = admin.player(id)!.sc;
    // Neither has synced: the cashier adds coins while the other records play.
    admin.coinIn(admin.player(id)!, sc: 50);
    other.recordRound('fruitspin', id, Currency.sc, 10, 4);
    final out = admin.coinOut(admin.player(id)!, sc: 5);

    await sOther.syncNow();
    await sAdmin.syncNow();
    await sOther.syncNow();

    expect(admin.player(id)!.sc, other.player(id)!.sc);
    expect(admin.player(id)!.sc, closeTo(before + 50 - 5 - 6, .001));
    expect(other.txns.any((t) => t.id == out.id), isTrue);
  });

  test('after a restart, a stale copy doesn’t overwrite newer changes', () async {
    final (admin, sAdmin) = await join();
    admin.signIn('owner');
    final saved = jsonEncode(admin.toJson());
    admin.updatePlayer(admin.player('Z7-100101')!, name: 'Renamed');
    await sAdmin.syncNow();

    // Another device opens with yesterday's copy.
    final stale = Casino.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    final s = CasinoSync(stale, transport: db.call, autoSync: false, storagePrefix: 'test.${device - 1}');
    await s.connect(dbUrl);
    expect(stale.player('Z7-100101')!.name, 'Renamed');
    expect(db.tree!['players']['Z7-100101']['n'], 'Renamed');
  });

  test('closing an account logs the phone out; removing a player reaches every device', () async {
    final (admin, sAdmin) = await join();
    admin.signIn('owner');
    final p = await newPlayer(admin, 'closing', 'secret77');
    await sAdmin.syncNow();
    final (_, sPhone, app) = await phone();
    expect(await app.logIn(p.username, 'secret77'), isNull);

    admin.setPlayerStatus(p, PlayerStatus.banned);
    await sAdmin.syncNow();
    await sPhone.syncNow();
    expect(app.signedIn, isFalse);
    expect(app.kickedOut, 'This account is closed');
    expect(await app.logIn(p.username, 'secret77'), 'This account is closed');

    final (other, sOther) = await join();
    admin.deletePlayer(admin.player('Z7-100103')!);
    await sAdmin.syncNow();
    await sOther.syncNow();
    expect(other.player('Z7-100103'), isNull);
  });

  test('settings, games and staff changes sync; nothing is re-sent once settled', () async {
    final (admin, sAdmin) = await join();
    admin.signIn('owner');
    final (other, sOther) = await join();

    admin.setGameStatus('blackjack', GameStatus.maintenance);
    admin.updateSettings('starting amount', (s) => s.newPlayerSc = 7.5);
    admin.addStaff('u-nia', 'Nia', StaffRole.cashier, username: 'nia');
    await sAdmin.syncNow();
    await sOther.syncNow();
    expect(other.statusOf('blackjack'), GameStatus.maintenance);
    expect(other.settings.newPlayerSc, 7.5);
    expect(other.staff.map((s) => s.name), contains('Nia'));

    final writes = db.writes;
    await sAdmin.syncNow();
    await sOther.syncNow();
    await sAdmin.syncNow();
    expect(db.writes, writes, reason: 'settled copies must not keep writing');
  });

  test('offline changes are kept and sent when the database is back', () async {
    final (admin, sAdmin) = await join();
    admin.signIn('owner');
    db.down = true;
    final p = admin.createPlayer(username: 'offline1');
    await sAdmin.syncNow();
    expect(sAdmin.state, SyncState.offline);
    db.down = false;
    await sAdmin.syncNow();
    expect(sAdmin.state, SyncState.live);
    expect((db.tree!['players'] as Map).containsKey(p.id), isTrue);
  });

  test('first-time setup makes the owner and starts the database clean', () async {
    await join(); // demo data in the database
    final c = Casino.demo(now: DateTime.now());
    final auth = FirebaseAuthApi(post: db.post);
    final s = CasinoSync(c, transport: db.call, auth: auth, autoSync: false, storagePrefix: 'test.${device++}');
    await s.connect(dbUrl);
    final session = await auth.signUp(staffEmail('Bhanu2357'), 'secret77');
    await s.setUpOwner(session, 'Bhanu', 'Bhanu2357');
    expect(c.admin?.name, 'Bhanu');
    expect(c.players, isEmpty);
    expect(db.tree!['players'], isNull);
    expect((db.tree!['staff'] as Map).keys, [session.uid]);
    expect(db.tree!['games'], isNotEmpty);

    // Staff sign in with their username from then on.
    final again = await auth.signIn(staffEmail('bhanu2357'), 'secret77');
    expect(again.uid, session.uid);
  });
}
