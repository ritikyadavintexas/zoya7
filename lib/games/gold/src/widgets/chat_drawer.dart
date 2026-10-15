import 'package:flutter/material.dart';

import '../controller.dart';
import '../icons.dart';
import '../style.dart';
import 'fx.dart';

/// Right-side TABLE CHAT drawer.
class ChatDrawer extends StatefulWidget {
  const ChatDrawer({super.key, required this.c});
  final GoldController c;

  @override
  State<ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends State<ChatDrawer> {
  static const double _w = 540;
  final _text = TextEditingController();
  final _focus = FocusNode();

  GoldController get c => widget.c;

  void _send() {
    c.chatSend(_text.text);
    _text.clear();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) => Stack(children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          right: _w,
          child: Tap(
            onTap: c.closeChat,
            label: 'Close chat',
            pressScale: 1,
            child: ColoredBox(color: GC.a(10, 5, 2, .45 * t)),
          ),
        ),
        Positioned(
          right: -_w * (1 - t),
          top: 0,
          bottom: 0,
          width: _w,
          child: _drawer(),
        ),
      ]),
    );
  }

  Widget _drawer() => Semantics(
        scopesRoute: true,
        label: 'Table chat',
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              gradient: GC.panelFill,
              border: const Border(left: BorderSide(color: Color(0xFFE8B545), width: 4)),
              boxShadow: [bs(-20, 0, 50, GC.a(0, 0, 0, .6))],
            ),
            child: Column(children: [
              _header(),
              Expanded(child: _log()),
              _composer(),
            ]),
          ),
        ),
      );

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: GC.a(232, 181, 69, .35), width: 1.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TABLE CHAT', style: lilita(40, color: GC.goldTitle, letterSpacingEm: .04)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GC.green,
                      boxShadow: [bs(0, 0, 8, GC.green)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('312 players in this game', style: rubik(18, color: GC.muted)),
                ]),
              ],
            ),
            CloseButtonRound(onTap: c.closeChat, size: 64, icon: 28, label: 'Close chat'),
          ],
        ),
      );

  Widget _log() {
    final msgs = c.chat;
    return Semantics(
      liveRegion: true,
      child: ListView.separated(
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        itemCount: msgs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, i) => _message(msgs[msgs.length - 1 - i]),
      ),
    );
  }

  Widget _message(ChatMessage m) {
    if (m.system) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          decoration: BoxDecoration(
            color: GC.a(226, 176, 79, .14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GC.a(226, 176, 79, .5), width: 1.5),
          ),
          child: Text(m.text, textAlign: TextAlign.center, style: rubik(18, color: GC.goldText)),
        ),
      );
    }
    final mine = m.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: (_w - 4 - 48) * .86),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m.name,
                style: rubik(18,
                    weight: FontWeight.w700,
                    color: mine ? GC.goldText : Color(m.color ?? 0xFFF2C869))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(mine ? 22 : 6),
                  bottomRight: Radius.circular(mine ? 6 : 22),
                ),
                gradient: mine
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFB0121C), Color(0xFF7A050C)],
                      )
                    : null,
                color: mine ? null : const Color(0xFF1C140B),
                border: Border.all(color: mine ? const Color(0xFFE0A52E) : const Color(0xFF3A2C16), width: 1.5),
              ),
              child: Text(m.text,
                  style: rubik(22, height: 1.35, color: mine ? GC.cream : const Color(0xFFF5E6C4))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: GC.a(232, 181, 69, .35), width: 1.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final q in const ['Good luck!', 'Nice win!', 'So close!', "Let's go!"])
                  Tap(
                    onTap: () => c.chatSend(q),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: GC.btnDark,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: GC.chipBorder, width: 1.5),
                      ),
                      child: Text(q, style: rubik(19, color: GC.goldTitle)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 68,
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                    cursorColor: GC.goldTitle,
                    style: rubik(21, color: GC.cream),
                    decoration: InputDecoration(
                      hintText: 'Say something to the table…',
                      hintStyle: rubik(21, color: GC.a(255, 244, 220, .45)),
                      filled: true,
                      fillColor: GC.btnDark,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                      enabledBorder: _border(GC.chipBorder),
                      focusedBorder: _border(GC.btnBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Tap(
                onTap: _send,
                label: 'Send message',
                child: Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: GC.brightBorder, width: 3),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE0303B), Color(0xFF9A0A14)],
                    ),
                  ),
                  child: GoldIcons.send(30),
                ),
              ),
            ]),
          ],
        ),
      );

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(34),
        borderSide: BorderSide(color: c, width: 2),
      );
}
