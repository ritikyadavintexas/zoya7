import 'package:flutter_test/flutter_test.dart';
import 'package:zoya7_gold/backoffice/casino.dart';

/// Owner → executive → agent → player: who adds whom, and points moving down
/// (and back up) the chain.
void main() {
  late Casino c;
  late Staff exec, agent;

  setUp(() {
    c = Casino.demo()..signIn('owner');
    exec = c.addStaff('u-exec', 'Ella', StaffRole.executive, username: 'ella');
    agent = c.addStaff('u-agent', 'Omar', StaffRole.agent, username: 'omar', parent: exec.uid);
  });

  test('points flow owner → executive → agent → player, and back', () {
    c.givePoints(exec, gc: 1000000, sc: 500);
    expect((exec.gc, exec.sc), (1000000, 500));

    c.signIn('u-exec');
    expect(() => c.givePoints(agent, sc: 600), throwsA(isA<CasinoError>()), reason: 'more than the executive has');
    c.givePoints(agent, gc: 400000, sc: 200);
    expect((exec.gc, exec.sc), (600000, 300));
    expect((agent.gc, agent.sc), (400000, 200));

    c.signIn('u-agent');
    final p = c.createPlayer(username: 'groundplayer');
    expect(p.agent, agent.uid);
    expect(() => c.coinIn(p, sc: 250), throwsA(isA<CasinoError>()), reason: 'more than the agent has');
    final before = p.sc;
    c.coinIn(p, gc: 100000, sc: 150);
    expect((agent.gc, agent.sc), (300000, 50));
    expect(p.sc, before + 150);
    c.coinOut(p, sc: 40);
    expect(agent.sc, 90, reason: 'a coin out puts the points back with the agent');

    c.signIn('u-exec');
    c.takePoints(agent, sc: 90);
    expect((exec.sc, agent.sc), (390, 0));

    // It all survives a round trip through the database records.
    final copy = Casino.empty()..loadRecords(c.toRecords());
    expect(copy.staffBy('u-exec')!.sc, 390);
    expect(copy.staffBy('u-agent')!.parent, 'u-exec');
    expect(copy.player(p.id)!.agent, 'u-agent');
  });

  test('who may add whom: the owner adds executives, executives agents, agents refer agents', () {
    c.signIn('u-exec');
    expect(() => c.addStaff('x', 'X', StaffRole.executive), throwsA(isA<CasinoError>()));
    final a2 = c.addStaff('u-a2', 'Ana', StaffRole.agent, parent: 'someone-else');
    expect(a2.parent, exec.uid, reason: 'an executive’s agents are theirs');
    expect(() => c.createPlayer(username: 'notmine'), throwsA(isA<CasinoError>()), reason: 'executives don’t make player IDs');

    c.signIn('u-agent');
    final ref = c.addStaff('u-a3', 'Raj', StaffRole.agent);
    expect(ref.parent, exec.uid, reason: 'a referral joins the same executive');
    expect(ref.referredBy, agent.uid);
    expect(c.teamOf(agent).map((s) => s.uid), ['u-a3']);
    expect(c.supplies(agent, ref), isFalse, reason: 'agents don’t give agents points');
    expect(c.supplies(exec, ref), isTrue);
  });

  test('each sees only their own: agents their players, executives their agents’ players', () {
    c.signIn('u-agent');
    final mine = c.createPlayer(username: 'omarsplayer');
    final others = c.players.firstWhere((p) => p.agent != agent.uid);
    expect(c.visiblePlayers.map((p) => p.id), [mine.id]);
    expect(() => c.coinIn(others, gc: 10), throwsA(isA<CasinoError>()));

    c.signIn('u-exec');
    expect(c.visiblePlayers.map((p) => p.id), [mine.id]);
    expect(() => c.coinIn(mine, gc: 10), throwsA(isA<CasinoError>()), reason: 'executives supply agents, not players');

    c.signIn('owner');
    expect(c.visiblePlayers.length, c.players.length);
  });

  test('switched off can’t sign in; nobody with points or agents can be removed', () {
    c.givePoints(exec, gc: 10);
    expect(() => c.removeStaff(exec), throwsA(isA<CasinoError>()));
    c.takePoints(exec, gc: 10);
    expect(() => c.removeStaff(exec), throwsA(isA<CasinoError>()), reason: 'still has agents');
    c.setStaffActive(agent, false);
    expect(c.signIn('u-agent'), isNull);
    c.signIn('owner');
    c.setStaffActive(agent, true);
    expect(c.signIn('u-agent'), isNotNull);
  });

  test('coin in / out totals: everyone sees only their own part of the chain', () {
    final other = c.addStaff('u-agent2', 'Zed', StaffRole.agent, parent: exec.uid);
    c.givePoints(exec, sc: 1000);
    c.signIn('u-exec');
    c.givePoints(agent, sc: 300);
    c.givePoints(other, sc: 300);

    c.signIn('u-agent');
    final mine = c.createPlayer(username: 'omarone');
    c.coinIn(mine, sc: 100);
    c.signIn('u-agent2');
    final theirs = c.createPlayer(username: 'zedone');
    c.coinIn(theirs, sc: 40);
    c.coinOut(theirs, sc: 10);
    c.signIn('owner');
    c.coinIn(c.players.firstWhere((p) => p.agent.isEmpty), sc: 7);

    final today = Period.standard(c.now).first;
    Report as(String uid) {
      c.signIn(uid, log: false);
      return c.report(today);
    }

    final omar = as('u-agent');
    expect((omar.coinInSc, omar.coinOutSc, omar.coinIns), (100, 0, 1), reason: 'only Omar’s own player');
    expect(c.daily(1).single.coinIn, 100);
    final zed = as('u-agent2');
    expect((zed.coinInSc, zed.coinOutSc), (40, 10));
    final ella = as('u-exec');
    expect((ella.coinInSc, ella.coinOutSc), (140, 10), reason: 'her two agents’ players, nobody else’s');
    final owner = as('owner');
    expect(owner.coinInSc, greaterThanOrEqualTo(147));
  });

  test('a player asks for coins; their agent puts them on from their own points', () {
    c.givePoints(exec, gc: 1000000, sc: 500);
    c.signIn('u-exec');
    c.givePoints(agent, gc: 500000, sc: 200);
    c.signIn('u-agent');
    final p = c.createPlayer(username: 'asker');
    final before = p.sc;

    final r = c.requestCoins(p, sc: 37.5, gc: 20000);
    expect(c.waitingRequests, [r]);
    c.signIn('u-exec');
    expect(c.waitingRequests, isEmpty, reason: 'executives don’t load players');
    c.signIn('leo');
    expect(c.waitingRequests, isEmpty, reason: 'another agent’s player');
    c.signIn('owner');
    expect(c.waitingRequests, [r], reason: 'the owner sees every request');

    c.signIn('u-agent');
    c.approveRequest(r);
    expect(p.sc, before + 37.5);
    expect((agent.gc, agent.sc), (480000, 162.5));
    expect(r.status, RequestStatus.done);
    expect(c.waitingRequests, isEmpty);
    expect(() => c.approveRequest(r), throwsA(isA<CasinoError>()), reason: 'only once');

    final r2 = c.requestCoins(p, sc: 5);
    c.declineRequest(r2);
    expect(r2.status, RequestStatus.declined);
    expect(p.sc, before + 37.5);

    // Requests and avatars survive the database records.
    c.setAvatar(p.id, 'phoenix');
    final copy = Casino.empty()..loadRecords(c.toRecords());
    expect(copy.requests.map((x) => (x.id, x.playerId, x.sc, x.gc, x.status)), c.requests.map((x) => (x.id, x.playerId, x.sc, x.gc, x.status)));
    expect(copy.avatars[p.id], 'phoenix');
  });

  test('request limits: an amount, at most three waiting, store and GC switches', () {
    c.signIn('owner');
    final p = c.players.first;
    expect(() => c.requestCoins(p), throwsA(isA<CasinoError>()), reason: 'nothing asked for');
    expect(() => c.requestCoins(p, sc: c.settings.maxCoinInPerDay + 1), throwsA(isA<CasinoError>()));
    for (var i = 0; i < 3; i++) {
      c.requestCoins(p, sc: 1);
    }
    expect(() => c.requestCoins(p, sc: 1), throwsA(isA<CasinoError>()), reason: 'three already waiting');

    final q = c.players[1];
    c.settings.hidden = {'gc'};
    expect(c.requestCoins(q, gc: 5000, sc: 2).gc, 0, reason: 'GC off: no Gold Coins asked for');
    c.settings.hidden = {'store'};
    expect(() => c.requestCoins(q, sc: 2), throwsA(isA<CasinoError>()), reason: 'buying switched off');
  });

  test('switching parts of the player app off', () {
    final s = c.settings;
    expect(CasinoSettings.playerFeatures.keys.every(s.shows), isTrue, reason: 'everything on by default');
    s.hidden = {'gc'};
    expect((s.gcOn, s.shows('daily'), s.shows('jackpots'), s.shows('vip')), (false, false, false, true),
        reason: 'GC off takes the GC bonus and jackpots with it');
    s.hidden = {'vip', 'jackpots'};
    expect((s.gcOn, s.shows('vip'), s.shows('jackpots'), s.shows('daily')), (true, false, false, true));
    final copy = CasinoSettings.fromJson(s.toJson());
    expect(copy.hidden, {'vip', 'jackpots'});
  });
}
