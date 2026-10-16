import 'package:flutter/widgets.dart';

import '../games/gold/src/math.dart' show Currency;
import 'nav.dart';

import '../backoffice/casino.dart';
import '../backoffice/storage.dart';

/// A Gold Coin package from the Wallet's BUY COINS grid.
class CoinPack {
  const CoinPack(this.gc, this.gcLabel, this.sc, this.price, [this.tag]);
  final int gc;
  final String gcLabel;
  final int sc;
  final double price;
  final String? tag;

  String get priceLabel => '\$${price.toStringAsFixed(2)}';
}

const coinPacks = [
  CoinPack(10000, '10K', 1, 1.99),
  CoinPack(50000, '50K', 5, 4.99),
  CoinPack(120000, '120K', 10, 9.99, 'POPULAR'),
  CoinPack(300000, '300K', 25, 24.99),
  CoinPack(650000, '650K', 50, 49.99, 'BEST VALUE'),
  CoinPack(1400000, '1.4M', 100, 99.99),
];

/// Session state shared by every page. Who's playing, their balances,
/// purchases, redemptions and the games on offer come from the back office
/// ([Casino]), which the admin panel manages. Players can only log in with a
/// player ID made in the admin panel; this device remembers who logged in.
class AppState extends ChangeNotifier {
  /// Without a [casino] (tests, previews) the demo account is logged in.
  AppState({Casino? casino, String? playerId})
      : casino = casino ?? Casino.demo(),
        playerId = casino == null ? Casino.meId : playerId {
    this.casino.addListener(_casinoChanged);
    if (this.playerId != null && player == null) this.playerId = null;
  }

  static const _playerKey = 'zoya7.player';

  /// The player this device remembers, if any.
  static String? rememberedPlayer() => loadSaved(_playerKey);

  final Casino casino;

  /// Logged-in player ID (null: logged out).
  String? playerId;

  Player? get player => playerId == null ? null : casino.player(playerId!);
  bool get signedIn => player != null;

  /// Set when the back office closes or removes this account while it plays.
  String? kickedOut;

  void _casinoChanged() {
    final p = player;
    if (playerId != null && (p == null || p.status != PlayerStatus.active)) {
      kickedOut = p == null
          ? 'This player ID no longer exists'
          : p.status == PlayerStatus.banned
              ? 'This account is closed'
              : 'This account is on hold — talk to your cashier';
      signOut();
      return;
    }
    notifyListeners();
  }

  /// Log in with a player ID (or username) and password; returns an error to
  /// show, or null.
  String? logIn(String who, String password) {
    try {
      final p = casino.login(who, password);
      playerId = p.id;
      kickedOut = null;
      save(_playerKey, p.id);
      notifyListeners();
      return null;
    } on CasinoError catch (e) {
      return e.message;
    }
  }

  void signOut() {
    playerId = null;
    clearSaved(_playerKey);
    notifyListeners();
  }

  double get gc => player?.gc ?? 0;
  double get sc => player?.sc ?? 0;

  double get redeemableSc => sc;
  String get name => player?.name ?? 'Player';

  /// Daily-bonus streak: today is day 4 of 7.
  final int streakDay = 4;
  final List<int> streakAmounts = const [1000, 2000, 3000, 5000, 7000, 10000, 25000];
  bool bonusClaimed = false;

  int avatarFrame = 0;

  /// Player level and progress to the next one (0–1).
  int level = 12;
  double levelProgress = .62;

  /// VIP rewards waiting to be collected (shown on the lobby's VIP icon).
  int vipRewards = 2;
  bool notificationsRead = false;
  final Set<String> notifyAtLaunch = {};
  final Map<String, bool> settings = {
    'sound': true,
    'music': true,
    'vibe': false,
    'fast': false,
    'push': true,
    'bonus': true,
    'mentions': true,
    'reminder': true,
  };

  int selectedPack = 2;
  CoinPack get pack => coinPacks[selectedPack];

  int get todayBonus => streakAmounts[streakDay - 1];
  int get unreadNotifications => notificationsRead ? 0 : 2;

  void claimBonus() {
    final p = player;
    if (bonusClaimed || !casino.settings.dailyBonus || p == null) return;
    bonusClaimed = true;
    casino.credit(p, gc: todayBonus.toDouble(), note: 'Daily bonus');
  }

  void selectPack(int i) {
    selectedPack = i;
    notifyListeners();
  }

  /// Credits [p] (plus [bonusGc] from a promo code) and returns the pack.
  void completePurchase(CoinPack p, {int bonusGc = 0}) {
    final me = player;
    if (me == null) return;
    casino.purchase(me, p.price,
        gc: (p.gc + bonusGc).toDouble(), sc: p.sc.toDouble(), note: '${p.gcLabel} GC package');
  }

  /// Ask for a payout of [amount] SC; returns an error to show, or null.
  String? requestRedemption(double amount, String method) {
    final me = player;
    if (me == null) return 'Log in first';
    try {
      casino.cashOut(me, amount, method: method);
      return null;
    } on CasinoError catch (e) {
      return e.message;
    }
  }

  void setAvatarFrame(int i) {
    avatarFrame = i;
    notifyListeners();
  }

  void markAllRead() {
    notificationsRead = true;
    notifyListeners();
  }

  void toggleNotify(String game) {
    notifyAtLaunch.contains(game) ? notifyAtLaunch.remove(game) : notifyAtLaunch.add(game);
    notifyListeners();
  }

  void toggleSetting(String key) {
    settings[key] = !(settings[key] ?? false);
    notifyListeners();
  }

  /// Book finished play for the logged-in player (balances follow).
  void recordRound(String gameId, Currency c, double staked, double returned) {
    final id = playerId;
    if (id != null) casino.recordRound(gameId, id, c, staked, returned);
  }

  @override
  void dispose() {
    casino.removeListener(_casinoChanged);
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing to changes (for callbacks).
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// Log the player out and go back to the welcome screen.
void logOut(BuildContext context) {
  AppScope.read(context).signOut();
  Nav.reset(R.welcome);
}
