# Bloom Atelier

An original landscape-only Zoya7 INSTANT game: a moonlit glasshouse where every chance round grows a luminous botanical discovery.

## How to play

1. Choose GC or DC and an allowed seed offering (bet).
2. Press **GROW A SEED** or Space/Enter.
3. The Zoya7 host draws and settles the outcome immediately. The animation illustrates precisely the outcome returned by the host; player timing has no effect on payouts.
4. Inspect the **i** panel to see the host-supplied probabilities and every possible multiplier.

## Pay table

| Outcome | Multiplier |
|---|---:|
| Quiet Seed | 0× |
| Pearl Bud | 1.5× |
| Silver Iris | 3× |
| Azure Orchid | 9× |
| Sun Lotus | 36× |
| Star Garden | 180× |

The game specifies **no outcome frequencies, jackpot funds, or RTP**. The Zoya7 bridge/host alone determines chances. The independent demo uses the unchanged bridge's demo payback rule and pretend coins.

## Run in demo mode

```sh
cd bloomatelier
python3 -m http.server 8000
```

Open `http://localhost:8000` on a computer or phone. No build step, no dependencies, and no outside resources. Audio starts after the first interaction; it gracefully degrades if unavailable.

## Package contents

`index.html`, unchanged `zoya7-bridge.js`, `game.json`, `src/game.js`, layered botanical PNG and SVG artwork under `assets/`, original MP3 sounds under `sounds/`, and a 512×512 square lobby icon plus 880×472 lobby tile under `lobby/`.

The 1920×1080 logical landscape stage scales uniformly and is centered in any viewport, with the background filling extra screen area. Touch, mouse and keyboard supported; reduced-motion requests shorten reveals. Currency, balances and chances always come from the host session.
