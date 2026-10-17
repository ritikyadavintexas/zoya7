import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoya7_gold/games/html/model.dart';
import 'package:zoya7_gold/games/html/package.dart';

/// Just enough of a PNG for its size to be read.
Uint8List png(int w, int h) {
  final b = ByteData(33);
  const sig = [137, 80, 78, 71, 13, 10, 26, 10];
  for (var i = 0; i < 8; i++) {
    b.setUint8(i, sig[i]);
  }
  b.setUint32(8, 13);
  for (final (i, c) in 'IHDR'.codeUnits.indexed) {
    b.setUint8(12 + i, c);
  }
  b.setUint32(16, w);
  b.setUint32(20, h);
  return b.buffer.asUint8List();
}

Map<String, Object> manifest({Object? options}) => {
      'zoya7': 1,
      'id': 'lanterns',
      'name': 'Lantern Drift',
      'category': 'INSTANT',
      'description': 'Release a lantern and see where the wind takes it.',
      'credits': 'Made for Zoya7',
      'options': options ??
          [
            {
              'id': 'main',
              'label': 'Release',
              'outcomes': [
                {'id': 'dark', 'label': 'Drifts away', 'multiplier': 0},
                {'id': 'rose', 'label': 'Rose', 'multiplier': 2},
                {'id': 'sea', 'label': 'Sea', 'multiplier': 5},
                {'id': 'gold', 'label': 'Golden', 'multiplier': 30},
              ],
            },
          ],
    };

/// A game zip, wrapped in its folder the way GPT delivers it.
Uint8List zip(Map<String, Object> files, {String folder = 'lanterns/'}) {
  final a = Archive();
  for (final MapEntry(key: path, value: content) in files.entries) {
    final bytes = content is Uint8List ? content : utf8.encode(content is String ? content : jsonEncode(content));
    a.addFile(ArchiveFile('$folder$path', bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}

Map<String, Object> goodFiles() => {
      'game.json': manifest(),
      'index.html': '<script src="zoya7-bridge.js"></script><script src="src/game.js"></script>',
      'src/game.js': 'Zoya7.init().then(s => { draw(s); Zoya7.ready(); }); go.onclick = () => Zoya7.play({bet}); back.onclick = () => Zoya7.exit();',
      'lobby/icon.png': png(512, 512),
      'lobby/tile.png': png(880, 472),
      'sounds/bloom.ogg': Uint8List(10),
      'mockups/idle.png': png(2560, 1080),
    };

void main() {
  group('payout', () {
    const table = [
      Outcome(id: 'none', multiplier: 0),
      Outcome(id: 'two', multiplier: 2),
      Outcome(id: 'five', multiplier: 5),
      Outcome(id: 'thirty', multiplier: 30),
    ];

    test('any multipliers pay back exactly the RTP, each win an equal share', () {
      for (final rtp in [.9, .95, .97]) {
        final p = chancesFor(table, rtp)!;
        expect(p.reduce((a, b) => a + b), closeTo(1, 1e-12));
        final back = [for (var i = 0; i < table.length; i++) p[i] * table[i].multiplier].reduce((a, b) => a + b);
        expect(back, closeTo(rtp, 1e-12));
        // equal shares: 2× pays back as much as 30×
        expect(p[1] * 2, closeTo(p[3] * 30, 1e-12));
      }
    });

    test('a game can weight its wins, and several no-wins split what is left', () {
      const t = [
        Outcome(id: 'miss1', multiplier: 0),
        Outcome(id: 'miss2', multiplier: 0),
        Outcome(id: 'small', multiplier: 1.5, share: 3),
        Outcome(id: 'big', multiplier: 25),
      ];
      final p = chancesFor(t, .95)!;
      expect(p[2] * 1.5, closeTo(3 * p[3] * 25, 1e-12));
      expect(p[0], closeTo(p[1], 1e-12));
    });

    test('wins too small to reach the RTP, or no losing outcome, are refused', () {
      expect(chancesFor(const [Outcome(id: 'a', multiplier: 0), Outcome(id: 'b', multiplier: .5)], .95), isNull);
      expect(chancesFor(const [Outcome(id: 'a', multiplier: 2), Outcome(id: 'b', multiplier: 5)], .95), isNull);
    });

    test('drawing outcomes over a million rounds lands on the RTP', () {
      final p = chancesFor(table, .95)!;
      final r = Random(3);
      var paid = 0.0;
      const n = 1000000;
      for (var i = 0; i < n; i++) {
        paid += table[drawOutcome(p, r)].multiplier;
      }
      expect(paid / n, closeTo(.95, .01));
    });

    test('bet steps run from the minimum to the maximum', () {
      expect(betSteps(100, 1000), [100, 200, 500, 1000]);
      expect(betSteps(.5, 5), [.5, 1, 2, 5]);
    });
  });

  group('package', () {
    test('a game made to the prompt is read, unwrapped and trimmed of what it doesn’t need', () {
      final p = GamePackage.read(zip(goodFiles()));
      expect(p.errors, isEmpty);
      expect(p.ok, isTrue);
      expect(p.id, 'lanterns');
      expect(p.game!.name, 'Lantern Drift');
      expect(p.game!.options.single.outcomes.map((o) => o.multiplier), [0, 2, 5, 30]);
      expect(p.files.keys, containsAll(['index.html', 'game.json', 'src/game.js', 'lobby/icon.png', 'sounds/bloom.ogg']));
      expect(p.files.keys.where((k) => k.startsWith('mockups/')), isEmpty);
      expect(p.warnings.join(), contains('mockups/'));
    });

    test('everything wrong is listed', () {
      final files = goodFiles()
        ..['game.json'] = {
          ...manifest(options: [
            {
              'id': 'main',
              'outcomes': [
                {'id': 'a', 'multiplier': 1},
                {'id': 'b', 'multiplier': 1.2},
              ],
            },
          ]),
          'id': 'Bad-Id',
          'name': 'Win real money now!!',
        }
        ..['index.html'] = '<script src="https://cdn.example.com/x.js"></script>'
        ..remove('lobby/icon.png');
      final p = GamePackage.read(zip(files));
      expect(p.ok, isFalse);
      final all = p.errors.join('\n');
      expect(all, contains('id "Bad-Id"'));
      expect(all, contains('name'));
      expect(all, contains('money wording'));
      expect(all, contains('multiplier 0'));
      expect(all, contains('zoya7-bridge.js'));
      expect(all, contains('loads something from the internet'));
      expect(all, contains('lobby/icon.png'));
    });

    test('paths that climb out of the folder are refused', () {
      final p = GamePackage.read(zip({'../evil.js': 'x', ...goodFiles()}, folder: ''));
      expect(p.errors.single, contains('Unsafe path'));
    });

    test('a built-in game’s id can’t be taken, and a non-zip is refused', () {
      expect(GamePackage.read(zip(goodFiles()..['game.json'] = {...manifest(), 'id': 'blackjack'})).errors.join(), contains('built-in'));
      expect(GamePackage.read(Uint8List.fromList(utf8.encode('hello'))).errors.single, contains('zip'));
    });
  });

  test('the prompt carries the exact bridge the uploader puts in every game', () {
    final doc = File('docs/GAME_PROMPT.md').readAsStringSync();
    final bridge = File('assets/sdk/zoya7-bridge.js').readAsStringSync();
    expect(doc, contains('```js\n$bridge```'));
  });
}
