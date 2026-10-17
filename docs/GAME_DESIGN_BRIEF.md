# Zoya7 — game design brief

Copy everything below the line into your design tool (or hand it to a designer), fill in the
`[BRACKETS]`, and send me the finished folder (zip it and upload it in chat, or put it in the repo at
`design/<game-id>/`). I'll embed it in the app, work out the math, and add it to the lobby and the
admin panel.

---

## Brief: design a game for Zoya7

Zoya7 is a social casino app played **in landscape** on phones, tablets and computers. It uses two
virtual coins with **no cash value**: Gold Coins (GC) and DC. Design one complete game:
**[GAME NAME]**, theme **[THEME, e.g. "Egyptian gold", "neon fruit", "pirate treasure"]**, mood
**[MOOD, e.g. bright and fun / dark and luxurious]**.

Deliver everything in one folder named `[game-id]` (lowercase, no spaces, e.g. `pharaoh-gold`), laid
out exactly as below. Every image is PNG with a **transparent background** unless it says otherwise,
drawn at the sizes given (these are 2× the on-screen size, so they stay sharp on phones).

### 1. Pick the game type

**Type A: reel slot (fastest; fits the engine Zoya7 already has)**
- 3 reels × 3 rows, one payline across the middle row.
- Exactly **11 symbols**, in these roles (keep the roles; the theme and art are up to you):

| Role | Pays | Example in Classic 777 | Your symbol |
|---|---|---|---|
| Mega jackpot | 3 on the line wins the MEGA jackpot | 7 | [ ] |
| Major jackpot | 3 → MAJOR jackpot | diamond | [ ] |
| Minor jackpot | 3 → MINOR jackpot | crown | [ ] |
| Mini jackpot | 3 → MINI jackpot | BAR | [ ] |
| Top symbol | 3 → 30× bet | star | [ ] |
| High 2 | 3 → 20× bet | bell | [ ] |
| High 3 | 3 → 15× bet | watermelon | [ ] |
| Mid 1 | 3 → 10× bet | plum | [ ] |
| Mid 2 | 3 → 8× bet | orange | [ ] |
| Low 1 | 3 → 6× bet | lemon | [ ] |
| Low 2 (also pays for any 2) | 3 → 5×, any 2 → 2× | cherry | [ ] |

**Type B: new kind of game** (more reels or paylines, free spins, a wheel, crash, plinko, roulette,
cards…). Describe the rules completely in `rules.md`: what the player bets, every way to win, what
each win pays, and any bonus feature, step by step, with examples. I'll build the game logic and
the math from that.

### 2. Folder layout

```
[game-id]/
  game.json            the facts (see section 4)
  rules.md             how to play, every pay, every feature (Type B: in full detail)
  mockups/             full-screen pictures of each state (section 5), 2560×1080, JPG or PNG
  lobby/
    card.png           lobby tile, 460×356, no text on it, NOT transparent
    banner.png         featured banner, 880×472, title text allowed, NOT transparent
  table/
    background.png     whole-screen backdrop, 2560×1080, NOT transparent
    frame.png          reel/table frame, 1400×792 (Type A: three reel windows, see section 3)
    logo.png           game title art, up to 900×300
  symbols/             Type A: 11 files, one per symbol, each 330×330, named by role:
    mega.png  major.png  minor.png  mini.png  top.png  high2.png  high3.png
    mid1.png  mid2.png  low1.png  low2.png
  wins/
    big.png  super.png  mega.png  jackpot.png      win banners, 770×474
  buttons/             optional — leave out to use Zoya7's standard buttons
    spin.png 660×296   stop.png 680×276   auto.png 486×274   max_bet.png 426×276
  jackpots/            optional plaques for the four jackpot meters, 486×352 each
    mega.png  major.png  minor.png  mini.png
  sounds/              optional, short .mp3 or .ogg: spin, reel_stop, win_small, win_big, jackpot
```

### 3. Art rules

- **Landscape 2560×1080** is the full screen; keep anything important inside the middle
  **1920×1080** (narrower phones crop the sides).
- The screen is laid out like this: **top strip** (back button, settings, four jackpot meters,
  GC and DC balances); **middle** (a panel on the left, the reels or table in the centre, a
  pay panel on the right); **bottom strip** (bet −/+, max bet, auto, win display, a big SPIN
  button). Design around these; you can restyle every piece.
- **Type A frame:** three reel windows side by side. Leave each window empty and fully
  transparent so the symbols show through. Windows start 25% from the top and are 57% of the
  frame's height; across the frame they sit at left 11.1%, 37.8% and 64.3%, each about 24.6% wide.
  Leave room in the centre for the payline.
- **Symbols:** centred, filling about 85% of the square, readable at small sizes, with a soft
  outline or shadow so they stand out on the reel. The four jackpot symbols should look the most
  special.
- Keep text out of the art (titles and numbers are drawn by the app), except `banner.png` and
  `logo.png`.
- Use **"DC"** and **"GC"** for the coins. Never show "$", money, "cash", "redeem" or prizes.

### 4. game.json

```json
{
  "id": "[game-id]",
  "name": "[Game Name]",
  "type": "reel-slot-3x3",
  "category": "SLOTS",
  "theme": "[one line]",
  "colors": { "background": "#0E4A20", "accent": "#FFD45A", "text": "#FFF4D6" },
  "symbols": {
    "mega": "Golden scarab", "major": "Eye of Ra", "minor": "Ankh", "mini": "Scroll",
    "top": "Pharaoh", "high2": "Cat", "high3": "Pyramid",
    "mid1": "Lotus", "mid2": "Vase", "low1": "Beetle", "low2": "Coin"
  },
  "target_rtp": 0.95,
  "feel": "steady",
  "notes": "[anything else]"
}
```

- `type`: `reel-slot-3x3` for Type A; for Type B, a short name like `slot-5x3-20-lines` or `crash`.
- `target_rtp`: the share of all bets paid back over time, between **0.90 and 0.96**. It's
  the same for every player and every spin, and it can be changed later in the admin panel.
- `feel`: `steady` (small wins often), `balanced`, or `swingy` (rare, big wins).

### 5. Mockups to include

1. The game at rest with a bet set.
2. Mid-spin.
3. A small line win (winning symbols highlighted).
4. Big win, super win and mega win banners.
5. A jackpot win.
6. The paytable screen.
7. (Type B) every bonus or feature screen.

### 6. Checklist before sending

- [ ] Folder named `[game-id]`, every file named exactly as in section 2.
- [ ] Transparent PNGs where required; sizes as listed.
- [ ] 11 symbols (Type A) or complete `rules.md` (Type B).
- [ ] `game.json` filled in.
- [ ] Mockups of every state.
- [ ] No money, "$", "cash", "redeem" or prize wording anywhere.

---

## What I do with it (for you, not the designer)

1. Put the art in `assets/games/<game-id>/` and make the game: for Type A, a new look on the
   existing 3×3 engine (like Fruit Spin); for Type B, new game logic with tests.
2. **Math:** set the reel strips (or the rules' odds) so the game pays back `target_rtp` with
   the chosen `feel`, include the jackpots in that figure, check it by simulating millions of
   rounds, and show the breakdown (each pay's share, hit rate, jackpot odds) in the admin
   panel's **Game math** page. The odds are the same for every player.
3. Add it to the lobby, the admin **Games** page (on/off, featured, bet limits) and the reports.
