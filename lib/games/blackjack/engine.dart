import 'dart:math';

/// Blackjack rules and round logic, with no UI. One [BlackjackRound] is one
/// hand of play: deal → (insurance) → player decisions → dealer → settle.
///
/// Table rules: 6 decks, reshuffled at 75% penetration; dealer stands on all
/// 17s and peeks for blackjack under an Ace or a ten; blackjack pays 3 to 2;
/// insurance pays 2 to 1; double on any first two cards, also after a split;
/// split up to four hands; split Aces get one card each and can't be re-split;
/// 21 on a split hand isn't a blackjack.

enum Suit { spades, hearts, diamonds, clubs }

class PlayingCard {
  const PlayingCard(this.rank, this.suit);

  /// 1 = Ace, 11–13 = J, Q, K.
  final int rank;
  final Suit suit;

  bool get isAce => rank == 1;
  bool get isRed => suit == Suit.hearts || suit == Suit.diamonds;

  /// Hard value (Ace counts 1).
  int get value => rank >= 10 ? 10 : rank;

  String get label => switch (rank) { 1 => 'A', 11 => 'J', 12 => 'Q', 13 => 'K', _ => '$rank' };

  @override
  String toString() => '$label${suit.name[0]}';
}

/// A multi-deck shoe with a cut card at 75%.
class Shoe {
  Shoe({this.decks = 6, Random? rng}) : _rng = rng ?? Random() {
    shuffle();
  }

  /// A shoe that deals exactly [cards] in order (for tests and replays).
  Shoe.stacked(List<PlayingCard> cards)
      : decks = 0,
        _rng = Random(0),
        _stacked = true {
    _cards.addAll(cards);
  }

  final int decks;
  final Random _rng;
  final _cards = <PlayingCard>[];
  var _next = 0;
  var _stacked = false;

  int get remaining => _cards.length - _next;

  /// True once the cut card has come out; shuffle before the next round.
  bool get needsShuffle => !_stacked && _next >= _cards.length * .75;

  void shuffle() {
    _cards
      ..clear()
      ..addAll([
        for (var d = 0; d < decks; d++)
          for (final s in Suit.values)
            for (var r = 1; r <= 13; r++) PlayingCard(r, s),
      ])
      ..shuffle(_rng);
    _next = 0;
  }

  PlayingCard draw() {
    if (_next >= _cards.length) {
      if (_stacked) throw StateError('Stacked shoe ran out');
      shuffle();
    }
    return _cards[_next++];
  }
}

/// Best total of [cards]: Aces count 11 while that doesn't bust.
({int total, bool soft}) handTotal(List<PlayingCard> cards) {
  var total = 0;
  var aces = 0;
  for (final c in cards) {
    total += c.value;
    if (c.isAce) aces++;
  }
  final soft = aces > 0 && total + 10 <= 21;
  return (total: soft ? total + 10 : total, soft: soft);
}

enum Outcome { blackjack, win, push, lose, bust }

class BjHand {
  BjHand(this.bet, {this.fromSplit = false, this.splitAces = false});

  final cards = <PlayingCard>[];
  double bet;
  final bool fromSplit;
  final bool splitAces;
  bool doubled = false;
  bool stood = false;
  Outcome? outcome;

  /// What the hand paid back at settlement (stake included).
  double returned = 0;

  int get total => handTotal(cards).total;
  bool get soft => handTotal(cards).soft;
  bool get bust => total > 21;
  bool get blackjack => !fromSplit && cards.length == 2 && total == 21;

  /// No more decisions for this hand.
  bool get done => stood || bust || total == 21 || doubled || (splitAces && cards.length >= 2);
}

enum Phase { betting, insurance, player, dealer, settled }

class BlackjackRound {
  BlackjackRound(this.shoe, {this.maxHands = 4});

  final Shoe shoe;
  final int maxHands;

  Phase phase = Phase.betting;
  final hands = <BjHand>[];
  final dealer = <PlayingCard>[];
  int active = 0;
  bool holeRevealed = false;
  double insuranceBet = 0;
  double insuranceReturned = 0;

  BjHand get hand => hands[active];
  int get dealerTotal => handTotal(holeRevealed ? dealer : dealer.take(1).toList()).total;
  bool get dealerBlackjack => dealer.length == 2 && handTotal(dealer).total == 21;
  PlayingCard? get upCard => dealer.isEmpty ? null : dealer.first;

