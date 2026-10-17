import 'package:flutter/widgets.dart';

import '../games/gold/src/math.dart' show Currency;
import 'nav.dart';
import 'sound.dart';

import '../backoffice/auth.dart';
import '../backoffice/casino.dart';
import '../backoffice/sync.dart';

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
/// coin packs and the games on offer come from the back office
/// ([Casino]), which the admin panel manages. Players can only log in with a
/// player ID made in the admin panel (a Firebase sign-in, through [sync]);
/// this device remembers who logged in.
class AppState extends ChangeNotifier {
  /// Without a [casino] (tests, previews) the demo account is logged in.
  AppState({Casino? casino, String? playerId, this.sync})
      : casino = casino ?? Casino.demo(),
        playerId = casino == null ? Casino.meId : playerId {
    this.casino.addListener(_casinoChanged);
    sync?.addListener(_syncChanged);
  }

  bool _ready = false;

  /// The database answering for the first time decides whether the account
  /// this device remembers still exists.
  void _syncChanged() {
    final ready = sync!.ready;
    if (ready == _ready) return;
    _ready = ready;
    _casinoChanged();
  }

  final Casino casino;
  final CasinoSync? sync;

  /// Logged-in player ID (null: logged out).
  String? playerId;

  Player? get player => playerId == null ? null : casino.player(playerId!);
  bool get signedIn => playerId != null;

  /// Signed in, waiting for the account to arrive from the database.
  bool get loading => playerId != null && player == null && !(sync?.ready ?? true);

  /// Set when the back office closes or removes this account while it plays.
  String? kickedOut;

  void _casinoChanged() {
    final p = player;
    if (loading) {
      notifyListeners();
      return;
    }
    if (playerId != null && (p == null || p.status != PlayerStatus.active)) {
      kickedOut = p == null ? 'This player ID no longer exists' : Casino.blocked(p);
      signOut();
      return;
    }
    notifyListeners();
  }

  /// Log in with a player ID (or username) and password; returns an error to
  /// show, or null.
  Future<String?> logIn(String who, String password) async {
    final s = sync, auth = s?.auth;
    if (who.trim().isEmpty) return 'Enter your player ID or username';
    if (password.isEmpty) return 'Enter your password';
    if (s == null || auth == null) return 'Can’t reach the server — check the connection';
    try {
      final email = await s.loginEmail(who);
      if (email == null) return 'No player with that ID. Ask your cashier for one.';
      final AuthSession session;
      try {
        session = await auth.signIn(email, password);
      } on AuthError catch (e) {
        return e.message == 'Wrong username or password' ? 'Wrong password' : e.message;
      }
      final id = await s.playerOf(session);
      if (id == null) return 'This password was reset — ask your cashier for the new one';
      await s.usePlayer(session, id);
      final p = casino.player(id);
      final blocked = p == null ? 'Can’t load your account — try again' : Casino.blocked(p);
      if (blocked != null) {
        s.signOut();
        return blocked;
      }
      playerId = id;
      kickedOut = null;
      casino.touchSeen(id);
      notifyListeners();
      return null;
    } catch (e) {
      return '$e';
    }
  }

  void signOut() {
    playerId = null;
    sync?.signOut();
    notifyListeners();
  }

  double get gc => player?.gc ?? 0;
  double get sc => player?.sc ?? 0;

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
    Sound.instance.play(Sounds.coins);
  }

  void selectPack(int i) {
    selectedPack = i;
    notifyListeners();
  }

  /// Coin packs can't be bought in the app yet (no payments are connected):
  /// a player signed in to the shared database is told to ask the cashier.
  bool get storeOpen => sync?.auth == null;

  /// Credits [p] (plus [bonusGc] from a promo code).
  void completePurchase(CoinPack p, {int bonusGc = 0}) {
    final me = player;
    if (me == null || !storeOpen) return;
    casino.purchase(me,
        gc: (p.gc + bonusGc).toDouble(), sc: p.sc.toDouble(), note: '${p.gcLabel} GC package');
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

  void toggleSetting(String key) => setSetting(key, !(settings[key] ?? false));

  void setSetting(String key, bool on) {
    settings[key] = on;
    if (key == 'sound' || key == 'music') {
      Sound.instance.configure(sfx: settings['sound'] ?? false, music: settings['music'] ?? false);
    }
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
