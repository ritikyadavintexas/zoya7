#!/usr/bin/env python3
"""Checks a game delivered to docs/GAME.md and brings it into the app.

    python3 tools/add_game.py pharaohgold.zip            # check, then import
    python3 tools/add_game.py pharaohgold.zip --check    # only check

The check lists everything that doesn't follow GAME.md (send it back to the designer). The
import writes the art and sounds into assets/ and prints the code to add (skin, lobby entry,
standard setup). Needs Pillow, numpy, scipy and ffmpeg.
"""

import json
import os
import re
import subprocess
import sys
import tempfile
import zipfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'sounds'))
from make_sounds import SR, encode  # noqa: E402

ROOT = os.environ.get('ZOYA7_ROOT') or os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))

# GAME.md role → the engine's symbol (whose pay it takes).
ROLES = {'mega': 'seven', 'major': 'diamond', 'minor': 'crown', 'mini': 'bar', 'top': 'star', 'high2': 'bell',
         'high3': 'melon', 'mid1': 'plum', 'mid2': 'orange', 'low1': 'lemon', 'low2': 'cherry'}
STANDARD_WINDOWS = [[258, 328, 570, 752], [877, 328, 566, 752], [1492, 328, 572, 752]]

REQUIRED = {
    'lobby/tile.png': ((880, 472), False),
    'lobby/card.png': ((460, 356), False),
    'table/frame.png': ((2320, 1312), True),
    **{f'symbols/{r}.png': ((330, 330), True) for r in ROLES},
}
OPTIONAL_SETS = {
    'buttons': {'spin.png': (760, 340), 'stop.png': (680, 276), 'auto.png': (486, 274), 'max_bet.png': (426, 276)},
    'jackpots': {'mega.png': (486, 352), 'major.png': (464, 350), 'minor.png': (432, 318), 'mini.png': (410, 308)},
    'wins': {'big.png': (1540, 948), 'super.png': (1572, 928), 'mega.png': (1280, 980), 'jackpot.png': (1364, 988)},
}
# The engine's file each optional piece replaces (lib/games/gold/src/assets.dart).
GOLD = {'buttons/spin.png': 'btn_spin', 'buttons/stop.png': 'btn_stop', 'buttons/auto.png': 'btn_auto',
        'buttons/max_bet.png': 'btn_max_bet', 'jackpots/mega.png': 'jp_mega', 'jackpots/major.png': 'jp_major',
        'jackpots/minor.png': 'jp_minor', 'jackpots/mini.png': 'jp_mini', 'wins/big.png': 'win_big',
        'wins/super.png': 'win_super', 'wins/mega.png': 'win_mega', 'wins/jackpot.png': 'win_jackpot'}
SOUNDS = {'spin': (1.0, 1.4), 'reel_stop': (.15, .4), 'win_small': (.8, 1.5), 'win_big': (2.5, 4), 'jackpot': (4, 6)}
OPTIONAL_SOUNDS = {'button': (0, .15), 'collect': (.8, 1.5)}
BANNED = re.compile(r'\$|\bcash\b|\bmoney\b|\bredeem|\bprize|\bwithdraw', re.I)


def find_game(path, tmp):
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            for n in z.namelist():  # nothing may land outside the folder it's unpacked into
                if n.startswith('/') or '..' in n.split('/'):
                    sys.exit(f'Unsafe path in the zip: {n}')
            z.extractall(tmp)
        path = tmp
    for d, _, files in os.walk(path):
        if 'game.json' in files and '__MACOSX' not in d:
            return d
    sys.exit('No game.json found.')


def decode(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 's16le', '-ac', '1', '-ar', str(SR), '-'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, '<i2').astype(float) / 32768