  /// Total staked this round (hands + insurance).
  double get staked => hands.fold<double>(0, (a, h) => a + h.bet) + insuranceBet;

  /// Total paid back at settlement (stakes included).
  double get returned => hands.fold<double>(0, (a, h) => a + h.returned) + insuranceReturned;

  /// Deal two cards each (player, dealer up, player, dealer hole).
  void deal(double bet) {
    assert(phase == Phase.betting && bet > 0);
    hands
      ..clear()
      ..add(BjHand(bet));
    dealer.clear();
    hand.cards.add(shoe.draw());
    dealer.add(shoe.draw());
    hand.cards.add(shoe.draw());
    dealer.add(shoe.draw());
    if (upCard!.isAce) {
      phase = Phase.insurance;
    } else {
      _peek();
    }
  }

  /// Answer the insurance offer (costs half the bet; pays 2 to 1).
  void insurance(bool take) {
    assert(phase == Phase.insurance);
    if (take) insuranceBet = hands.first.bet / 2;
    _peek();
  }

  /// Dealer checks for blackjack under an Ace or a ten.
  void _peek() {
    final up = upCard!;
    if ((up.isAce || up.value == 10) && dealerBlackjack) {
      _settle();
    } else if (hands.first.blackjack) {
      _settle();
    } else {
      phase = Phase.player;
      _advance();
    }
  }

  bool get canHit => phase == Phase.player && !hand.done;
  bool get canDouble => phase == Phase.player && hand.cards.length == 2 && !hand.done;
  bool get canSplit =>
      phase == Phase.player &&
      hand.cards.length == 2 &&
      hand.cards[0].value == hand.cards[1].value &&
      hands.length < maxHands &&
      !hand.splitAces;

  void hit() {
    assert(canHit);
    hand.cards.add(shoe.draw());
    _advance();
  }

  void stand() {
    assert(phase == Phase.player);
    hand.stood = true;
    _advance();
  }

  /// Double the bet, take exactly one more card.
  void doubleDown() {
    assert(canDouble);
    hand
      ..bet *= 2
      ..doubled = true
      ..cards.add(shoe.draw());
    _advance();
  }

  /// Split a pair into two hands, each with its own bet and a new second card.
  void split() {
    assert(canSplit);
    final h = hand;
    final aces = h.cards[0].isAce;
    final a = BjHand(h.bet, fromSplit: true, splitAces: aces)..cards.add(h.cards[0]);
    final b = BjHand(h.bet, fromSplit: true, splitAces: aces)..cards.add(h.cards[1]);
    a.cards.add(shoe.draw());
    b.cards.add(shoe.draw());
    hands
      ..removeAt(active)
      ..insertAll(active, [a, b]);
    _advance();
  }

  /// Move to the next hand that still needs a decision, or to the dealer.
  void _advance() {
    while (active < hands.length && hands[active].done) {
      active++;
    }
    if (active >= hands.length) {
      active = hands.length - 1;
      phase = Phase.dealer;
    }
  }

  /// One dealer action: reveal the hole card, then draw to 17. Returns false
  /// once the dealer is finished and the round has been settled.
  bool dealerStep() {
    assert(phase == Phase.dealer);
    if (!holeRevealed) {
      holeRevealed = true;
      return true;
    }
    // Nothing to play against: every hand bust.
    final live = hands.any((h) => !h.bust);
    if (live && handTotal(dealer).total < 17) {
      dealer.add(shoe.draw());
      return true;
    }
    _settle();
    return false;
  }

  void _settle() {
    holeRevealed = true;
    final d = handTotal(dealer).total;
    final dBj = dealerBlackjack;
    for (final h in hands) {
      if (h.bust) {
        h
          ..outcome = Outcome.bust
          ..returned = 0;
      } else if (h.blackjack && !dBj) {
        h
          ..outcome = Outcome.blackjack
          ..returned = h.bet * 2.5;
      } else if (dBj) {
        h
          ..outcome = h.blackjack ? Outcome.push : Outcome.lose
          ..returned = h.blackjack ? h.bet : 0;
      } else if (d > 21 || h.total > d) {
        h
          ..outcome = Outcome.win
          ..returned = h.bet * 2;
      } else if (h.total == d) {
        h
          ..outcome = Outcome.push
          ..returned = h.bet;
      } else {
        h
          ..outcome = Outcome.lose
          ..returned = 0;
      }
    }
    insuranceReturned = dBj ? insuranceBet * 3 : 0;
    phase = Phase.settled;
  }
}
