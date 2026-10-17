# Zoya7 — GAME.md: how to deliver a game

> **A completely new game (made with GPT)?** Use [GAME_PROMPT.md](GAME_PROMPT.md) instead and upload
> the zip from the admin panel (Games → Upload a game). This document is for a new look on the
> built-in 3-reel slot.

Hand everything below the line to whoever (or whatever tool) designs the game. When the finished
folder comes back, zip it and drop the zip in chat. If it follows this document exactly, it goes
into the app in one step: art, sounds, math, lobby, admin panel and reports.

Everything in **bold** is a hard rule. Anything marked *optional* can be left out; Zoya7's standard
version is used instead.

---

## Brief: design a game for Zoya7

Zoya7 is a social casino app, played **in landscape** on phones, tablets and computers. It uses two
virtual coins, **Gold Coins (GC) and DC, with no cash value**. Design one complete game:

- **Name:** [GAME NAME] — at most 14 characters, so it fits the lobby tiles.
- **Theme:** [THEME, e.g. "Egyptian gold", "neon fruit", "pirate treasure"].
- **Mood:** [MOOD, e.g. bright and fun / dark and luxurious / calm and mystical].

### 1. The game: a 3-reel slot

The game runs on Zoya7's slot engine. The rules are fixed; only the look and the sound are yours.

- 3 reels × 3 rows, **one payline across the middle row**.
- **Exactly 11 symbols**, one per role below. The roles and what they pay can't change; what each
  symbol looks like is up to you.

| Role (file name) | Three on the payline pays | In Classic 777 | In Phoenix Ruby |
|---|---|---|---|
| `mega` | the MEGA jackpot | 7 | 7 |
| `major` | the MAJOR jackpot | diamond | phoenix |
| `minor` | the MINOR jackpot | crown | crown |
| `mini` | the MINI jackpot | BAR | coin |
| `top` | 30 × bet | star | ruby |
| `high2` | 20 × bet | bell | sun |
| `high3` | 15 × bet | watermelon | star |
| `mid1` | 10 × bet | plum | lotus |
| `mid2` | 8 × bet | orange | feather |
| `low1` | 6 × bet | lemon | amber gem |
| `low2` | 5 × bet, **and any 2 of it on the line pay 2 × bet** | cherry | amethyst |

The four jackpot symbols must look the most special. `low2` lands most often; make it friendly
and easy to spot.

**Payback (RTP):** set by Zoya7, **between 90% and 96%** (95% unless you say otherwise in
`game.json`). It's the share of all bets the game pays back over time, the same for every player
and every spin, and the owner can change it later in the admin panel. Don't design odds, free
spins, multipliers or extra features; the engine doesn't have them. (For a different kind of game,
see section 9.)

### 2. Deliver one folder

Name the folder with the game's id: **lowercase letters and digits only, no spaces or
hyphens** (e.g. `pharaohgold`). Lay it out exactly like this, with exactly these file names:

```
pharaohgold/
  game.json                 the facts about the game (section 7)        required
  lobby/
    tile.png                880 × 472, the Games page tile              required
    card.png                460 × 356, the lobby card                   required
  table/
    frame.png               2320 × 1312, the reel frame                 required
    background.png          2560 × 1440, the backdrop                   optional
  symbols/
    mega.png  major.png  minor.png  mini.png
    top.png   high2.png  high3.png
    mid1.png  mid2.png   low1.png   low2.png    330 × 330 each          required (all 11)
  sounds/
    music.wav               background music loop                       required
    spin.wav  reel_stop.wav  win_small.wav  win_big.wav  jackpot.wav    required
    button.wav  collect.wav                                             optional
  buttons/                                                              optional (all or none)
    spin.png 760 × 340   stop.png 680 × 276   auto.png 486 × 274   max_bet.png 426 × 276
  jackpots/                                                             optional (all or none)
    mega.png 486 × 352   major.png 464 × 350   minor.png 432 × 318   mini.png 410 × 308
  wins/                                                                 optional (all or none)
    big.png 1540 × 948   super.png 1572 × 928   mega.png 1280 × 980   jackpot.png 1364 × 988
  mockups/                  pictures of the finished game (section 8)   recommended
```

**No other files, no extra folders, no layered or source files** (PSD, Figma, AI): they're left
out. Sizes are in pixels and must match **exactly**; they're 2× the size the art is shown at, so
it stays sharp on phones.