def check(d):
    problems, notes = [], []
    try:
        g = json.load(open(os.path.join(d, 'game.json')))
    except Exception as e:  # noqa: BLE001
        return [f'game.json: not valid JSON ({e})'], notes, None

    gid = g.get('id', '')
    if not re.fullmatch(r'[a-z0-9]+', gid or ''):
        problems.append('game.json id: lowercase letters and digits only')
    if os.path.basename(os.path.normpath(d)) != gid:
        problems.append(f'The folder must be named like the id ("{gid}")')
    if not (0 < len(g.get('name') or '') <= 14):
        problems.append('game.json name: 1 to 14 characters')
    if BANNED.search(json.dumps(g)):
        problems.append('game.json: no "$", cash, money, redeem, prize or withdraw wording')
    if g.get('type') != 'reel-slot-3x3':
        problems.append(f'type "{g.get("type")}" is a new kind of game: it needs building (GAME.md section 9), not importing')
        return problems, notes, g
    if g.get('category') != 'SLOTS':
        problems.append('game.json category: SLOTS')
    if g.get('badge') not in ('NEW', 'HOT', None):
        problems.append('game.json badge: NEW, HOT or null')
    bg = (g.get('colors') or {}).get('background')
    if not (isinstance(bg, list) and len(bg) == 3 and all(re.fullmatch(r'#[0-9A-Fa-f]{6}', c or '') for c in bg)):
        problems.append('game.json colors.background: three colours like "#8A2A12"')
    if set((g.get('symbols') or {}).keys()) != set(ROLES):
        problems.append(f'game.json symbols: a name for each of {", ".join(ROLES)}')
    rtp = g.get('target_rtp')
    if not (isinstance(rtp, (int, float)) and .90 <= rtp <= .96):
        problems.append('game.json target_rtp: between 0.90 and 0.96')
    if not (g.get('credits') or '').strip():
        problems.append('game.json credits: who made the art and sound, and the licence')
    music = g.get('music') or {}
    try:
        expect = music['bars'] * 4 * 60 / music['bpm']
        if abs(expect - music['loop_seconds']) > .01:
            problems.append(f'game.json music: {music["bars"]} bars at {music["bpm"]} BPM is {expect:.3f} s, not {music["loop_seconds"]}')
    except (KeyError, TypeError, ZeroDivisionError):
        problems.append('game.json music: bpm, bars and loop_seconds')
    windows = g.get('reel_windows') or STANDARD_WINDOWS
    if not (len(windows) == 3 and all(len(w) == 4 for w in windows)):
        problems.append('game.json reel_windows: null or three [x, y, width, height]')
        windows = STANDARD_WINDOWS

    def image(rel, size, alpha):
        p = os.path.join(d, rel)
        if not os.path.exists(p):
            problems.append(f'Missing {rel}')
            return None
        try:
            im = Image.open(p)
            im.load()
        except Exception:  # noqa: BLE001
            problems.append(f'{rel}: not a readable PNG')
            return None
        if im.format != 'PNG':
            problems.append(f'{rel}: must be PNG (is {im.format})')
        if im.size != size:
            problems.append(f'{rel}: must be {size[0]} × {size[1]} (is {im.size[0]} × {im.size[1]})')
        rgba = im.convert('RGBA')
        a = np.asarray(rgba)[:, :, 3]
        if alpha and a.min() == 255:
            problems.append(f'{rel}: needs a transparent background')
        if not alpha and a.min() < 250:
            problems.append(f'{rel}: must be fully opaque')
        return rgba

    for rel, (size, alpha) in REQUIRED.items():
        im = image(rel, size, alpha)
        if rel == 'table/frame.png' and im is not None and im.size == size:
            a = np.asarray(im)[:, :, 3]
            for i, (x, y, w, h) in enumerate(windows):
                win = a[y + 4:y + h - 4, x + 4:x + w - 4]
                if win.size == 0 or (win > 8).mean() > .02:
                    problems.append(f'table/frame.png: reel window {i + 1} ({x}, {y}, {w} × {h}) must be fully transparent')
    for folder, files in OPTIONAL_SETS.items():
        have = [f for f in files if os.path.exists(os.path.join(d, folder, f))]
        if have and len(have) < len(files):
            problems.append(f'{folder}/: give all of {", ".join(files)} or none')
        elif have:
            for f, size in files.items():
                image(f'{folder}/{f}', size, True)
    if os.path.exists(os.path.join(d, 'table/background.png')):
        image('table/background.png', (2560, 1440), False)

    for name, (lo, hi) in {**SOUNDS, **OPTIONAL_SOUNDS, 'music': (20, 40)}.items():
        p = next((os.path.join(d, 'sounds', f'{name}.{e}') for e in ('wav', 'mp3', 'ogg')
                  if os.path.exists(os.path.join(d, 'sounds', f'{name}.{e}'))), None)
        if p is None:
            if name not in OPTIONAL_SOUNDS:
                problems.append(f'Missing sounds/{name}.wav')
            continue
        if not p.endswith('.wav'):
            notes.append(f'sounds/{os.path.basename(p)}: WAV is preferred')
        try:
            x = decode(p)
        except subprocess.CalledProcessError:
            problems.append(f'sounds/{os.path.basename(p)}: not a readable sound file')
            continue
        dur = len(x) / SR
        if name == 'music' and 'loop_seconds' in music:
            if abs(dur - music['loop_seconds']) > .005:
                problems.append(f'sounds/music: must be exactly {music["loop_seconds"]} s, one loop (is {dur:.3f} s)')
        elif not lo * .8 <= dur <= hi * 1.25:
            notes.append(f'sounds/{name}: {dur:.2f} s (GAME.md asks {lo}–{hi} s)')
        if np.max(np.abs(x)) >= .999:
            notes.append(f'sounds/{name}: clips (peak at 0 dBFS)')
    return problems, notes, g


