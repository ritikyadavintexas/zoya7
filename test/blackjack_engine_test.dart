import 'package:flutter_test/flutter_test.dart';
import 'package:zoya7_gold/games/blackjack/engine.dart';

PlayingCard c(String s) {
  final rank = switch (s.substring(0, s.length - 1)) {
    'A' => 1,
    'T' => 10,
    'J' => 11,
    'Q' => 12,
    'K' => 13,
    final n => int.parse(n),
  };
  final suit = switch (s[s.length - 1]) { 's' => Suit.spades, 'h' => Suit.hearts, 'd' => Suit.diamonds, _ => Suit.clubs };
  return PlayingCard(rank, suit);
}

/// A round whose shoe deals [cards] in order. Deal order: P, D-up, P, D-hole, then draws.
BlackjackRound round(String cards) => BlackjackRound(Shoe.stacked(cards.split(' ').map(c).toList()));

void main() {
  group('totals', () {
    test('Ace counts 11 until it would bust', () {
      expect(handTotal([c('As'), c('6h')]), (total: 17, soft: true));
      expect(handTotal([c('As'), c('6h'), c('9c')]), (total: 16, soft: false));
      expect(handTotal([c('As'), c('Ad'), c('9c')]), (total: 21, soft: true));
      expect(handTotal([c('Ks'), c('Qh'), c('2c')]).total, 22);
    });
  });

  test('blackjack pays 3 to 2', () {
    final r = round('As 9d Kh 7c')..deal(100);
    expect(r.phase, Phase.settled);
    expect(r.hands.single.outcome, Outcome.blackjack);
    expect(r.returned, 250);
  });

  test('player and dealer blackjack push', () {
    final r = round('As Ad Kh Kc')..deal(100);
    expect(r.phase, Phase.insurance);
    r.insurance(false);
    expect(r.phase, Phase.settled);
    expect(r.hands.single.outcome, Outcome.push);
    expect(r.returned, 100);
  });

  test('insurance pays 2 to 1 when the dealer has blackjack', () {
    final r = round('9s Ad 8h Kc')..deal(100);
    r.insurance(true);
    expect(r.insuranceBet, 50);
    expect(r.phase, Phase.settled);
    expect(r.hands.single.outcome, Outcome.lose);
    expect(r.returned, 150); // insurance 50 back + 100
    expect(r.staked, 150);
  });

  test('insurance is lost when the dealer has no blackjack, and play goes on', () {
    final r = round('9s Ad 8h 6c')..deal(100);
    r.insurance(true);
    expect(r.phase, Phase.player);
    r.stand();
    while (r.dealerStep()) {}
    expect(r.insuranceReturned, 0);
  });

  test('dealer peeks under a ten and ends the round at once', () {
    final r = round('9s Kd 8h Ac')..deal(100);
    expect(r.phase, Phase.settled);
    expect(r.hands.single.outcome, Outcome.lose);
  });

  test('dealer stands on soft 17', () {
    final r = round('Ts 6d 9h Ac')..deal(100);
    expect(r.phase, Phase.player);
    r.stand();
    while (r.dealerStep()) {}
    expect(r.dealer.length, 2);
    expect(handTotal(r.dealer).total, 17);
    expect(r.hands.single.outcome, Outcome.win); // 19 beats 17
  });

  test('dealer draws to 17 and can bust', () {
    final r = round('Ts 6d 8h Tc 9s')..deal(100);
    r.stand();
    while (r.dealerStep()) {}
    expect(handTotal(r.dealer).total, 25);
    expect(r.hands.single.outcome, Outcome.win);
    expect(r.returned, 200);
  });

  test('busting loses at once and the dealer does not draw', () {
    final r = round('Ts 6d 6h Tc 9s')..deal(100);
    r.hit();
    expect(r.hands.single.bust, isTrue);
    expect(r.phase, Phase.dealer);
    while (r.dealerStep()) {}
    expect(r.dealer.length, 2);
    expect(r.hands.single.outcome, Outcome.bust);
    expect(r.returned, 0);
  });

  test('double down doubles the bet and deals exactly one card', () {
    final r = round('6s 6d 5h Tc Ks 9c')..deal(100); // dealer 16, draws 9 = 25
    expect(r.canDouble, isTrue);
    r.doubleDown();
    expect(r.hands.single.bet, 200);
    expect(r.hands.single.total, 21);
    expect(r.phase, Phase.dealer);
    while (r.dealerStep()) {}
    expect(r.hands.single.outcome, Outcome.win);
    expect(r.returned, 400);
  });

  test('split makes two hands with their own bets, played in turn', () {
    final r = round('8s 6d 8h Tc 3s Kd 9c Tc')..deal(100);
    expect(r.canSplit, isTrue);
    r.split();
    expect(r.hands.length, 2);
    expect(r.hands.map((h) => h.bet), [100, 100]);
    expect(r.hands[0].total, 11);
    expect(r.active, 0);
    r.doubleDown(); // double after split: 8+3+9 = 20
    expect(r.active, 1);
    r.stand(); // 8 + K = 18
    expect(r.phase, Phase.dealer);
    while (r.dealerStep()) {} // dealer 6+T = 16, draws T = 26
    expect(r.hands.map((h) => h.outcome), [Outcome.win, Outcome.win]);
    expect(r.staked, 300);
    expect(r.returned, 600);
  });

  test('split Aces get one card each and 21 is not a blackjack', () {
    final r = round('As 9d Ah 7c Ks 5d 2c')..deal(100);
    r.split();
    expect(r.hands.every((h) => h.cards.length == 2), isTrue);
    expect(r.canSplit, isFalse);
    expect(r.phase, Phase.dealer);
    while (r.dealerStep()) {}
    expect(r.hands[0].total, 21);
    expect(r.hands[0].outcome, Outcome.win); // pays 1:1, not 3:2
    expect(r.hands[0].returned, 200);
    expect(handTotal(r.dealer).total, 18); // 9 + 7, draws 2
    expect(r.hands[1].outcome, Outcome.lose); // A + 5 = 16
  });

  test('a full shoe has 312 cards and reshuffles at the cut card', () {
    final s = Shoe();
    expect(s.remaining, 312);
    for (var i = 0; i < 234; i++) {
      s.draw();
    }
    expect(s.needsShuffle, isTrue);
  });
}
