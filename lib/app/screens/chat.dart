import 'dart:async';

import 'package:flutter/material.dart';

import '../icons.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

enum _Kind { other, mine, system }

class _Msg {
  const _Msg(this.kind, this.text, {this.name = '', this.color = Z.gold, this.time = ''});
  final _Kind kind;
  final String text;
  final String name;
  final Color color;
  final String time;
}

const _supportColor = Z.gold;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.room = 'community'});
  final String room;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late bool support = widget.room == 'support';
  bool typing = false;
  final muted = <String>{};
  final _draft = TextEditingController();
  final _timers = <Timer>[];

  final community = <_Msg>[
    const _Msg(_Kind.other, 'Morning everyone! Daily bonus is live', name: 'LuckyLina', color: Color(0xFFC99BFF), time: '9:02'),
    const _Msg(_Kind.other, 'Classic 777 has been hot today', name: 'SpinKing', color: Color(0xFF8CC0FF), time: '9:05'),
    const _Msg(_Kind.system, 'SpinKing hit the MINI jackpot — 12,345 GC!'),
    const _Msg(_Kind.other, 'Congrats!! what bet were you on?', name: 'RubyRose', color: Color(0xFFFF8A7A), time: '9:07'),
    const _Msg(_Kind.other, 'Max bet, third spin after the bonus', name: 'SpinKing', color: Color(0xFF8CC0FF), time: '9:08'),
    const _Msg(_Kind.mine, 'Nice one! Heading in now', time: '9:10'),
  ];
  late final supportMsgs = <_Msg>[
    const _Msg(_Kind.system, 'You are chatting with Zoya Support · usually replies in a few minutes'),
    _Msg(_Kind.other, 'Hi ${AppScope.read(context).name}! How can we help you today?',
        name: 'Zoya Support', color: _supportColor, time: '9:12'),
  ];

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _draft.dispose();
    super.dispose();
  }

  String _now() {
    final d = DateTime.now();
    return '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _post(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final inSupport = support;
    setState(() {
      (inSupport ? supportMsgs : community).add(_Msg(_Kind.mine, t, time: _now()));
      _draft.clear();
    });
    if (inSupport) {
      _timers.add(Timer(const Duration(milliseconds: 400), () => mounted ? setState(() => typing = true) : null));
      _timers.add(Timer(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        setState(() {
          typing = false;
          supportMsgs.add(_Msg(_Kind.other, 'Thanks! I am looking into that for you now — one moment.',
              name: 'Zoya Support', color: _supportColor, time: _now()));
        });
      }));
    } else {
      _timers.add(Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() => community.add(
            _Msg(_Kind.other, 'Good luck!', name: 'LuckyLina', color: const Color(0xFFC99BFF), time: _now())));
      }));
    }
  }

  void _openMenu(String name) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xB3060301),
      builder: (ctx) => _MessageMenu(
        name: name,
        onMute: () {
          Navigator.pop(ctx);
          setState(() => muted.add(name));
          showToast(context, "You won't see messages from $name");
        },
        onReport: () {
          Navigator.pop(ctx);
          showToast(context, 'Report sent — our moderators will review it');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = (support ? supportMsgs : community)
        .where((m) => !(m.kind == _Kind.other && muted.contains(m.name)))
        .toList()
        .reversed
        .toList();
    final quick = support
        ? const ['Coins not credited', 'Redemption help', 'Account access']
        : const ['Good luck!', 'Congrats!', 'Which game is hot?'];
    return ZPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Panes(
          sideFraction: .3,
          minSide: 230,
          maxSide: 300,
          divider: true,
          side: PaneList(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            children: [
              Row(children: [
                const BackBtn(label: 'Back'),
                const SizedBox(width: 12),
                Expanded(child: Text('CHAT', style: outfit(21, w: FontWeight.w800, ls: .1, c: Z.gold))),
                RoundBtn(
                  label: 'Notifications',
                  onTap: () => Nav.push(R.notifications),
                  child: const Ico(P.bell, size: 18),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Z.green, boxShadow: [bs(0, 0, 6, Z.green)]),
                ),
                const SizedBox(width: 6),
                Text(support ? 'Support online' : '1,284 players online', style: outfit(12, c: Z.muted)),
              ]),
              const SizedBox(height: 12),
              SegTabs(
                labels: const ['COMMUNITY', 'SUPPORT'],
                index: support ? 1 : 0,
                fontSize: 12,
                ls: .04,
                onChanged: (i) => setState(() {
                  support = i == 1;
                  if (!support) typing = false;
                }),
              ),
              const SizedBox(height: 14),
              Text('QUICK REPLIES', style: outfit(12, w: FontWeight.w800, ls: .14, c: Z.label)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final q in quick)
                  Press(
                    onTap: () => _post(q),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Z.field,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Z.chip),
                      ),
                      child: Center(widthFactor: 1, child: Text(q, style: outfit(13, w: FontWeight.w600, c: Z.gold))),
                    ),
                  ),
              ]),
            ],
          ),
          main: LayoutBuilder(builder: (context, box) {
            return Column(children: [
              Expanded(
                child: ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  itemCount: list.length + (typing && support ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    if (typing && support && i == 0) return const _Typing();
                    final m = list[i - (typing && support ? 1 : 0)];
                    return switch (m.kind) {
                      _Kind.system => _SystemBubble(m.text),
                      _Kind.mine => _MineBubble(m, maxWidth: box.maxWidth * .7),
                      _Kind.other =>
                        _OtherBubble(m, maxWidth: box.maxWidth * .75, onMore: support ? null : () => _openMenu(m.name)),
                    };
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Z.line)), gradient: Z.footerBar),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _draft,
                      style: outfit(15, c: Z.cream),
                      cursorColor: Z.goldHi,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _post,
                      decoration: fieldDeco(
                        hint: support ? 'Describe your issue…' : 'Say something to the room…',
                        radius: 24,
                      ).copyWith(hintStyle: outfit(15, c: Z.faint), contentPadding: const EdgeInsets.fromLTRB(16, 13, 16, 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Press(
                    label: 'Send message',
                    onTap: () => _post(_draft.text),
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Z.rimBright, width: 2),
                        gradient: const LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE0303B), Color(0xFF9A0A14)]),
                        boxShadow: [bs(0, 0, 12, const Color(0x59FFAA3C))],
                      ),
                      child: const Ico(P.send, size: 20, color: Z.goldHi),
                    ),
                  ),
                ]),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C140B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Z.cardBorder),
          ),
          child: Text('Zoya Support is typing…', style: outfit(13, c: Z.muted)),
        ),
      );
}