def import_game(d, g):
    gid = g['id']
    out = os.path.join(ROOT, 'assets', 'games', gid)
    snd = os.path.join(out, 'sounds')
    os.makedirs(snd, exist_ok=True)
    frame = Image.open(os.path.join(d, 'table/frame.png')).convert('RGBA')
    frame.resize((1400, round(1400 * frame.height / frame.width)), Image.LANCZOS).save(os.path.join(out, 'reel_frame.png'), optimize=True)
    for role in ROLES:
        im = Image.open(os.path.join(d, f'symbols/{role}.png')).convert('RGBA')
        im.resize((300, 300), Image.LANCZOS).save(os.path.join(out, f'sym_{role}.png'), optimize=True)
    overrides = {}
    for rel, gold in GOLD.items():
        p = os.path.join(d, rel)
        if os.path.exists(p):
            im = Image.open(p).convert('RGBA')
            im.resize((im.width // 2, im.height // 2), Image.LANCZOS).save(os.path.join(out, f'{gold}.png'), optimize=True)
            overrides[gold] = f'{gold}.png'
    background = os.path.exists(os.path.join(d, 'table/background.png'))
    if background:
        Image.open(os.path.join(d, 'table/background.png')).convert('RGB').save(os.path.join(out, 'background.webp'), quality=82)
    app = os.path.join(ROOT, 'assets', 'app')
    Image.open(os.path.join(d, 'lobby/tile.png')).convert('RGB').save(os.path.join(app, f'game_{gid}.webp'), quality=88)
    Image.open(os.path.join(d, 'lobby/card.png')).convert('RGB').save(os.path.join(app, f'card_{gid}.webp'), quality=88)

    extra = []
    for name in [*SOUNDS, *OPTIONAL_SOUNDS]:
        p = next((os.path.join(d, 'sounds', f'{name}.{e}') for e in ('wav', 'mp3', 'ogg')
                  if os.path.exists(os.path.join(d, 'sounds', f'{name}.{e}'))), None)
        if p is None:
            continue
        if name in OPTIONAL_SOUNDS:
            extra.append(name)
        encode(decode(p), os.path.join(snd, f'{name}.mp3'), ['-ac', '1', '-codec:a', 'libmp3lame', '-b:a', '96k'])
    p = next(os.path.join(d, 'sounds', f'music.{e}') for e in ('wav', 'mp3', 'ogg')
             if os.path.exists(os.path.join(d, 'sounds', f'music.{e}')))
    x = decode(p)
    loop = len(x)
    encode(x, os.path.join(snd, 'music.ogg'), ['-ac', '1', '-codec:a', 'libvorbis', '-q:a', '3'])
    encode(np.concatenate([x[-SR:], x, x[:SR]]), os.path.join(snd, 'music.mp3'), ['-ac', '1', '-codec:a', 'libmp3lame', '-b:a', '80k'])

    W, H = 2320, 1312
    win = g.get('reel_windows') or STANDARD_WINDOWS
    cols = ', '.join(f'({x / W * 100:.1f}, {w / W * 100:.1f})' for x, _, w, _ in win)
    top, height = sum(w[1] for w in win) / 3 / H, sum(w[3] for w in win) / 3 / H
    colors = ', '.join(f'Color(0xFF{c[1:].upper()})' for c in g['colors']['background'])
    name = g['name']
    var = gid
    art = '\n'.join(f"      Sym.{sym}: '$_{var}/sym_{role}.png'," for role, sym in ROLES.items())
    labels = ', '.join(f"Sym.{sym}: '{g['symbols'][role].lower()}'" for role, sym in ROLES.items())
    over = '\n'.join(f"      'assets/games/gold/{v}': '$_{var}/{v}'," for v in overrides.values())
    code = f"""
── lib/games/gold/src/skin.dart (and a case in forGame: '{gid}' => {var},) ──
  static const _{var} = 'assets/games/{gid}';

  static const {var} = SlotSkin(
    name: '{name}',
    background: [{colors}],
    reelFrame: '$_{var}/reel_frame.png',
    reelCols: [{cols}],
    reelTop: {top:.3f},
    reelHeight: {height:.3f},
    sounds: '$_{var}/sounds',
    musicLoop: {loop} / {SR},{f"""
    extraSounds: {{{', '.join(repr(e) for e in extra)}}},""" if extra else ''}{f"""
    backgroundImage: '$_{var}/background.webp',""" if background else ''}
    art: {{
{art}
    }},
    labels: {{{labels}}},{f'''
    overrides: {{
{over}
    }},''' if overrides else ''}
  );

── pubspec.yaml ──
    - assets/games/{gid}/
    - assets/games/{gid}/sounds/

── lib/app/assets.dart ──
  static const {var}Game = '$_d/game_{gid}.webp';   (and in `all`, with card_{gid}.webp)
  GameInfo(id: '{gid}', name: '{name}', cat: 'SLOTS', image: A.{var}Game, playable: true, players: '0'),

── lib/backoffice/casino.dart ──
  kindOf: '{gid}' → goldSlot;  _startingGame: '{gid}' => solve({g['target_rtp']}){", badge 'NEW'" if g.get('badge') == 'NEW' else ''}

── test/gold_math_test.dart ──
  add SlotSkin.{var} to the skins checked.
"""
    print(code)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    with tempfile.TemporaryDirectory() as tmp:
        d = find_game(sys.argv[1], tmp)
        problems, notes, g = check(d)
        for n in notes:
            print(f'note: {n}')
        if problems:
            print(f'\n{len(problems)} thing(s) to fix before it can go in:')
            for p in problems:
                print(f'  - {p}')
            sys.exit(1)
        print(f'{g["name"]} follows GAME.md.')
        if '--check' not in sys.argv:
            import_game(d, g)


if __name__ == '__main__':
    main()