### 3. Image rules (all images)

- **PNG, sRGB colour.** Transparent background (alpha) for everything **except** `tile.png`,
  `card.png` and `background.png`, which must be fully opaque.
- Transparent means truly transparent: no white or black box, no checkerboard drawn into the
  picture.
- **No text in the art**, except: the game name on `tile.png`; the words on the buttons
  (SPIN, STOP, AUTO, MAX BET); the jackpot names on the plaques (MEGA, MAJOR, MINOR, MINI);
  the words on the win banners (BIG WIN, SUPER WIN, MEGA WIN, JACKPOT). Numbers, balances and
  amounts are always drawn by the app.
- Coins are called **"GC"** and **"DC"**. **Never show "$", "cash", "money", "redeem", "prize",
  "withdraw" or real-world currency** anywhere.
- Original work only, or art you hold a commercial licence for (say which in `game.json`).

### 4. The screen and each piece of art

The game screen is a 1920 × 1080 layout that widens to 2560 on long phones:

```
┌──────────────────────────────────────────────────────────────────────────┐
│ ← back  ⚙        MEGA   MAJOR   MINOR   MINI            GC balance  [+]  │  top strip
│                  (four jackpot plaques)                 DC balance  [+]  │
│ ┌─────────┐   ┌──────────────────────────────────┐   ┌─────────┐         │
│ │ jackpot │   │      ┌──────┐┌──────┐┌──────┐    │   │  line   │         │
│ │ combos  │   │      │reel 1││reel 2││reel 3│    │   │  pays   │         │  middle
│ │         │   │ ─────│──────││──────││──────│──  │   │         │         │
│ │         │   │      └──────┘└──────┘└──────┘    │   │         │         │
│ └─────────┘   └──────────────── frame ───────────┘   └─────────┘         │
│ [− BET +]   [MAX BET]  [AUTO]   [ WIN ......... ]          [  SPIN  ]    │  bottom strip
└──────────────────────────────────────────────────────────────────────────┘
```

**`table/frame.png` (2320 × 1312), required.** The ornate frame around the reels. It has three
**reel windows**, and **each window must be completely transparent** (alpha 0) so the spinning
symbols show through. Use these window positions, in pixels from the top-left corner of the image:

| Window | x | y | width | height |
|---|---|---|---|---|
| Reel 1 | 258 | 328 | 570 | 752 |
| Reel 2 | 877 | 328 | 566 | 752 |
| Reel 3 | 1492 | 328 | 572 | 752 |

If your frame needs different windows, that's fine: list the three rectangles in `game.json` as
`reel_windows` (same pixel units). The payline is drawn by the app across the middle of the
windows, from the left edge of reel 1 to the right edge of reel 3; leave the dividers between
windows thin there. Everything outside the windows can be as decorative as you like. Keep the
outer edge of the frame inside the image; nothing should be cut off at the border.

**`symbols/*.png` (330 × 330 each), required.** One symbol per file, centred, filling about 85%
of the square (about 280 px), on a transparent background. A soft shadow or outline helps it read
on the reel. Each symbol is shown in a reel cell about 190 × 250 px (on a 2× screen) and as small
as 76 px in the pay tables, so it must stay clear at small sizes: bold shapes, no fine text.

**`table/background.png` (2560 × 1440), optional.** The backdrop behind everything. Phones crop
the top and bottom and tablets crop the sides, so keep anything important inside the centre
**1920 × 1080**, and keep it calm and darker in the middle where the reels sit. Without it, the
app paints a radial glow from `colors.background` in `game.json`.

**`lobby/tile.png` (880 × 472), required.** The tile on the Games page and in the lobby rows.
The game name in big, readable lettering is welcome here (it must read at 180 px wide). The app
rounds the corners and puts a small HOT / NEW tag in the **top-right corner (keep the right 25%
of the top 25% free of anything important)**.

**`lobby/card.png` (460 × 356), required.** The tall card in the lobby. **No text.** The app
zooms into it, so keep the subject in the **centre 60%** of the picture.

**`buttons/` (optional; give all four or none).** SPIN 760 × 340, STOP 680 × 276 (shown in
place of SPIN while the reels turn), AUTO 486 × 274, MAX BET 426 × 276. The whole picture is the
button, so crop tight; the word is part of the art.

