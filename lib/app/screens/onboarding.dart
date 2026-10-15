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
          if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Nav.replace(R.welcome);
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
              child: Image.asset(A.logo, width: 260, height: 107, fit: BoxFit.contain, semanticLabel: 'Zoya7'),
            ),
            const SizedBox(height: 22),
            Text('Play. Win. Shine.', style: playfair(24, c: const Color(0xFFF2D28A))),
            const SizedBox(height: 52),
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
          bottom: 28,
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
    return ZPage(
      color: Z.inkDeep,
      gradient: ellipseGradient(
          cx: .5, cy: 1, rx: .9, ry: .4, colors: const [Color(0xFF2A1606), Z.inkDeep], stops: const [0, .7]),
      child: LayoutBuilder(builder: (context, box) {
        final heroH = (box.maxHeight * .6).clamp(320.0, 530.0);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Column(children: [
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black, Colors.transparent],
                  stops: [0, .78, 1],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: SizedBox(
                  height: heroH,
                  width: double.infinity,
                  child: OverflowBox(
                    maxWidth: box.maxWidth + 40,
                    child: Image.asset(A.welcomeHero,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        width: box.maxWidth + 40,
                        height: heroH,
                        semanticLabel: 'Zoya7 — Play. Win. Shine. Premium games, real excitement.'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 14, 30, 0),
                child: Column(children: [
                  CtaButton(
                    'GET STARTED',
                    height: 64,
                    fontSize: 24,
                    ls: .02,
                    trailing: const StrokeIco(P.forward, size: 20, color: Z.ctaText),
                    onTap: () => Nav.push(R.signup),
                  ),
                  const SizedBox(height: 16),
                  FractionallySizedBox(
                    widthFactor: .82,
                    child: GhostButton('LOG IN', fontSize: 18, onTap: () => Nav.push(R.login)),
                  ),
                  const SizedBox(height: 10),
                  LinkText('Continue as Guest', size: 17, underline: true, onTap: () {
                    AppScope.read(context).signIn(asGuest: true);
                    Nav.reset(R.home, AppTab.home);
                  }),
                ]),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 26),
                child: ResponsibleFooter(parts: ['Play Responsibly.', 'Terms & Conditions Apply.']),
              ),
            ]),
          ),
        );
      }),
    );
  }
}

// ── Log in / Sign up ─────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.signup = false});
  final bool signup;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late bool signup = widget.signup;
  bool showPw = false;
  bool agreed = false;

  void _submit() {
    if (signup && !agreed) {
      showToast(context, 'Please confirm you are 18+ and agree to the Terms');
      return;
    }
    AppScope.read(context).signIn();
    Nav.homeWithBonus();
  }

  @override
  Widget build(BuildContext context) {
    return ZPage(
      gradient: Z.pageGlow(ry: .34),
      child: Column(children: [
        SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              const BackBtn(),
              const Spacer(),
              Press(
                onTap: () => Nav.push(R.chat, 'support'),
                child: Row(children: [
                  const Ico(P.chat, size: 18),
                  const SizedBox(width: 6),
                  Text('Need help?', style: outfit(13, w: FontWeight.w600, c: Z.gold)),
                ]),
              ),
            ]),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 24),
            child: Column(children: [
              Image.asset(A.logo, width: 190, height: 78, fit: BoxFit.contain, semanticLabel: 'Zoya7'),
              const SizedBox(height: 8),
              Text(
                signup ? 'Create your account and claim your welcome bonus' : 'Welcome back — your seat is waiting',
                textAlign: TextAlign.center,
                style: outfit(15, c: Z.body),
              ),
              const SizedBox(height: 18),
              SegTabs(
                labels: const ['LOG IN', 'SIGN UP'],
                index: signup ? 1 : 0,
                height: 44,
                fontSize: 15,
                onChanged: (i) => setState(() => signup = i == 1),
              ),
              const SizedBox(height: 18),
              if (signup) ...[
                const ZField(label: 'USERNAME', hint: 'Choose a player name'),
                const SizedBox(height: 14),
              ],
              const ZField(label: 'EMAIL', hint: 'you@example.com', keyboard: TextInputType.emailAddress),
              const SizedBox(height: 14),
              ZField(
                label: 'PASSWORD',
                hint: '••••••••',
                obscure: !showPw,
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
              ),
              if (!signup)
                Align(
                  alignment: Alignment.centerRight,
                  child: LinkText('Forgot password?', size: 14, onTap: () => Nav.push(R.forgot)),
                ),
              if (signup) ...[
                const SizedBox(height: 14),
                Press(
                  onTap: () => setState(() => agreed = !agreed),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _Check(on: agreed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('I am 18 or older and agree to the Terms & Conditions and Privacy Policy.',
                          style: outfit(13, c: Z.body, h: 1.4)),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 18),
              CtaButton(signup ? 'CREATE ACCOUNT' : 'LOG IN', height: 60, fontSize: 21, ls: .03, onTap: _submit),
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(child: Divider(color: Z.line35, height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OR CONTINUE WITH', style: outfit(12, c: Z.muted2, ls: .08)),
                ),
                const Expanded(child: Divider(color: Z.line35, height: 1)),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _SocialBtn('Google', onTap: _socialIn)),
                const SizedBox(width: 10),
                Expanded(child: _SocialBtn('Apple', onTap: _socialIn)),
              ]),
              const SizedBox(height: 12),
              LinkText('Continue as Guest', underline: true, onTap: () {
                AppScope.read(context).signIn(asGuest: true);
                Nav.reset(R.home, AppTab.home);
              }),
            ]),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 22),
          child: ResponsibleFooter(parts: ['Play Responsibly.', 'No purchase necessary.'], badge: 26),
        ),
      ]),
    );
  }

  void _socialIn() {
    AppScope.read(context).signIn();
    Nav.homeWithBonus();
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => Semantics(
        checked: on,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: on ? Z.ghostBorder : Z.field,
            border: Border.all(color: on ? Z.ghostBorder : Z.chip, width: 1.5),
          ),
          child: on ? const StrokeIco(P.check, size: 16, color: Z.brown, width: 3.2) : null,
        ),
      );
}

