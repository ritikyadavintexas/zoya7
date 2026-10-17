import 'dart:async';

import 'package:flutter/material.dart';

import '../assets.dart';
import '../icons.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

// ── Splash / loading ─────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  int pct = 0;
  Timer? _timer;
  late final AnimationController _glow =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      setState(() => pct = (pct + 4).clamp(0, 100));
      if (pct >= 100) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 350), () {
          // Only advance when the splash is on top (a deep link may have opened a page over it).
          if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
            Nav.replace(AppScope.read(context).signedIn ? R.home : R.welcome);
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final a in A.all) {
      precacheImage(AssetImage(a), context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glow.dispose();
    super.dispose();
  }

  String get status => pct < 40
      ? 'Polishing the reels…'
      : pct < 80
          ? 'Loading games…'
          : pct < 100
              ? 'Almost there…'
              : 'Ready!';

  @override
  Widget build(BuildContext context) {
    return ZPage(
      color: Z.inkDeep,
      gradient: ellipseGradient(
          cx: .5, cy: .45, rx: .8, ry: .5, colors: const [Color(0xFF3A2209), Z.inkDeep], stops: const [0, .75]),
      child: Stack(children: [
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _glow,
              builder: (_, child) => DecoratedBox(
                decoration: BoxDecoration(boxShadow: [
                  bs(0, 0, 12 + 16 * _glow.value, Color.fromRGBO(255, 190, 70, .12 + .18 * _glow.value)),
                ]),
                child: child,
              ),
              child: Image.asset(A.logo, width: 220, height: 90, fit: BoxFit.contain, semanticLabel: 'Zoya7'),
            ),
            const SizedBox(height: 14),
            Text('Play. Win. Shine.', style: playfair(22, c: const Color(0xFFF2D28A))),
            const SizedBox(height: 30),
            SizedBox(
              width: 240,
              child: Column(children: [
                Semantics(
                  label: 'Loading',
                  value: '$pct%',
                  child: GoldBar(value: pct / 100, height: 10, border: Z.chip),
                ),
                const SizedBox(height: 10),
                Text(status, style: outfit(14, c: Z.tabOff)),
              ]),
            ),
          ]),
        ),
        const Positioned(
          left: 16,
          right: 16,
          bottom: 14,
          child: ResponsibleFooter(parts: ['Play responsibly · No purchase necessary'], color: Z.muted2, badge: 26),
        ),
      ]),
    );
  }
}

