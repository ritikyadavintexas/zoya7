# Zoya7 — the game prompt (for GPT)

How to use it:

1. Copy **everything below the line** into GPT (ChatGPT with file output works best) and say
   **“CREATE A NEW GAME”**. Ask for changes until you love it.
2. Download the zip it gives you.
3. Admin panel → **Games** → **Upload a game** → choose the zip. The panel checks it; if anything is
   wrong, press **Copy for GPT**, paste that to GPT and upload the fixed zip.
4. Press **Publish to the lobby** (the first time it asks for a GitHub token and saves it; the key
   icon in the uploader's corner changes or removes it). The site rebuilds and
   the game switches on in the lobby by itself in about 5 minutes. Its payback is set in
   **Game math** (95% to start); the game only says what each result pays.

To replace a game, upload a new zip with the same `id`. To take one away, **Remove game** on its card.

---

# MASTER PROMPT — ZOYA7 GAME STUDIO

## Your mission

You are an elite independent game studio in one: creative director, gameplay inventor, visual
artist, animator, sound designer and HTML5 Canvas engineer. **Invent a genuinely new game,
make it extraordinarily beautiful and satisfying, and deliver it complete and playable**, as one
folder that drops straight into the Zoya7 app.

Zoya7 is a social casino app played in **landscape** on phones, tablets and computers, with two
virtual coins that have **no cash value: Gold Coins (GC) and DC**. Your game is one of its games:
the app holds the player's coins and decides each round's result; your game makes that round a
wonderful thing to watch and play.

Every time you're asked, invent something different. Not a reskin: a different core interaction,
visual composition, motion, progression, sound identity and art direction. Games already in Zoya7,
so don't repeat them: **Classic 777, Fruit Spin, Phoenix Ruby** (3-reel slots), **Blackjack**,
and soon **Roulette, Plinko, Mega Reels** (5-reel slot). [Add your own uploaded games here.]

Before building, imagine several fundamentally different ideas, judge them on originality,
beauty, clarity, satisfaction, replayability and feasibility, and pick the strongest, not the
most complicated. Then build it, play it, and polish the weakest parts until it feels
professionally finished.

Inspiration (not a checklist): physical machines and mechanisms, gravity and chain reactions,
creatures and characters, light and colour, transformations and reveals, beautiful worlds, toys,
rituals, nature, space, music. Any art style that suits the idea; not everything is gold.

## The one hard rule: Zoya7 decides every result

Each round, your game calls `Zoya7.play(...)`. Zoya7 takes the bet, draws the result from your pay
table, pays any win, and answers with **which outcome happened**. Your game then shows exactly that
outcome. So:

- **It's a game of chance, presented beautifully.** The player chooses the bet and starts the
  round, and may make choices that are part of the show (which lantern, which door), but **nothing
  the player does changes the result**: no aiming, timing, steering, reflexes or puzzles that
  decide what's paid. Never suggest otherwise (no “aim carefully”, no score that looks earned).
- **Show exactly the outcome Zoya7 sends, every time.** Each outcome in your pay table has its
  own clear, unmistakable end state. Decorative details may vary; the result never does.
- **Honest presentation.** Don't stage near-misses on purpose, don't fake “almost won the top
  prize” moments, don't flash or celebrate a loss as if it were a win. Celebrate in proportion to
  what was won.
- **Don't invent odds, RTP, jackpot pools or prize funds.** You only say what each result pays,
  as a multiple of the bet. Zoya7 sets how often each one comes.

## What you deliver

One zip containing one folder, named with the game's id:

```
lanterns/                      the folder name = the id in game.json
  index.html                   loads zoya7-bridge.js first, then the game's scripts
  game.json                    the facts and the pay table (below)
  zoya7-bridge.js              copied exactly from the end of this prompt
  src/                         the game's JavaScript (plain scripts or ES modules)
  assets/                      images (PNG, WebP, JPG or SVG), fonts (WOFF2)
  sounds/                      MP3 (plays everywhere, including iPhone), short and small
  lobby/icon.png               512 × 512, square, the game's logo (no text needed)
  lobby/tile.png               880 × 472, the lobby tile: key art with the game's name
  README.md                    how it plays, in a few lines
```

`mockups/`, `docs/`, `tools/` and `tests/` may be included but are ignored. Up to 600 files,
80 MB in all, 20 MB per file (aim for under 15 MB in all: phones download it).

## game.json

```json
{
  "zoya7": 1,
  "id": "lanterns",
  "name": "Lantern Drift",
  "category": "INSTANT",
  "description": "Release a paper lantern over the night lake and see which star it reaches.",
  "credits": "Art, code and sound: original, made for Zoya7.",
  "options": [
    {
      "id": "main",
      "label": "Release",
      "outcomes": [
        { "id": "drift",  "label": "Drifts away",  "multiplier": 0 },
        { "id": "rose",   "label": "Rose star",    "multiplier": 2 },
        { "id": "sea",    "label": "Sea star",     "multiplier": 5 },
        { "id": "gold",   "label": "Golden star",  "multiplier": 30 },
        { "id": "moon",   "label": "The Moon",     "multiplier": 250 }
      ]
    }
  ]
}
```

| Field | Rules |
|---|---|
| `zoya7` | Always `1`. |
| `id` | 3–24 lowercase letters and digits, starting with a letter. No spaces, hyphens or underscores. Not `classic777`, `fruitspin`, `phoenixruby`, `blackjack`, `roulette`, `plinko` or `megareels`. |
| `name` | 1–18 characters, as players see it. |
| `category` | `SLOTS`, `TABLE` or `INSTANT`. |
| `description` | One sentence, up to 160 characters. |
| `credits` | Who made the art and sound, and that it's original (or its licence). |
| `options` | 1–6 kinds of bet. Most games have one, `"main"`. Use more only when the player picks between genuinely different bets (e.g. a calm path and a daring path), each with its own pay table. |
| `outcomes` | 2–40 per option, each with a unique `id` (lowercase letters, digits, `_` or `-`), a short `label` players see in the info panel, and a `multiplier`: what it pays × the bet. |

**Pay table rules** (the uploader refuses anything else):

- Any multipliers you like (`1.5`, `2`, `25`, `30`, `777`…), from 0.1 up to 5000, and **at least one
  outcome with `"multiplier": 0`** (no win). Several no-win outcomes are fine if they look
  different (the lantern drifts left, or right).
- How Zoya7 sets the chances (so you can design the feel): every win pays back an equal share
  of the payback, so a 30× comes 15 times less often than a 2×, and the rest of the time the
  round is a no-win. Optional `"share": 2` on an outcome makes it pay back twice its share (comes
  twice as often). Examples at 95%: `[0, 2, 5, 30]` → wins in 23% of rounds; `[0, 1.2, 2, 5]` →
  49%; `[0, 2, 4, 8, 20, 100, 500]` → 15%; `[0, 10, 100, 1000]` → 3.5%. Lots of small multipliers
  feel lively; a few big ones feel dramatic.
- The wins must be able to pay back 99% without winning almost every round: avoid pay tables made
  mostly of multipliers near 1×.
- Your info panel shows each outcome's label, multiplier and chance from the session (below), so
  players can see what can happen and how likely it is.

## The bridge: how the game talks to Zoya7

Copy `zoya7-bridge.js` from the end of this prompt into the folder **exactly as it is**, and load
it before your own scripts:

```html
<script src="zoya7-bridge.js"></script>
<script src="src/game.js"></script>
```

It gives you `window.Zoya7`:

```js
const session = await Zoya7.init();      // once, at start-up
// session = {
//   demo,                  // true when the game runs on its own (pretend coins)
//   currency: 'GC',        // the starting currency; 'GC' or 'DC'
//   currencies: ['GC', 'DC'],  // the ones switched on (Zoya7 may switch GC off: then ['DC'])
//   balances: {GC, DC},    // the player's coins
//   bets: {GC: [...], DC: [...]},   // the only bets allowed, smallest first
//   bet: {GC, DC},         // the bet to start with
//   options: [{id, label, outcomes: [{id, label, multiplier, chance}]}],
//   rtp, sound: {effects, music}, player: {name}, reducedMotion
// }

Zoya7.ready();                           // after the first frame is drawn (lifts Zoya7's loading screen)

const round = await Zoya7.play({ option: 'main', currency: 'GC', bet: 500 });
// round = { round, option, outcome: 'gold', label, multiplier: 30, currency, bet, win: 15000,
//           balances: {GC, DC} }        // balances after the bet and the win
// It rejects with an Error whose .code is:
//   'balance' (not enough coins) · 'bet' (not an allowed bet) · 'option' · 'currency'
//   'closed' (the game was switched off) · 'signedout' · 'busy' · 'timeout' (connection)

Zoya7.exit();                            // back to the Zoya7 lobby
Zoya7.buyCoins();                        // the Gold Coin store (GC only, never DC)
Zoya7.on('balance', b => {...});         // coins changed outside the game: {GC, DC}
Zoya7.on('sound', s => {...});           // the player's settings changed: {effects, music}
Zoya7.on('pause', () => {...});          // the app went to the background: pause motion and sound
Zoya7.on('resume', () => {...});
```

Opened on its own from a local web server (`python3 -m http.server` in the folder, then
`http://localhost:8000`), the bridge runs a demo with pretend coins, bets and the same payout rule,
so you can build and test everything without Zoya7.

**A round, step by step:**

1. The player has picked a bet from `session.bets[currency]` and starts the round (the PLAY button,
   or your game's own way of starting: release, drop, pull…). Ignore input that would start
   another round until this one is finished.
2. Call `Zoya7.play(...)` right away. While waiting (usually instant, up to a few seconds on a slow
   connection), start the motion: it's only a lead-in.
3. When the answer comes, steer the animation to the end state of `round.outcome`. Show the
   balance as before the round minus the bet while it plays, then add `round.win` as the result
   is revealed. Afterwards use `round.balances`.
4. If it rejects: `balance` → say “Not enough GC/DC” (for GC, offer **Get coins** →
   `Zoya7.buyCoins()`); `bet` → reset to an allowed bet; `closed` or `signedout` → explain and offer
   the way back to the lobby; `timeout` → “Connection lost, try again”. Never show a result Zoya7
   didn't send.

## Screen and controls

- **Landscape only.** Draw on one full-window canvas with a fixed **1920 × 1080 logical stage**,
  scaled to fit (scale = min(width / 1920, height / 1080)) and centred; paint the background beyond
  the stage so there are no black bars on wide phones or 4:3 iPads. Use `devicePixelRatio` for
  sharp drawing, redraw on resize, and map pointer positions back to stage coordinates.
- Touch, mouse and keyboard (Space or Enter starts a round; Escape goes back).
- Smooth 60 fps with `requestAnimationFrame` and time-based (delta) motion. Respect
  `session.reducedMotion`.
- **The platform bar**, the same in every Zoya7 game (style it to suit your game):
  - Top left: a **back** button (arrow) that calls `Zoya7.exit()`. Keep that corner clear.
  - Top right: the **GC** and **DC** balances (GC as whole numbers with separators, DC with two
    decimals), a switch between playing with GC or DC, and a **+** next to GC only, calling
    `Zoya7.buyCoins()`. DC never has a +. Show only the currencies in `session.currencies`: when
    it's `['DC']`, GC appears nowhere (no balance, no switch, no +).
  - A **bet** selector stepping through `session.bets[currency]`.
  - A **sound** button (mute effects and music) and an **info** button: how to play, and the pay
    table (each outcome's label, multiplier and chance as “1 in N”).
  - The win of the last round.
- Nothing else that isn't needed. No fake jackpot meters, no timers, no pop-up offers.

## Sound

Give the game its own sound identity: interactions, motion, impacts, reveals, wins scaled to their
size, a gentle no-win, and a looping ambience or music track. Use Web Audio; start it on the
player's first tap (browsers block sound before that). Follow `session.sound` and the `sound`
event (effects and music separately), the game's own mute button, and `pause`/`resume`. Never
loud or harsh; nothing that piles up when played repeatedly.

## Art

Original, beautiful, coherent, made for this game: background, game pieces, effects, UI. Layered,
separate files (not one flattened picture), each named for what it is. Numbers, balances and
amounts are always drawn by code, never baked into images. `lobby/icon.png` (512 × 512, square) and
`lobby/tile.png` (880 × 472; key art with the game's name; keep the top-right corner plain, Zoya7
puts a small NEW/HOT tag there).

## Technical rules (the uploader checks these)

- Plain HTML, CSS and JavaScript. No build step, frameworks or libraries.
- **Everything the game needs is in its folder.** Nothing from the internet: no CDNs, web fonts
  from Google, analytics, `fetch` to other sites, WebSockets or iframes. All paths relative
  (`assets/bg.png`, never `/assets/bg.png` or `https://…`).
- Zoya7 runs the game in a sandbox: no `localStorage`, cookies, `alert()`, pop-ups or new windows.
  Keep state in memory.
- Use `Zoya7.init`, `Zoya7.play` and `Zoya7.exit` (the uploader looks for them), and `Zoya7.ready`.
- Words: the coins are **GC** and **DC**. Never “$”, cash, money, dollars, redeem, withdraw or
  “real money”.

## Before you deliver

Play it in demo mode and check:

- [ ] It starts, calls `Zoya7.ready()`, and plays round after round without breaking.
- [ ] Every outcome in game.json can be shown and looks clearly different (while testing, a
      temporary key in your own code that replays the reveal of each outcome id; remove it after).
- [ ] The balance, bet steps, GC/DC switch, + (GC only), back, sound and info all work.
- [ ] Not enough coins, a lost connection and a switched-off game are handled.
- [ ] It fits and looks right at 2560 × 1080, 1920 × 1080, 1366 × 1024 and 844 × 390.
- [ ] No outside URLs; zoya7-bridge.js is unchanged; the folder name equals the id.

Then give me: the zip, a short description of the game and how a round plays, and the pay table.

## zoya7-bridge.js

Copy this file exactly:

```js
/*
 * Zoya7 game bridge, v1. Load it before the game's own scripts:
 *
 *     <script src="zoya7-bridge.js"></script>
 *
 * Inside the Zoya7 app it talks to the app, which holds the player's coins and
 * draws the result of every round. Opened on its own (from any local web
 * server) it runs a demo with pretend coins and the same payout rule, so the
 * game can be built and tested anywhere. Zoya7 puts its own copy of this file
 * in the game when it is uploaded: don't change it, build on its API.
 *
 *   Zoya7.init()                  -> Promise<session>   call once, first
 *   Zoya7.play({option, currency, bet}) -> Promise<round>  one round; the app decides it
 *   Zoya7.ready()                 the first frame is drawn (the app drops its loading cover)
 *   Zoya7.exit()                  back to the Zoya7 lobby
 *   Zoya7.buyCoins()              the Gold Coin store (GC only; never for DC)
 *   Zoya7.on(event, fn)           'balance' {GC, DC} · 'sound' {effects, music} · 'pause' · 'resume'
 */
(function () {
  'use strict';
  var VERSION = 1;
  var RTP = 0.95;
  var listeners = {};
  var pending = {};
  var seq = 0;
  var mode = null; // 'host' (in Zoya7) or 'demo'
  var session = null;
  var initPromise = null;
  var demo = null;

  // Zoya7 runs games in a sandbox without storage; an in-memory one keeps a game that uses it working.
  function memoryStorage() {
    var d = {};
    return {
      getItem: function (k) { return Object.prototype.hasOwnProperty.call(d, k) ? d[k] : null; },
      setItem: function (k, v) { d[k] = String(v); },
      removeItem: function (k) { delete d[k]; },
      clear: function () { d = {}; },
      key: function (i) { return Object.keys(d)[i] || null; },
      get length() { return Object.keys(d).length; }
    };
  }
  ['localStorage', 'sessionStorage'].forEach(function (name) {
    try { window[name].getItem('zoya7'); } catch (e) {
      try { Object.defineProperty(window, name, { value: memoryStorage(), configurable: true }); } catch (e2) { /* left as is */ }
    }
  });

  function fail(code, message) {
    var e = new Error(message || code);
    e.code = code;
    return e;
  }

  function emit(type, data) {
    (listeners[type] || []).slice().forEach(function (fn) {
      try { fn(data); } catch (e) { console.error(e); }
    });
  }

  window.addEventListener('message', function (e) {
    var m = e.data;
    if (e.source !== window.parent || !m || m.zoya7 !== VERSION) return;
    if (m.re != null && pending[m.re]) {
      var p = pending[m.re];
      delete pending[m.re];
      if (m.error) p.reject(fail(m.error.code, m.error.message));
      else p.resolve(m.data);
    } else if (m.event) {
      if (m.event === 'balance' && session) session.balances = m.data;
      if (m.event === 'sound' && session) session.sound = m.data;
      emit(m.event, m.data);
    }
  });

  document.addEventListener('visibilitychange', function () { emit(document.hidden ? 'pause' : 'resume', {}); });

  function ask(type, data, timeoutMs) {
    return new Promise(function (resolve, reject) {
      var id = ++seq;
      pending[id] = { resolve: resolve, reject: reject };
      window.parent.postMessage({ zoya7: VERSION, id: id, type: type, data: data || {} }, '*');
      if (timeoutMs) {
        setTimeout(function () {
          if (!pending[id]) return;
          delete pending[id];
          reject(fail('timeout', 'Zoya7 did not answer'));
        }, timeoutMs);
      }
    });
  }

  function tell(type) {
    if (mode === 'host') window.parent.postMessage({ zoya7: VERSION, type: type, data: {} }, '*');
  }

  // ── The payout rule (the same in the app) ──────────────────────────────────
  // Every win gets its share of the payback (equal unless the game sets
  // "share"), so a 30x win comes 15 times less often than a 2x win; the rest
  // of the time the round is a no-win.
  function chances(outcomes, rtp) {
    var wins = outcomes.filter(function (o) { return o.multiplier > 0; });
    var losses = outcomes.length - wins.length;
    if (!wins.length || !losses) return null;
    var shares = wins.reduce(function (a, o) { return a + o.share; }, 0);
    var hit = 0;
    var p = outcomes.map(function (o) {
      if (o.multiplier <= 0) return 0;
      var x = rtp * (o.share / shares) / o.multiplier;
      hit += x;
      return x;
    });
    if (hit > 0.95) return null;
    return p.map(function (x, i) { return outcomes[i].multiplier > 0 ? x : (1 - hit) / losses; });
  }

  function money(currency, v) {
    return currency === 'GC' ? Math.round(v) : Math.round(v * 100) / 100;
  }

  // ── Demo: the game opened on its own ───────────────────────────────────────
  function startDemo() {
    return fetch('game.json', { cache: 'no-store' })
      .then(function (r) { return r.json(); })
      .catch(function () { throw fail('demo', 'Open the game from a local web server (e.g. python3 -m http.server) so it can read game.json'); })
      .then(function (g) {
        var options = (g.options || []).map(function (o) {
          var outs = (o.outcomes || []).map(function (x) {
            return { id: x.id, label: x.label || x.id, multiplier: +x.multiplier || 0, share: x.share == null ? 1 : +x.share };
          });
          var p = chances(outs, RTP);
          if (!p) throw fail('paytable', 'Option "' + o.id + '": needs a 0x outcome and wins big enough to pay back 95%');
          return {
            id: o.id,
            label: o.label || o.id,
            outcomes: outs.map(function (x, i) { return { id: x.id, label: x.label, multiplier: x.multiplier, chance: p[i] }; })
          };
        });
        if (!options.length) throw fail('paytable', 'game.json has no options');
        demo = { balances: { GC: 100000, DC: 100 }, round: 0, last: 0 };
        mode = 'demo';
        return {
          demo: true,
          currency: 'GC',
          balances: { GC: demo.balances.GC, DC: demo.balances.DC },
          bets: { GC: [100, 200, 500, 1000, 2000, 5000, 10000], DC: [0.2, 0.5, 1, 2, 5, 10] },
          bet: { GC: 100, DC: 0.2 },
          options: options,
          rtp: RTP,
          sound: { effects: true, music: true },
          player: { name: 'Demo player' },
          reducedMotion: !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches)
        };
      });
  }

  function demoPlay(req) {
    var option = session.options.filter(function (o) { return o.id === req.option; })[0];
    if (!option) return Promise.reject(fail('option', 'No bet option "' + req.option + '"'));
    if (session.bets[req.currency] == null) return Promise.reject(fail('currency', 'Currency is GC or DC'));
    if (session.bets[req.currency].indexOf(req.bet) < 0) return Promise.reject(fail('bet', 'Bet is one of session.bets'));
    if (demo.balances[req.currency] < req.bet) return Promise.reject(fail('balance', 'Not enough coins'));
    var r = Math.random();
    var pick = option.outcomes[option.outcomes.length - 1];
    for (var i = 0; i < option.outcomes.length; i++) {
      r -= option.outcomes[i].chance;
      if (r < 0) { pick = option.outcomes[i]; break; }
    }
    var win = money(req.currency, req.bet * pick.multiplier);
    demo.balances[req.currency] = money(req.currency, demo.balances[req.currency] - req.bet + win);
    return Promise.resolve({
      round: 'demo-' + (++demo.round),
      option: option.id,
      outcome: pick.id,
      label: pick.label,
      multiplier: pick.multiplier,
      currency: req.currency,
      bet: req.bet,
      win: win,
      balances: { GC: demo.balances.GC, DC: demo.balances.DC }
    });
  }

  window.Zoya7 = {
    version: VERSION,

    /** The session: balances, bet steps, pay tables (with each outcome's chance), sound settings. */
    init: function () {
      if (initPromise) return initPromise;
      var framed = window.parent !== window;
      var start = framed
        ? ask('init', { bridge: VERSION }, 2500).then(function (s) { mode = 'host'; return s; }, startDemo)
        : startDemo();
      initPromise = start.then(function (s) { session = s; return s; });
      return initPromise;
    },

    /**
     * Plays one round: the bet is taken, the result drawn and any win paid, all at once.
     * Resolves with {round, option, outcome, label, multiplier, currency, bet, win, balances};
     * rejects with an Error whose .code is 'balance', 'bet', 'option', 'currency', 'closed',
     * 'signedout', 'busy' or 'timeout'. Show exactly this outcome; never another.
     */
    play: function (req) {
      if (!session) return Promise.reject(fail('init', 'Call Zoya7.init() first'));
      req = req || {};
      var r = { option: req.option || session.options[0].id, currency: req.currency || session.currency, bet: +req.bet };
      var p = mode === 'host' ? ask('play', r, 15000) : demoPlay(r);
      return p.then(function (round) { session.balances = round.balances; return round; });
    },

    ready: function () { tell('ready'); },

    exit: function () {
      if (mode === 'host') tell('exit');
      else if (window.history.length > 1) window.history.back();
    },

    buyCoins: function () { tell('buy'); },

    on: function (type, fn) { (listeners[type] = listeners[type] || []).push(fn); },

    off: function (type, fn) { listeners[type] = (listeners[type] || []).filter(function (f) { return f !== fn; }); },

    get session() { return session; },
    get demo() { return mode === 'demo'; }
  };
})();
```
