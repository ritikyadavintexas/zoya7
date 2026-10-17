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
}
