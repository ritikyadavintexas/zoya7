import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// The game's own keyboard. On an upright phone the game is drawn turned
/// ([ForceLandscape]) but the phone's keyboard would still come up the
/// ordinary way, across the bottom and not matching anything above it, and a
/// web page can't turn it. So there every text box types with this keyboard
/// instead, drawn turned with the game, along its bottom edge. It plugs in as
/// Flutter's text input control, so text boxes need nothing of their own.
class GameKeyboard extends ChangeNotifier with TextInputControl {
  GameKeyboard._();
  static final instance = GameKeyboard._();

  TextInputClient? _client;
  TextInputConfiguration _config = const TextInputConfiguration();
  TextEditingValue _value = TextEditingValue.empty;
  bool _inUse = false;

  /// A text box is being typed in.
  bool visible = false;

  /// The next letter is a capital.
  bool shift = false;

  /// Digits only (amounts, phone numbers).
  bool get numeric =>
      _config.inputType.index == TextInputType.number.index || _config.inputType.index == TextInputType.phone.index;

  /// What the action key says and does (Next, Go, Done…).
  TextInputAction get action => _config.inputAction;

  /// Use this keyboard ([on]) or the phone's own.
  void use(bool on) {
    if (on == _inUse) return;
    _inUse = on;
    on ? TextInput.setInputControl(this) : TextInput.restorePlatformInputControl();
    if (!on && visible) {
      visible = false;
      notifyListeners();
    }
  }

  @override
  void attach(TextInputClient client, TextInputConfiguration configuration) {
    _client = client;
    _config = configuration;
    shift = false;
    notifyListeners();
  }

  @override
  void detach(TextInputClient client) {
    if (_client != client) return;
    _client = null;
    visible = false;
    notifyListeners();
  }

  @override
  void updateConfig(TextInputConfiguration configuration) {
    _config = configuration;
    notifyListeners();
  }

  @override
  void setEditingState(TextEditingValue value) => _value = value;

  @override
  void show() {
    visible = true;
    notifyListeners();
  }

  @override
  void hide() {
    visible = false;
    notifyListeners();
  }

  void _send(TextEditingValue v) {
    _value = v;
    TextInput.updateEditingValue(v);
  }

  /// Types [s] where the cursor is (over any selection).
  void type(String s) {
    final v = _value, sel = v.selection;
    final start = sel.isValid ? sel.start : v.text.length, end = sel.isValid ? sel.end : v.text.length;
    final t = shift ? s.toUpperCase() : s;
    _send(TextEditingValue(text: v.text.replaceRange(start, end, t), selection: TextSelection.collapsed(offset: start + t.length)));
    if (shift) {
      shift = false;
      notifyListeners();
    }
  }

  /// Deletes the selection, or the character before the cursor.
  void backspace() {
    final v = _value, sel = v.selection;
    var start = sel.isValid ? sel.start : v.text.length;
    final end = sel.isValid ? sel.end : v.text.length;
    if (start == end) {
      if (start == 0) return;
      start = v.text.characters.take(v.text.substring(0, start).characters.length - 1).string.length;
    }
    _send(TextEditingValue(text: v.text.replaceRange(start, end, ''), selection: TextSelection.collapsed(offset: start)));
  }

  void toggleShift() {
    shift = !shift;
    notifyListeners();
  }

  /// The action key: next box, log in, done…
  void submit() => _client?.performAction(_config.inputAction);

  /// Puts the keyboard away (the box loses focus).
  void close() => FocusManager.instance.primaryFocus?.unfocus();

  @visibleForTesting
  void debugReset() {
    use(false);
    _client = null;
    visible = false;
    shift = false;
  }
}

/// The keys, sized to [height] (the game's height), along the bottom of the game.
class GameKeyboardView extends StatelessWidget {
  const GameKeyboardView({super.key, required this.height});
  final double height;

  /// How tall the keyboard is in a game this tall.
  /// (Five rows, each with a gap above; the padding and the top border.)
  static double heightFor(double height) => (keyHeightFor(height) + _gap) * 5 + 3 + 6 + 1;
  static double keyHeightFor(double height) => (height * .085).clamp(28.0, 42.0);
  static const _gap = 5.0;