class _SystemBubble extends StatelessWidget {
  const _SystemBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: FractionallySizedBox(
          widthFactor: .8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x80E2B04F)),
              gradient: const LinearGradient(colors: [Color(0x2EE2B04F), Color(0x0FE2B04F)]),
            ),
            child: Text(text, textAlign: TextAlign.center, style: outfit(13, w: FontWeight.w600, c: Z.goldHi)),
          ),
        ),
      );
}

class _MineBubble extends StatelessWidget {
  const _MineBubble(this.m, {required this.maxWidth});
  final _Msg m;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(color: const Color(0xFFE0A52E)),
                gradient: const LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB0121C), Color(0xFF7A050C)]),
              ),
              child: Text(m.text, style: outfit(15, c: const Color(0xFFFFF4DC), h: 1.35)),
            ),
            const SizedBox(height: 3),
            Text(m.time, style: outfit(11, c: Z.faint)),
          ]),
        ),
      );
}

class _OtherBubble extends StatelessWidget {
  const _OtherBubble(this.m, {required this.maxWidth, this.onMore});
  final _Msg m;
  final double maxWidth;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: m.color),
              child: Text(m.name.substring(0, 2).toUpperCase(), style: outfit(11, w: FontWeight.w800, c: Z.ink)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(m.name, style: outfit(12, w: FontWeight.w700, c: m.color)),
                  const SizedBox(width: 6),
                  Text(m.time, style: outfit(12, c: Z.faint)),
                  if (onMore != null)
                    Press(
                      label: 'More options for ${m.name}',
                      onTap: onMore,
                      child: const SizedBox(
                        width: 28,
                        height: 22,
                        child: Center(
                          child: RawIco(
                              '<g fill="#8f8576"><circle cx="5" cy="12" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="19" cy="12" r="2"/></g>',
                              size: 16),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C140B),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                    ),
                    border: Border.all(color: Z.cardBorder),
                  ),
                  child: Text(m.text, style: outfit(15, h: 1.35)),
                ),
              ]),
            ),
          ]),
        ),
      );
}

class _MessageMenu extends StatefulWidget {
  const _MessageMenu({required this.name, required this.onMute, required this.onReport});
  final String name;
  final VoidCallback onMute;
  final VoidCallback onReport;

  @override
  State<_MessageMenu> createState() => _MessageMenuState();
}

class _MessageMenuState extends State<_MessageMenu> {
  bool report = false;

  Widget _btn(String label, VoidCallback onTap, {Color color = Z.text, Color border = Z.cardBorder, bool left = false}) => Press(
        onTap: onTap,
        child: Container(
          height: left ? 50 : 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: left ? Alignment.centerLeft : Alignment.center,
          decoration: BoxDecoration(
            color: Z.card,
            borderRadius: BorderRadius.circular(left ? 14 : 16),
            border: Border.all(color: border),
          ),
          child: Text(label, style: outfit(left ? 15 : 16, w: left ? FontWeight.w600 : FontWeight.w700, c: color)),
        ),
      );

  @override
  Widget build(BuildContext context) => Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .92),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF150D07),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Z.border, width: 2)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: const Color(0xFF4A3A1E), borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 10),
                if (!report) ...[
                  Text(widget.name, textAlign: TextAlign.center, style: outfit(14, c: Z.muted)),
                  const SizedBox(height: 10),
                  _btn('Mute ${widget.name}', widget.onMute),
                  const SizedBox(height: 10),
                  _btn('Report message', () => setState(() => report = true),
                      color: Z.coral, border: const Color(0x73FF6B5B)),
                ] else ...[
                  Text('Why are you reporting this?', style: outfit(17, w: FontWeight.w800, c: Z.cream)),
                  for (final r in const ['Spam or scam', 'Harassment or hate', 'Inappropriate content', 'Something else']) ...[
                    const SizedBox(height: 8),
                    _btn(r, widget.onReport, left: true),
                  ],
                ],
                const SizedBox(height: 10),
                GhostButton('Cancel', height: 50, color: Z.gold, borderColor: Z.chip, onTap: () => Navigator.pop(context)),
                ]),
              ),
            ),
          ),
        ),
      );
}
