import 'package:flutter/foundation.dart';

import '../gold/src/math.dart' show Currency;
import '../gold/src/style.dart' show curLabel, fmtAmount;
import 'engine.dart';

/// Where the table takes bets from and pays winnings to.
abstract class BlackjackWallet {
  double balance(Currency c);
  void add(Currency c, double amount);
}

/// Drives a [BlackjackRound] for the table UI: bets and chips, the wallet,
/// and the pacing of the deal and the dealer's draws.
class BlackjackController extends ChangeNotifier {
  BlackjackController({
    required this.wallet,
    Shoe? shoe,
    this.pace = const Duration(milliseconds: 520),
  }) : shoe = shoe ?? Shoe() {
    round = BlackjackRound(this.shoe);
  }

  final BlackjackWallet wallet;
  final Shoe shoe;

  /// Time between dealer cards (and the base for deal animations).
  final Duration pace;

  late BlackjackRound round;
  Currency currency = Currency.gc;

  /// Chips on the betting circle before the deal.
  double bet = 0;
  double lastBet = 0;

  /// An animation or the dealer is playing; buttons wait.
  bool busy = false;
  bool shuffling = false;

  /// Bumped on each deal so the cards animate in afresh.
  int dealSerial = 0;

  /// A short note for the player (bet limits, balance).
  String? note;

  static const _chips = {
    Currency.gc: [500.0, 1000.0, 5000.0, 25000.0],
    Currency.sc: [0.5, 1.0, 5.0, 25.0],
  };
  List<double> get chips => _chips[currency]!;
  double get minBet => chips.first;
  double get maxBet => currency == Currency.gc ? 250000 : 250;
  double get balance => wallet.balance(currency);

  Phase get phase => round.phase;
  bool get betting => phase == Phase.betting;

  bool get canDeal => betting && !busy && bet >= minBet && bet <= balance;
  bool get canHit => !busy && round.canHit;
  bool get canStand => !busy && phase == Phase.player;
  bool get canDouble => !busy && round.canDouble && balance >= round.hand.bet;
  bool get canSplit => !busy && round.canSplit && balance >= round.hand.bet;

  /// Cost of insurance on the current hand.
  double get insuranceCost => round.hands.isEmpty ? 0 : round.hands.first.bet / 2;
  bool get canInsure => phase == Phase.insurance && balance >= insuranceCost;

  /// Net result of the settled round (winnings minus everything staked).
  double get net => round.returned - round.staked;

  Future<void> _wait([double times = 1]) =>
      Future.delayed(Duration(milliseconds: (pace.inMilliseconds * times).round()));

  void setCurrency(Currency c) {
    if (!betting || busy || c == currency) return;
    currency = c;
    bet = 0;
    lastBet = 0;
    note = null;
    notifyListeners();
  }

  void addChip(double v) {
    if (!betting || busy) return;
    final next = bet + v;
    if (next > balance) {
      note = 'Not enough coins for that chip';
    } else if (next > maxBet) {
      note = 'Table limit is ${fmtAmount(maxBet, currency)} ${curLabel(currency)}';
    } else {
      bet = next;
      note = null;
    }
    notifyListeners();
  }

  void clearBet() {
    if (!betting || busy) return;
    bet = 0;
    note = null;
    notifyListeners();
  }

  void rebet() {
    if (!betting || busy || lastBet == 0) return;
    bet = lastBet <= balance ? lastBet : 0;
    note = bet == 0 ? 'Not enough coins to repeat the last bet' : null;
    notifyListeners();
  }

  Future<void> deal() async {
    if (!canDeal) return;
    busy = true;
    note = null;
    if (shoe.needsShuffle) {
      shuffling = true;
      notifyListeners();
      await _wait(1.6);
      shoe.shuffle();
      shuffling = false;
    }
    wallet.add(currency, -bet);
    lastBet = bet;
    round = BlackjackRound(shoe)..deal(bet);
    dealSerial++;
    notifyListeners();
    // Let the four cards fly in.
    await _wait(1.6);
    busy = false;
    if (phase == Phase.settled) _payout();
    notifyListeners();
  }

  void insurance(bool take) {
    if (phase != Phase.insurance || busy) return;
    final buy = take && canInsure;
    if (buy) wallet.add(currency, -insuranceCost);
    round.insurance(buy);
    _afterAction();
  }

  void hit() {
    if (!canHit) return;
    round.hit();
    _afterAction();
  }

  void stand() {
    if (!canStand) return;
    round.stand();
    _afterAction();
  }

  void doubleDown() {
    if (!canDouble) return;
    wallet.add(currency, -round.hand.bet);
    round.doubleDown();
    _afterAction();
  }

  void split() {
    if (!canSplit) return;
    wallet.add(currency, -round.hand.bet);
    round.split();
    _afterAction();
  }

  void _afterAction() {
    notifyListeners();
    if (phase == Phase.dealer) {
      _runDealer();
    } else if (phase == Phase.settled) {
      _payout();
      notifyListeners();
    }
  }

  Future<void> _runDealer() async {
    busy = true;
    notifyListeners();
    await _wait(.8);
    while (round.dealerStep()) {
      notifyListeners();
      await _wait();
    }
    _payout();
    busy = false;
    notifyListeners();
  }

  void _payout() {
    if (round.returned > 0) wallet.add(currency, round.returned);
  }

  /// Back to betting, keeping the last bet on the circle when affordable.
  void newRound() {
    if (phase != Phase.settled || busy) return;
    round = BlackjackRound(shoe);
    bet = lastBet <= balance ? lastBet : 0;
    notifyListeners();
  }

  Future<void> playAgain() async {
    newRound();
    await deal();
  }
}
