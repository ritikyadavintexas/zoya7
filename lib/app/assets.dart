/// Images exported from the design canvas into assets/app/.
class A {
  static const _d = 'assets/app';
  static const logo = '$_d/logo.webp';
  static const welcomeHero = '$_d/welcome_hero.webp';
  static const avatar = '$_d/avatar.webp';
  static const vipBanner = '$_d/vip_banner.webp';
  static const classic777 = '$_d/game_classic777.webp';
  static const fruitSpin = '$_d/game_fruitspin.webp';
  static const phoenixRuby = '$_d/game_phoenixruby.webp';
  static const megaReels = '$_d/game_megareels.webp';
  static const blackjack = '$_d/game_blackjack.webp';
  static const roulette = '$_d/game_roulette.webp';
  static const plinko = '$_d/game_plinko.webp';

  /// Lobby: tall game-card art (no text) and the daily-bonus icon.
  static String card(String gameId) => '$_d/card_$gameId.webp';
  static const dailyBonusIcon = '$_d/icon_daily_bonus.webp';

  static const all = [
    logo, welcomeHero, avatar, vipBanner, classic777, fruitSpin, phoenixRuby, megaReels, blackjack, roulette, plinko, //
    dailyBonusIcon, '$_d/card_classic777.webp', '$_d/card_fruitspin.webp', '$_d/card_phoenixruby.webp', '$_d/card_megareels.webp',
    '$_d/card_blackjack.webp', '$_d/card_roulette.webp', '$_d/card_plinko.webp',
  ];
}

/// A game tile in the lobby and on the Games page.
class GameInfo {
  const GameInfo({
    required this.id,
    required this.name,
    required this.cat,
    required this.image,
    this.playable = false,
    this.players = '',
    this.category = '',
    this.blurb = '',
    this.tags = const [],
  });
  final String id;
  final String name;

  /// Filter category: SLOTS, TABLE or INSTANT.
  final String cat;
  final String image;
  final bool playable;
  final String players;

  // Coming-soon page copy.
  final String category;
  final String blurb;
  final List<String> tags;
}

const games = [
  GameInfo(id: 'classic777', name: 'Classic 777', cat: 'SLOTS', image: A.classic777, playable: true, players: '1.2k'),
  GameInfo(id: 'phoenixruby', name: 'Phoenix Ruby', cat: 'SLOTS', image: A.phoenixRuby, playable: true, players: '930'),
  GameInfo(
    id: 'blackjack',
    name: 'Blackjack',
    cat: 'TABLE',
    image: A.blackjack,
    playable: true,
    players: '642',
    category: 'TABLE GAME',
    blurb: 'Classic 21 against the dealer with split, double and side bets.',
    tags: ['Split & double', 'Side bets', 'Live table chat'],
  ),
  GameInfo(
    id: 'roulette',
    name: 'Roulette',
    cat: 'TABLE',
    image: A.roulette,
    category: 'TABLE GAME',
    blurb: 'Spin the golden wheel — bet on numbers, colors and columns.',
    tags: ['Inside & outside bets', 'Hot numbers', 'Racetrack'],
  ),
  GameInfo(id: 'fruitspin', name: 'Fruit Spin', cat: 'SLOTS', image: A.fruitSpin, playable: true, players: '864'),
  GameInfo(
    id: 'plinko',
    name: 'Plinko',
    cat: 'INSTANT',
    image: A.plinko,
    category: 'INSTANT WIN',
    blurb: 'Drop the ruby ball and watch it bounce to a multiplier.',
    tags: ['Instant results', 'Risk levels', 'Auto drop'],
  ),
  GameInfo(
    id: 'megareels',
    name: 'Mega Reels',
    cat: 'SLOTS',
    image: A.megaReels,
    category: 'SLOTS · 5 REELS',
    blurb: 'Gem-packed 5-reel slots with expanding wilds and a free-spins bonus round.',
    tags: ['Free spins', 'Wilds', 'Jackpot eligible'],
  ),
];

GameInfo gameById(String id) => games.firstWhere((g) => g.id == id, orElse: () => games.firstWhere((g) => !g.playable));
