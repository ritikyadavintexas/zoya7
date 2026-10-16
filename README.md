# Zoya7 — app + Gold (Classic 777)

Flutter build of the Zoya7 design: the full app and the **Gold** slot, all in landscape.

**App pages:** splash, welcome, log in / sign up, forgot password (3 steps), lobby with live
jackpots, games (search + categories), coming soon (Mega Reels, Blackjack, Roulette, Plinko), promotions
with the 7-day streak, daily-bonus popup, slots-race leaderboard, wallet (buy / redeem / history),
checkout, purchase success, profile, edit profile (avatar frames), VIP club, notifications, settings,
chat (community + support, mute / report), legal (terms / privacy / sweeps rules) and no-connection.

**Game (landscape):** base game, Big / Super / Mega / Jackpot wins, paytable, in-game settings,
not-enough-coins and table chat.

**Blackjack:** a full table (`lib/games/blackjack/`): 6-deck shoe, blackjack pays 3 to 2, dealer
stands on all 17s and peeks under an Ace or ten, insurance 2 to 1, double (also after split), split
up to four hands (split Aces one card each). Bets in GC or SC from the app balances. Rules and
settlement live in `engine.dart` (no UI, unit-tested); `controller.dart` paces the deal and dealer;
`blackjack_game.dart` draws the table, cards and chips.

**Admin panel (Cash App style, portrait) — its own app.** Open `…/admin/` (e.g.
https://ritikyadavintexas.github.io/zoya7/admin/) and add it to the home screen: it installs as
**Z7 Admin**, separate from the game, upright, with its own green icon. Sign in once with your staff PIN;
the device stays signed in until *Lock*.

- *Phone* — the basics, in four tabs: **Today** (net cash, in/out, approvals, drawer), **Players**
  (search, create a player ID, profile with cash in/out), **Cash** (Cash App keypad: pick a player,
  type an amount, cash in or out; pending queue; history) and **Games** (on/off switches,
  maintenance mode). The avatar menu has *Database & install*.
- *Desktop* — everything: dashboard; players (bulk IDs, bonuses, adjustments, password reset,
  suspend / ban / delete); cash ledger, approvals and drawer shifts (starting amount → expected →
  counted); reports (starting / ending amount, cash in / out, per game, per player, by staff — CSV);
  games (live / off / hidden, featured, ribbons, bet limits); game math (slot RTP solver, reel
  stops, spin simulator, blackjack rules); settings (starting amount, rates, limits, database,
  clean start); staff & audit log.

**Players need a player ID.** There is no sign-up or guest play: the game's log-in takes the
player ID (or username) and password made in the admin panel, and the device remembers it. A
player who is suspended, banned or deleted is logged out on the spot.

**Shared database (temporary, free).** The game and the panel share one back office
(`lib/backoffice/casino.dart`). To share it between phones and computers, connect a Firebase
Realtime Database (`lib/backoffice/sync.dart`, plain REST — no SDK):

1. console.firebase.google.com → add a project → Build → Realtime Database → Create → *test mode*.
2. Copy its URL (`https://<project>-default-rtdb.firebaseio.com`).
3. Either paste it in the admin panel (Settings → Shared database → Connect) and open the
   *player / admin links* it shows on each device once, **or** add it as the repository variable
   `ZOYA7_DB_URL` (Settings → Secrets and variables → Actions → Variables) so every build
   connects by itself.

Devices sync every few seconds, record by record (players, ledger lines, play, games, settings),
so two devices changing different things never lose each other's work; balances are worked out
from the ledger, never stored. Offline changes are sent when the connection is back. Test-mode
databases are open to anyone with the URL and expire after 30 days — lock the rules before real
use. Without a database each device keeps its own copy (browser storage).

**Landscape everywhere.** The Android and iOS builds lock to landscape. Browsers can't lock
orientation, so when the window is taller than wide (phone held upright) the game draws itself
turned sideways (the admin panel stays upright) (`lib/app/landscape.dart`). Pages use a left side rail for navigation and a
side pane + main pane layout sized for a phone on its side.

App code lives in `lib/app/` (`screens/` one file per area, `state.dart` holds the prototype balances,
`nav.dart` the routes). Images from the design are in `assets/app/`.

## Run

```bash
flutter create . --platforms=android,ios --org com.zoya7   # generates android/ and ios/ only
flutter pub get
flutter run
```

`flutter create .` keeps the existing `lib/`, `assets/` and `test/`.

**iOS / iPad:** in Xcode → Runner → General, tick only *Landscape Left/Right* and
*Requires full screen* (iPad otherwise insists on supporting portrait).

## How it matches the design

The whole game is laid out on the design's **1920×1080 canvas** with the design's exact
pixel sizes, percentages, colors, gradients, shadows and SVG icons, then scaled to fit
the screen. On 4:3 iPads and tall phones the background glow fills the extra space.

All 28 images were exported 1:1 from the design into `assets/games/gold/`.

Motion added on top of the static design: scrolling reels with motion blur and a landing
bounce, press feedback on buttons, the win amount counting up, turning light rays and a
pop-in banner on celebrations, a sliding chat drawer.

## Structure

```
lib/games/gold/
  gold_game.dart          ← the one widget your app routes to
  src/math.dart           ← symbols, paytable rules, GoldOutcomeSource (plug your engine here)
  src/controller.dart     ← game state: spin/stop/auto, bets, GC/SC, panels, chat
  src/style.dart          ← design tokens + exact CSS→Flutter conversions
  src/widgets/            ← header, reels, side panels, footer, modals, chat, win overlay
```

## Connecting it to Zoya7

```dart
GoldGame(
  outcomes: MyServerMath(),                    // implements GoldOutcomeSource
  initialGc: wallet.gc, initialSc: wallet.sc,
  onExitToLobby: () => router.go('/lobby'),
  onBuyCoins: (cur) => router.go('/wallet'),
  onOpenPlayLimits: () => router.go('/settings/limits'),
)
```

- **Math:** `GoldOutcomeSource.spin()` returns the 3×3 grid, win, multiplier and jackpot. Reels keep
  spinning until it resolves, so a network call works. `LocalGoldMath` uses the reel weights set in the
  admin panel's *Game math* (95% / 94% RTP by default; the design prototype's were ≈22.8%).
- **Jackpots:** meter values are simulated in `GoldController.jackpots()`; feed live values from your server.
- **Chat:** the auto-reply is the design's demo; connect `chatSend` to your chat service.
- **Sound:** the design has no audio; implement `GoldAudio` (spin, reel stop, win, music).
- **Fonts:** Lilita One and Rubik load via `google_fonts`. For offline release builds, bundle the
  font files and set `GoogleFonts.config.allowRuntimeFetching = false`.

## Preview any design state

```dart
GoldGame(previewOverlay: WinTier.mega)
GoldGame(previewOverlay: WinTier.jackpot, currency: Currency.sc)
GoldGame(previewPanel: GoldPanel.paytable)   // .settings, .noCoins
```

## See it on your phone (every push)

`.github/workflows/preview.yml` builds on every push to `main`:

- **Any phone (iPhone too):** `https://<your-user>.github.io/<repo>/` — open in the browser,
  hold it sideways, and use *Add to Home Screen* for full screen.
- **Android app:** Releases → **preview** → `zoya7-preview.apk`.

The build id is shown bottom-left so you can confirm you're on the latest.
