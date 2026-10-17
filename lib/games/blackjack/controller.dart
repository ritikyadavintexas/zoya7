import 'dart:async';

import 'package:flutter/foundation.dart';

import '../gold/src/math.dart' show Currency;
import '../gold/src/style.dart' show curLabel, fmtAmount;
import 'engine.dart';

/// The table's sounds, by moment.
enum BjSound { chip, card, shuffle, win, blackjack, lose, push }

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
    this.rules = const BjRules(),
    this.limits = defaultLimits,
    this.onSettled,
    this.onSound,
    this.gcAllowed = true,
    this.pace = const Duration(milliseconds: 520),
  }) : shoe = shoe ?? Shoe(decks: rules.decks) {
    round = BlackjackRound(this.shoe, rules: rules);
  }

  final BlackjackWallet wallet;
  final Shoe shoe;
  final BjRules rules;

  /// Table limits (min, max bet) per currency.
  final Map<Currency, (double, double)> limits;
  static const defaultLimits = {Currency.gc: (500.0, 250000.0), Currency.sc: (.5, 250.0)};

  /// Called once per settled round with what was staked and paid back.
  final void Function(Currency currency, double staked, double returned)? onSettled;

  /// Asked to play a sound at each moment of the round.
  final void Function(BjSound sound)? onSound;

  void _sound(BjSound s) => onSound?.call(s);

  /// Time between dealer cards (and the base for deal animations).
  final Duration pace;

  late BlackjackRound round;

  /// Gold Coins switched off by the owner: the table plays in DC only.
  final bool gcAllowed;
  late Currency currency = gcAllowed ? Currency.gc : Currency.sc;

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
  List<double> get chips {
    final all = _chips[currency]!;
    final fit = all.where((c) => c <= maxBet).toList();
    return fit.isEmpty ? [all.first] : fit;
  }

  double get minBet => limits[currency]?.$1 ?? defaultLimits[currency]!.$1;
  double get maxBet => limits[currency]?.$2 ?? defaultLimits[currency]!.$2;
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
    if (!betting || busy || c == currency || (c == Currency.gc && !gcAllowed)) return;
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
      _sound(BjSound.chip);
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
    if (bet > 0) _sound(BjSound.chip);
    notifyListeners();
  }

  Future<void> deal() async {
    if (!canDeal) return;
    busy = true;
    note = null;
    if (shoe.needsShuffle) {
      shuffling = true;
      _sound(BjSound.shuffle);
      notifyListeners();
      await _wait(1.6);
      shoe.shuffle();
      shuffling = false;
    }
    wallet.add(currency, -bet);
    lastBet = bet;
    round = BlackjackRound(shoe, rules: rules)..deal(bet);
    dealSerial++;
    // One for each card as it flies in (they leave the shoe 200 ms apart).
    _sound(BjSound.card);
    if (onSound != null) {
      for (var i = 1; i < 4; i++) {
        Timer(Duration(milliseconds: 200 * i), () => _sound(BjSound.card));
      }
    }
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
    if (buy) {
      wallet.add(currency, -insuranceCost);
      _sound(BjSound.chip);
    }
    round.insurance(buy);
    _afterAction();
  }

  void hit() {
    if (!canHit) return;
    round.hit();
    _sound(BjSound.card);
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
    _sound(BjSound.chip);
    _sound(BjSound.card);
    _afterAction();
  }

  void split() {
    if (!canSplit) return;
    wallet.add(currency, -round.hand.bet);
    round.split();
    _sound(BjSound.card);
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
      _sound(BjSound.card);
      notifyListeners();
      await _wait();
    }
    _payout();
    busy = false;
    notifyListeners();
  }

  void _payout() {
    if (round.returned > 0) wallet.add(currency, round.returned);
    onSettled?.call(currency, round.staked, round.returned);
    _sound(round.hands.any((h) => h.outcome == Outcome.blackjack)
        ? BjSound.blackjack
        : net > 0
            ? BjSound.win
            : net == 0
                ? BjSound.push
                : BjSound.lose);
  }

  /// Back to betting, keeping the last bet on the circle when affordable.
  void newRound() {
    if (phase != Phase.settled || busy) return;
    round = BlackjackRound(shoe, rules: rules);
    bet = lastBet <= balance ? lastBet : 0;
    notifyListeners();
  }

  Future<void> playAgain() async {
    newRound();
    await deal();
  }
}