**`jackpots/` (optional; all four or none).** The plaques for the four jackpot meters along the
top: MEGA 486 × 352, MAJOR 464 × 350, MINOR 432 × 318, MINI 410 × 308. Put the jackpot's name in
the top half. **The app writes the live amount in the band from 62% to 92% of the height, 9% in
from each side**: keep that band a plain, dark panel.

**`wins/` (optional; all four or none).** The banners shown over the reels for a big win
(10× the bet and up), super win (20×), mega win (30×) and a jackpot: BIG 1540 × 948, SUPER
1572 × 928, MEGA 1280 × 980, JACKPOT 1364 × 988. The app shows the amount won and a COLLECT
button underneath the banner, so the bottom edge of the banner should be clean.

### 5. Sound rules

Every game has its own music and sounds. **Deliver WAV files: 44.1 kHz or 48 kHz, 16- or
24-bit, mono or stereo.** (MP3 or OGG only if WAV is impossible.) Zoya7 converts them for phones
and the web.

| File | When it plays | Length | Notes |
|---|---|---|---|
| `music.wav` | all the time while the game is open | 20–40 s | **A seamless loop** (rules below) |
| `spin.wav` | SPIN is pressed; the reels start | 1.0–1.4 s | Energy that rises, then fades by the time the reels land |
| `reel_stop.wav` | each reel lands (three times per spin) | 0.15–0.4 s | Short, punchy, **sound starts at 0 ms**. The app raises the pitch slightly for reels 2 and 3 |
| `win_small.wav` | a line win under 10× the bet | 0.8–1.5 s | Cheerful, not too loud: it plays often |
| `win_big.wav` | big, super or mega win | 2.5–4 s | A celebration. The music dips while it plays |
| `jackpot.wav` | any of the four jackpots | 4–6 s | The biggest moment in the game |
| `button.wav` | *optional:* bet −/+, MAX BET, AUTO | under 0.15 s | Without it, Zoya7's standard click |
| `collect.wav` | *optional:* COLLECT after a big win | 0.8–1.5 s | Coins pouring. Without it, Zoya7's standard coins |

**The music loop.**
- Pick a tempo and write a whole number of bars: e.g. 16 bars of 4/4 at 100 BPM =
  16 × 4 × 60 / 100 = **38.4 s exactly**. Put `bpm`, `bars` and `loop_seconds` in `game.json`.
- The file is **exactly one loop long**, to the sample: no silence at the start, no fade-in or
  fade-out at either end. The end must flow straight back into the start. Let reverb tails from
  the last bar continue at the start (render the loop twice and keep the second copy).
- It plays for a long time, so keep it pleasant: steady, not too busy, no sudden loud hits, no
  vocals.
- It plays under everything else, so mix it about 6 dB quieter than the sound effects.

**All sounds.** Trim silence from the start (sound within 10 ms). Peak at **−1 dBFS**, never
clipped. Effects should feel like one family, matching the theme (e.g. wooden knocks and marimba
for a tropical game, taiko and gongs for an eastern one). No voices saying words.

### 6. Colours

Pick three colours for the backdrop glow, from the centre out: a warm, lighter centre colour, a
mid colour and a near-black edge, e.g. `["#8A2A12", "#3D0B12", "#120408"]`. They're used behind
the game even when `background.png` is given (they show at the edges on unusual screen shapes).

### 7. `game.json`

```json
{
  "id": "pharaohgold",
  "name": "Pharaoh Gold",
  "type": "reel-slot-3x3",
  "category": "SLOTS",
  "badge": "NEW",
  "colors": { "background": ["#8A5A12", "#3D2410", "#120A04"] },
  "symbols": {
    "mega": "Golden scarab", "major": "Eye of Ra", "minor": "Ankh", "mini": "Scroll",
    "top": "Pharaoh", "high2": "Cat", "high3": "Pyramid",
    "mid1": "Lotus", "mid2": "Vase", "low1": "Beetle", "low2": "Coin"
  },
  "reel_windows": null,
  "music": { "bpm": 100, "bars": 16, "loop_seconds": 38.4 },
  "target_rtp": 0.95,
  "credits": "Art: [who]. Sound: [who]. All original, or licensed for commercial use: [licence]."
}
```