class _SocialBtn extends StatelessWidget {
  const _SocialBtn(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        label: 'Continue with $label',
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Z.chip, width: 1.5),
            color: Z.field,
          ),
          child: Text(label, style: outfit(15, w: FontWeight.w600)),
        ),
      );
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
    return ZPage(
      gradient: Z.pageGlow(ry: .34),
      child: Column(children: [
        SizedBox(
          height: 62,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              BackBtn(
                label: 'Back to log in',
                onTap: () => step > 0 && step < 3 ? setState(() => step--) : Nav.back(),
              ),
              Expanded(
                child: Text('STEP ${step.clamp(0, 2) + 1} OF 3',
                    textAlign: TextAlign.center, style: outfit(13, w: FontWeight.w700, ls: .12, c: Z.label)),
              ),
              const SizedBox(width: 40),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Row(children: [
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
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(key: ValueKey(step), child: _step()),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: LinkText('Still stuck? Chat with support',
              size: 14, w: FontWeight.w600, onTap: () => Nav.push(R.chat, 'support')),
        ),
      ]),
    );
  }

  Widget _title(String t) =>
      Text(t, style: outfit(28, w: FontWeight.w800, c: Z.cream), textAlign: TextAlign.left);

  Widget _step() {
    const gap = SizedBox(height: 18);
    switch (step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('Forgot your password?'),
          gap,
          Text("Enter the email on your account and we'll send you a 6-digit code.",
              style: outfit(16, c: Z.body, h: 1.5)),
          gap,
          ZField(label: 'EMAIL', hint: 'you@example.com', controller: _email, keyboard: TextInputType.emailAddress),
          gap,
          CtaButton('SEND CODE', onTap: _next),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('Check your email'),
          gap,
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(text: email, style: outfit(16, w: FontWeight.w700, c: Z.cream)),
              const TextSpan(text: '.'),
            ]),
            style: outfit(16, c: Z.body, h: 1.5),
          ),
          gap,
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
          _title('Set a new password'),
          gap,
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
          padding: const EdgeInsets.only(top: 40),
          child: Column(children: [
            Container(
              width: 100,
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x1F3FD17A),
                border: Border.all(color: Z.green, width: 3),
                boxShadow: [bs(0, 0, 24, const Color(0x593FD17A))],
              ),
              child: const StrokeIco(P.check, size: 48, color: Z.green),
            ),
            const SizedBox(height: 16),
            Text('Password updated', style: outfit(28, w: FontWeight.w800, c: Z.cream)),
            const SizedBox(height: 16),
            Text('You can now log in with your new password.',
                textAlign: TextAlign.center, style: outfit(16, c: Z.body, h: 1.5)),
            const SizedBox(height: 16),
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
          cx: .5, cy: .38, rx: .9, ry: .45, colors: const [Color(0xFF2E1A08), Z.ink], stops: const [0, .75]),
      child: Column(children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Column(children: [
                Container(
                  width: 120,
                  height: 120,
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
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text("You're offline", style: outfit(28, w: FontWeight.w800, c: Z.cream)),
                const SizedBox(height: 16),
                Text(
                  "We can't reach the Zoya7 tables right now. Your coins and progress are safe — check your connection and try again.",
                  textAlign: TextAlign.center,
                  style: outfit(16, c: Z.body, h: 1.5),
                ),
                if (failed && !busy) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x1AFF6B5B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x66FF6B5B)),
                    ),
                    child: Text('Still no connection. Try switching Wi-Fi or mobile data.',
                        textAlign: TextAlign.center, style: outfit(14, c: const Color(0xFFFFB0A6))),
                  ),
                ],
                const SizedBox(height: 26),
                CtaButton(
                  busy ? 'RECONNECTING…' : 'TRY AGAIN',
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
                const SizedBox(height: 10),
                LinkText('Back to lobby', w: FontWeight.w600, onTap: () => Nav.tab(AppTab.home)),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 0, 30, 28),
          child: Text(
            'Spins in progress are settled on our servers and appear in your wallet history once you reconnect.',
            textAlign: TextAlign.center,
            style: outfit(13, c: Z.muted2),
          ),
        ),
      ]),
    );
  }
}
