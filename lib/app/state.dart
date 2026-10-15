import 'package:flutter/widgets.dart';

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

/// Prototype session state shared by every page. Replace with your backend.
class AppState extends ChangeNotifier {
  double gc = 125000;
  double sc = 250.50;
  double redeemableSc = 180;
  String name = 'Player123';
  bool guest = false;

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

  void signIn({bool asGuest = false}) {
    guest = asGuest;
    notifyListeners();
  }

  void claimBonus() {
    if (bonusClaimed) return;
    bonusClaimed = true;
    gc += todayBonus;
    notifyListeners();
  }

  void selectPack(int i) {
    selectedPack = i;
    notifyListeners();
  }

  /// Credits [p] (plus [bonusGc] from a promo code) and returns the pack.
  void completePurchase(CoinPack p, {int bonusGc = 0}) {
    gc += p.gc + bonusGc;
    sc += p.sc;
    notifyListeners();
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

  void setGc(double v) {
    gc = v;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing to changes (for callbacks).
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