| Field | Rules |
|---|---|
| `id` | Same as the folder name. Lowercase letters and digits only. |
| `name` | As shown to players; at most 14 characters. |
| `type` | `reel-slot-3x3` (section 9 for anything else). |
| `category` | `SLOTS`. |
| `badge` | `NEW`, `HOT` or `null`. |
| `colors.background` | Three hex colours, centre to edge (section 6). |
| `symbols` | A name for each of the 11 roles (used in the paytable and for accessibility). |
| `reel_windows` | `null` for the standard windows, or `[[x, y, w, h], [x, y, w, h], [x, y, w, h]]` in `frame.png` pixels. |
| `music` | Tempo, number of bars and exact loop length of `music.wav` in seconds. |
| `target_rtp` | 0.90 to 0.96. |
| `credits` | Who made the art and sound, and the licence. |

### 8. Mockups (recommended)

Full-screen pictures (2560 × 1080, PNG or JPG) of: the game at rest with a bet set; mid-spin; a
small line win; the big win banner; the jackpot banner. They're only a reference, used to check
the result; nothing in them is used directly.

### 9. A different kind of game

Anything that isn't a 3-reel, one-line slot (5 reels, more lines, free spins, blackjack, roulette,
plinko, crash, a wheel…) is new game logic. Building it takes real work, not one step, but the
delivery is just as strict:

- `type`: a short name, e.g. `slot-5x3-20-lines`, `crash`, `wheel`.
- `rules.md`: the complete rules. What the player bets (and the bet limits); every way to win and
  exactly what it pays; every feature step by step, with three worked examples (a loss, a small
  win, a feature or big win); anything random and how likely it is. Leave out RTP and odds
  tables: Zoya7 sets those.
- Every piece of art as its own transparent PNG at 2× size, named for what it is (cards,
  chips, table, wheel segments, buttons…), plus the same `lobby/`, `colors` and `credits` as
  above. **Never flattened mockups only.**
- `sounds/`: `music.wav` (looping, same rules) plus one WAV per event, named for the event
  (e.g. `card_deal.wav`, `chip.wav`, `wheel_tick.wav`, `win.wav`), and a list in `rules.md` of
  when each one plays.
- Mockups of every screen and state, including every feature and the paytable or rules screen.

### 10. Checklist before sending

- [ ] Folder named with the id (lowercase letters and digits), zipped.
- [ ] `game.json` complete; `id` matches the folder; `target_rtp` between 0.90 and 0.96.
- [ ] Exactly 11 symbols named by role, 330 × 330, transparent.
- [ ] `frame.png` 2320 × 1312 with three fully transparent reel windows in the right places.
- [ ] `tile.png` 880 × 472 and `card.png` 460 × 356, opaque; nothing important under the tag.
- [ ] Optional sets complete or left out entirely (`buttons/`, `jackpots/`, `wins/`).
- [ ] All six required sounds as WAV; `music.wav` is exactly `loop_seconds` long and loops
  seamlessly.
- [ ] No "$", cash, money, redeem, prize or withdraw wording anywhere; coins are GC and DC.
- [ ] Every image and sound is original or licensed for commercial use, listed in `credits`.

### Mistakes we've seen

- 9 symbols instead of 11 (every role needs its own symbol).
- An RTP outside 90–96% (80% isn't allowed).
- Reel windows that are dark instead of transparent, so the symbols can't show through.
- Text or numbers baked into symbols or plaques where the app writes its own.
- Only flattened screenshots, with no separate image files.
- A music file with silence or a fade at the end, which gives a gap or a jump every loop.

---

## What happens on delivery (for the Zoya7 team)

1. `python3 tools/add_game.py <zip> --check` checks the delivery against this document (sizes,
   transparency, reel windows, file names, `game.json`, sound lengths, the music loop's length)
   and lists anything to send back to fix.
2. `python3 tools/add_game.py <zip>` brings it in: symbols and frame resized for the app into
   `assets/games/<id>/`, the optional buttons, plaques, banners and backdrop beside them, lobby
   art as `assets/app/game_<id>.webp` and `card_<id>.webp`, effects as MP3, and the music as OGG
   (looped whole on Android) and MP3 with a 1 s wrap-around pad at each end (the web loops the
   middle, so the MP3 encoder can't leave a gap). It prints the code to paste: the skin (art,
   windows, colours, sounds, overrides), the lobby entry and the standard setup.
3. Paste it, solve the reel strips for `target_rtp`, and run the tests (every screen size, the
   math, the skin's art and sound files) before it goes live.
4. It appears in the lobby and on the admin **Games** page (on/off, featured, bet limits, RTP)
   and in the reports.