// ── Welcome ──────────────────────────────────────────────────────────────────

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Z.inkDeep,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ellipseGradient(
              cx: 1, cy: .5, rx: .6, ry: .9, colors: const [Color(0xFF2A1606), Z.inkDeep], stops: const [0, .7]),
        ),
        child: LayoutBuilder(builder: (context, box) {
          final heroW = (box.maxWidth * .52).clamp(0.0, 640.0);
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // The art runs under the notch / rounded corner, so no inset on this side.
            SizedBox(
              width: heroW,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Colors.black, Colors.black, Colors.transparent],
                  stops: [0, .8, 1],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: Image.asset(A.welcomeHero,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -.45),
                    semanticLabel: 'Zoya7 — Play. Win. Shine. Premium games, real excitement.'),
              ),
            ),
            Expanded(
              child: SafeArea(
                left: false,
                child: DefaultTextStyle(
                  style: outfit(15),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 28, 16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(children: [
                          CtaButton(
                            'LOG IN',
                            height: 60,
                            fontSize: 22,
                            ls: .02,
                            trailing: const StrokeIco(P.forward, size: 20, color: Z.ctaText),
                            onTap: () => Nav.push(R.login),
                          ),
                          const SizedBox(height: 14),
                          Text('Play with the player ID your agent gives you.',
                              textAlign: TextAlign.center, style: outfit(15, c: Z.body, h: 1.35)),
                          const SizedBox(height: 18),
                          const ResponsibleFooter(parts: ['Play Responsibly.', 'Terms & Conditions Apply.']),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}

// ── Log in / Sign up ─────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Players log in with the player ID (or username) and password made for
/// them in the admin panel. There is no sign-up and no guest play.
class _LoginScreenState extends State<LoginScreen> {
  final _who = TextEditingController();
  final _pw = TextEditingController();
  bool showPw = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    _who.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (busy) return;
    final s = AppScope.read(context);
    setState(() => busy = true);
    final e = await s.logIn(_who.text, _pw.text);
    if (!mounted) return;
    setState(() => busy = false);
    if (e != null) {
      setState(() => error = e);
      return;
    }
    s.casino.settings.dailyBonus ? Nav.homeWithBonus() : Nav.reset(R.home);
  }

  @override
  Widget build(BuildContext context) {
    final kicked = AppScope.of(context).kickedOut;
    final who = ZField(label: 'PLAYER ID OR USERNAME', hint: 'Z7-123456', controller: _who, action: TextInputAction.next);
    final password = ZField(
      label: 'PASSWORD',
      hint: '••••••••',
      controller: _pw,
      obscure: !showPw,
      action: TextInputAction.go,
      onSubmitted: (_) => _submit(),
      suffix: Semantics(
        label: showPw ? 'Hide password' : 'Show password',
        button: true,
        child: IconButton(
          onPressed: () => setState(() => showPw = !showPw),
          icon: const RawIco(
              '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" fill="none" stroke="#c9a35a" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="12" r="3" fill="none" stroke="#c9a35a" stroke-width="2"/>',
              size: 22),
        ),
      ),
    );
    return ZPage(
      gradient: Z.pageGlow(ry: .5, rx: .7),
      child: Panes(
        sideFraction: .4,
        minSide: 210,
        // Brand and how to get an ID on the left; the form on the right.
        side: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 10),
          child: Column(children: [
            const Align(alignment: Alignment.centerLeft, child: BackBtn()),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Image.asset(A.logo,
                      height: (box.maxHeight * .3).clamp(40.0, 82.0), fit: BoxFit.contain, semanticLabel: 'Zoya7'),
                  const SizedBox(height: 8),
                  Text('Welcome back — your seat is waiting', textAlign: TextAlign.center, style: outfit(14, c: Z.body)),
                  const SizedBox(height: 6),
                  Text('No player ID yet? Your agent makes one for you.',
                      textAlign: TextAlign.center, style: outfit(13, c: Z.muted2, h: 1.35)),
                ]),
              ),
            ),
            const ResponsibleFooter(parts: ['Play Responsibly.', 'No purchase necessary.'], badge: 24),
          ]),
        ),
        main: LayoutBuilder(builder: (context, box) {
          final pairs = box.maxWidth >= 300;
          // Near the top, not centred: a phone's keyboard covers the lower
          // part of the screen, and the boxes stay above it (Return logs in).
          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(6, 10, 20, 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: Text('LOG IN', style: outfit(20, w: FontWeight.w800, ls: .08, c: Z.goldHi))),
                  ]),
                  const SizedBox(height: 10),
                  if (pairs)
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: who),
                      const SizedBox(width: 10),
                      Expanded(child: password),
                    ])
                  else ...[
                    who,
                    const SizedBox(height: 10),
                    password,
                  ],
                  const SizedBox(height: 6),
                  Text(error ?? kicked ?? 'Forgot your password? Your agent can reset it.',
                      style: outfit(13, w: FontWeight.w600, c: error != null || kicked != null ? Z.coral : Z.muted2)),
                  const SizedBox(height: 10),
                  CtaButton(busy ? 'LOGGING IN…' : 'LOG IN', height: 46, fontSize: 18, ls: .03, onTap: _submit),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Forgot password (3 steps + done) ─────────────────────────────────────────

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int step = 0;
  int wait = 0;
  Timer? _timer;
  final _email = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  void _startWait() {
    _timer?.cancel();
    setState(() => wait = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => wait = (wait - 1).clamp(0, 30));
      if (wait == 0) t.cancel();
    });
  }

  void _next() {
    if (step == 0) _startWait();
    setState(() => step = (step + 1).clamp(0, 3));
  }

  String get email => _email.text.trim().isEmpty ? 'you@example.com' : _email.text.trim();

  @override
  Widget build(BuildContext context) {
    const intros = [
      ('Forgot your password?', "Enter the email on your account and we'll send you a 6-digit code."),
      ('Check your email', ''),
      ('Set a new password', 'Pick something you have not used here before.'),
      ('All done', ''),
    ];
    final (title, intro) = intros[step];
    return ZPage(
      gradient: Z.pageGlow(ry: .5, rx: .7),
      child: Panes(
        sideFraction: .4,
        side: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              BackBtn(
                label: 'Back to log in',
                onTap: () => step > 0 && step < 3 ? setState(() => step--) : Nav.back(),
              ),
              const SizedBox(width: 12),
              Text('STEP ${step.clamp(0, 2) + 1} OF 3', style: outfit(13, w: FontWeight.w700, ls: .12, c: Z.label)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: i <= step ? Z.progress : null,
                      color: i <= step ? null : const Color(0xFF2A1D0E),
                    ),
                  ),
                ),
              ],
            ]),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (step < 3) _title(title),
                  const SizedBox(height: 10),
                  if (step == 1)
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'We sent a 6-digit code to '),
                        TextSpan(text: email, style: outfit(15, w: FontWeight.w700, c: Z.cream)),
                        const TextSpan(text: '.'),
                      ]),
                      style: outfit(15, c: Z.body, h: 1.5),
                    )
                  else if (intro.isNotEmpty)
                    Text(intro, style: outfit(15, c: Z.body, h: 1.5)),
                ]),
              ),
            ),
            Text('Still stuck? Your agent can reset your password.', style: outfit(14, w: FontWeight.w600, c: Z.muted)),
          ]),
        ),
        main: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 14, 24, 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(key: ValueKey(step), child: _step()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String t) =>
      Text(t, style: outfit(26, w: FontWeight.w800, c: Z.cream, h: 1.15), textAlign: TextAlign.left);

  Widget _step() {
    const gap = SizedBox(height: 14);
    switch (step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ZField(label: 'EMAIL', hint: 'you@example.com', controller: _email, keyboard: TextInputType.emailAddress),
          gap,
          CtaButton('SEND CODE', onTap: _next),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _CodeBoxes(),
          gap,
          CtaButton('VERIFY CODE', onTap: _next),
          const SizedBox(height: 8),
          Center(
            child: Press(
              onTap: wait > 0 ? null : _startWait,
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Text(wait > 0 ? 'Resend code in ${wait}s' : 'Resend code',
                      style: outfit(15, w: FontWeight.w600, c: wait > 0 ? Z.faint : Z.gold)),
                ),
              ),
            ),
          ),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const ZField(label: 'NEW PASSWORD', hint: 'At least 8 characters', obscure: true),
          gap,
          const ZField(label: 'CONFIRM PASSWORD', hint: 'Type it again', obscure: true),
          gap,
          for (final r in const ['8+ characters', 'One number and one letter'])
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text('•  $r', style: outfit(14, c: Z.muted, h: 1.5)),
            ),
          gap,
          CtaButton('SAVE PASSWORD', onTap: _next),
        ]);
      default:
        return Padding(
          padding: EdgeInsets.zero,
          child: Column(children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x1F3FD17A),
                border: Border.all(color: Z.green, width: 3),
                boxShadow: [bs(0, 0, 24, const Color(0x593FD17A))],
              ),
              child: const StrokeIco(P.check, size: 40, color: Z.green),
            ),
            const SizedBox(height: 14),
            Text('Password updated', style: outfit(26, w: FontWeight.w800, c: Z.cream)),
            const SizedBox(height: 16),
            Text('You can now log in with your new password.',
                textAlign: TextAlign.center, style: outfit(15, c: Z.body, h: 1.5)),
            const SizedBox(height: 14),
            CtaButton('BACK TO LOG IN', onTap: () => Nav.back()),
          ]),
        );
    }
  }
}