  @override
  Widget build(BuildContext context) {
    final k = GameKeyboard.instance;
    final keyH = keyHeightFor(height);
    return ListenableBuilder(
      listenable: k,
      builder: (context, _) {
        Widget key(String label, VoidCallback onTap, {int flex = 1, String? semantics, bool strong = false, bool on = false, Widget? icon}) =>
            Expanded(
              flex: flex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _gap / 2),
                child: Semantics(
                  button: true,
                  label: semantics ?? 'Key $label',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => onTap(),
                    child: Container(
                      height: keyH,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: strong ? Z.red3 : null,
                        color: strong ? null : (on ? Z.chip : const Color(0xFF2A1E12)),
                        border: Border.all(color: strong ? Z.goldHi.withValues(alpha: .6) : Z.cardBorder),
                      ),
                      child: ExcludeSemantics(
                        child: icon ??
                            Text(label,
                                style: outfit(keyH * .44, w: strong ? FontWeight.w800 : FontWeight.w600, c: strong ? Z.ctaText : Z.cream)),
                      ),
                    ),
                  ),
                ),
              ),
            );
        Widget row(List<Widget> keys, {double indent = 0}) => Padding(
              padding: EdgeInsets.only(top: _gap, left: indent, right: indent),
              child: Row(children: keys),
            );
        Widget letters(String s) => row([for (final c in s.split('')) key(k.shift ? c.toUpperCase() : c, () => k.type(c))]);
        final actionLabel = switch (k.action) {
          TextInputAction.next => 'NEXT',
          TextInputAction.go => 'GO',
          TextInputAction.search => 'SEARCH',
          TextInputAction.send => 'SEND',
          _ => 'DONE',
        };
        final back = key('', k.backspace, semantics: 'Backspace', flex: 3,
            icon: Icon(Icons.backspace_outlined, size: keyH * .5, color: Z.cream));
        final hide = key('', k.close, semantics: 'Hide keyboard', flex: 3,
            icon: Icon(Icons.keyboard_hide_outlined, size: keyH * .55, color: Z.cream));
        final go = key(actionLabel, k.submit, semantics: actionLabel, flex: 5, strong: true);
        final rows = k.numeric
            ? [
                row([for (final c in '123'.split('')) key(c, () => k.type(c), flex: 4), back]),
                row([for (final c in '456'.split('')) key(c, () => k.type(c), flex: 4), hide]),
                row([for (final c in '789'.split('')) key(c, () => k.type(c), flex: 4), key('-', () => k.type('-'), flex: 3)]),
                row([
                  key('.', () => k.type('.'), flex: 4),
                  key('0', () => k.type('0'), flex: 4),
                  key(actionLabel, k.submit, semantics: actionLabel, flex: 7, strong: true),
                ]),
              ]
            : [
                letters('1234567890'),
                letters('qwertyuiop'),
                letters('asdfghjkl'),
                row([
                  key('', k.toggleShift, semantics: 'Shift', flex: 3, on: k.shift,
                      icon: Icon(Icons.arrow_upward_rounded, size: keyH * .5, color: Z.cream)),
                  for (final c in 'zxcvbnm'.split('')) key(k.shift ? c.toUpperCase() : c, () => k.type(c), flex: 2),
                  back,
                ]),
                row([
                  hide,
                  key('-', () => k.type('-'), flex: 2),
                  key('_', () => k.type('_'), flex: 2),
                  key('.', () => k.type('.'), flex: 2),
                  key('@', () => k.type('@'), flex: 2),
                  key('space', () => k.type(' '), flex: 8, semantics: 'Space'),
                  go,
                ]),
              ];
        // Taps on the keys count as taps on the text box (a tap anywhere else
        // on the web would end the typing).
        return TextFieldTapRegion(
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 3, 8, 6),
            decoration: const BoxDecoration(
              color: Color(0xFF140D07),
              border: Border(top: BorderSide(color: Z.cardBorder)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: k.numeric ? 520 : 900),
                child: Column(mainAxisSize: MainAxisSize.min, children: rows),
              ),
            ),
          ),
        );
      },
    );
  }
}
