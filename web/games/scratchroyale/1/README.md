# Scratch Royale — Zoya7 scratch-card game

**Launch**: On Mac, double-click `tools/start_demo.command` (Terminal may require you to allow it); on Windows use `tools/start_demo.bat`. Or open a terminal in this game folder, run `python3 -m http.server 8000`, then open `http://localhost:8000/`. **Do not double-click `index.html`** from a file explorer: the standalone demo reads `game.json` over HTTP and therefore requires the included local server launcher. Keep the launcher window open while playing.

**How to play**: (1) select one of five ticket collections (05, 10, 20, 30, 50). These are visual *series labels*, not fixed stake amounts. (2) select GC/DC and an actual allowed bet supplied by the app; (3) press PLAY TICKET; (4) drag across the silver area, or press REVEAL ALL; (5) view the exact Zoya7-decided outcome and payout. Another round is started with NEW TICKET.

**Outcome mapping**: nomatch=0× (three different symbols); clover=1.5×; pearl=3×; ruby=8×; crown=25×; diamond=100×. Every win shows three matching symbols. Player scratching never affects payout. Chances and bets are sourced from `Zoya7.init()`, results from `Zoya7.play()`. No client-side win generation.

**Integration**: identical `id` to prior scratchroyale so uploads can replace that game. `zoya7-bridge.js` is copied unchanged from provided prompt. Host handles wagers, payouts, bets, and currencies. Offline and no CDNs. Audio MP3 cues are bundled; WebAudio fallback if playback is unavailable. Responsive full canvas, keyboard Space/Enter and Escape, a single reveal action for accessibility.

**Browser testing**: test scripts or screenshots, where available, are separate from the ZIP. Production payouts and host loading should be tested in Zoya7's actual sandbox before publishing.