class _CodeBoxes extends StatefulWidget {
  const _CodeBoxes();

  @override
  State<_CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<_CodeBoxes> {
  final _nodes = List.generate(6, (_) => FocusNode());
  final _ctrls = List.generate(6, (_) => TextEditingController());

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < 6; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              label: 'Digit ${i + 1}',
              child: SizedBox(
                height: 58,
                child: TextField(
                  controller: _ctrls[i],
                  focusNode: _nodes[i],
                  autofocus: i == 0,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: outfit(24, w: FontWeight.w800, c: Z.goldHi),
                  cursorColor: Z.goldHi,
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) _nodes[i + 1].requestFocus();
                    if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
                  },
                  decoration: fieldDeco(radius: 12, left: 0, right: 0).copyWith(
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Z.chip, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Z.border, width: 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ]);
}

// ── No connection ────────────────────────────────────────────────────────────

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  bool busy = false;
  bool failed = false;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ZPage(
      gradient: ellipseGradient(
          cx: .3, cy: .5, rx: .6, ry: .8, colors: const [Color(0xFF2E1A08), Z.ink], stops: const [0, .75]),
      child: Panes(
        sideFraction: .38,
        side: Center(
          child: Container(
            width: 140,
            height: 140,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Z.goldFrame,
              boxShadow: [bs(0, 0, 30, const Color(0x4DE2B04F))],
            ),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: Z.darkWell()),
              alignment: Alignment.center,
              child: const RawIco(
                '<g fill="none" stroke="#f2c869" stroke-width="2" stroke-linecap="round"><path d="M2 8.5a15 15 0 0 1 20 0"/><path d="M5.5 12a10 10 0 0 1 13 0"/><path d="M9 15.5a5 5 0 0 1 6 0"/><path d="M3 3l18 18" stroke="#ff6b5b"/></g><circle cx="12" cy="19" r="1.2" fill="#f2c869"/>',
                size: 64,
              ),
            ),
          ),
        ),
        main: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(6, 16, 28, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("You're offline", style: outfit(28, w: FontWeight.w800, c: Z.cream)),
                const SizedBox(height: 10),
                Text(
                  "We can't reach the Zoya7 tables right now. Your coins and progress are safe — check your connection and try again.",
                  style: outfit(15, c: Z.body, h: 1.5),
                ),
                if (failed && !busy) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x1AFF6B5B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x66FF6B5B)),
                    ),
                    child: Text('Still no connection. Try switching Wi-Fi or mobile data.',
                        style: outfit(14, c: const Color(0xFFFFB0A6))),
                  ),
                ],
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: CtaButton(
                      busy ? 'RECONNECTING…' : 'TRY AGAIN',
                      height: 54,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 3, color: Z.ctaText, backgroundColor: Color(0x59FBD88A)),
                            )
                          : null,
                      onTap: busy
                          ? null
                          : () {
                              setState(() => busy = true);
                              _t = Timer(const Duration(milliseconds: 1500), () {
                                if (mounted) {
                                  setState(() {
                                    busy = false;
                                    failed = true;
                                  });
                                }
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  LinkText('Back to lobby', w: FontWeight.w600, onTap: () => Nav.tab(AppTab.home)),
                ]),
                const SizedBox(height: 14),
                Text(
                  'Spins in progress are settled on our servers and appear in your wallet history once you reconnect.',
                  style: outfit(13, c: Z.muted2),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
