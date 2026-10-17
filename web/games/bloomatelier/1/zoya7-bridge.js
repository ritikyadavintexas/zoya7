/*
 * Zoya7 game bridge, v1. Load it before the game's own scripts:
 *
 *     <script src="zoya7-bridge.js"></script>
 *
 * Inside the Zoya7 app it talks to the app, which holds the player's coins and
 * draws the result of every round. Opened on its own (from any local web
 * server) it runs a demo with pretend coins and the same payout rule, so the
 * game can be built and tested anywhere. Zoya7 puts its own copy of this file
 * in the game when it is uploaded: don't change it, build on its API.
 *
 *   Zoya7.init()                  -> Promise<session>   call once, first
 *   Zoya7.play({option, currency, bet}) -> Promise<round>  one round; the app decides it
 *   Zoya7.ready()                 the first frame is drawn (the app drops its loading cover)
 *   Zoya7.exit()                  back to the Zoya7 lobby
 *   Zoya7.buyCoins()              the Gold Coin store (GC only; never for DC)
 *   Zoya7.on(event, fn)           'balance' {GC, DC} · 'sound' {effects, music} · 'pause' · 'resume'
 */
(function () {
  'use strict';
  var VERSION = 1;
  var RTP = 0.95;
  var listeners = {};
  var pending = {};
  var seq = 0;
  var mode = null; // 'host' (in Zoya7) or 'demo'
  var session = null;
  var initPromise = null;
  var demo = null;

  // Zoya7 runs games in a sandbox without storage; an in-memory one keeps a game that uses it working.
  function memoryStorage() {
    var d = {};
    return {
      getItem: function (k) { return Object.prototype.hasOwnProperty.call(d, k) ? d[k] : null; },
      setItem: function (k, v) { d[k] = String(v); },
      removeItem: function (k) { delete d[k]; },
      clear: function () { d = {}; },
      key: function (i) { return Object.keys(d)[i] || null; },
      get length() { return Object.keys(d).length; }
    };
  }
  ['localStorage', 'sessionStorage'].forEach(function (name) {
    try { window[name].getItem('zoya7'); } catch (e) {
      try { Object.defineProperty(window, name, { value: memoryStorage(), configurable: true }); } catch (e2) { /* left as is */ }
    }
  });

  function fail(code, message) {
    var e = new Error(message || code);
    e.code = code;
    return e;
  }

  function emit(type, data) {
    (listeners[type] || []).slice().forEach(function (fn) {
      try { fn(data); } catch (e) { console.error(e); }
    });
  }

  window.addEventListener('message', function (e) {
    var m = e.data;
    if (e.source !== window.parent || !m || m.zoya7 !== VERSION) return;
    if (m.re != null && pending[m.re]) {
      var p = pending[m.re];
      delete pending[m.re];
      if (m.error) p.reject(fail(m.error.code, m.error.message));
      else p.resolve(m.data);
    } else if (m.event) {
      if (m.event === 'balance' && session) session.balances = m.data;
      if (m.event === 'sound' && session) session.sound = m.data;
      emit(m.event, m.data);
    }
  });

  document.addEventListener('visibilitychange', function () { emit(document.hidden ? 'pause' : 'resume', {}); });

  function ask(type, data, timeoutMs) {
    return new Promise(function (resolve, reject) {
      var id = ++seq;
      pending[id] = { resolve: resolve, reject: reject };
      window.parent.postMessage({ zoya7: VERSION, id: id, type: type, data: data || {} }, '*');
      if (timeoutMs) {
        setTimeout(function () {
          if (!pending[id]) return;
          delete pending[id];
          reject(fail('timeout', 'Zoya7 did not answer'));
        }, timeoutMs);
      }
    });
  }

  function tell(type) {
    if (mode === 'host') window.parent.postMessage({ zoya7: VERSION, type: type, data: {} }, '*');
  }

  // ── The payout rule (the same in the app) ──────────────────────────────────
  // Every win gets its share of the payback (equal unless the game sets
  // "share"), so a 30x win comes 15 times less often than a 2x win; the rest
  // of the time the round is a no-win.
  function chances(outcomes, rtp) {
    var wins = outcomes.filter(function (o) { return o.multiplier > 0; });
    var losses = outcomes.length - wins.length;
    if (!wins.length || !losses) return null;
    var shares = wins.reduce(function (a, o) { return a + o.share; }, 0);
    var hit = 0;
    var p = outcomes.map(function (o) {
      if (o.multiplier <= 0) return 0;
      var x = rtp * (o.share / shares) / o.multiplier;
      hit += x;
      return x;
    });
    if (hit > 0.95) return null;
    return p.map(function (x, i) { return outcomes[i].multiplier > 0 ? x : (1 - hit) / losses; });
  }

  function money(currency, v) {
    return currency === 'GC' ? Math.round(v) : Math.round(v * 100) / 100;
  }

  // ── Demo: the game opened on its own ───────────────────────────────────────
  function startDemo() {
    return fetch('game.json', { cache: 'no-store' })
      .then(function (r) { return r.json(); })
      .catch(function () { throw fail('demo', 'Open the game from a local web server (e.g. python3 -m http.server) so it can read game.json'); })
      .then(function (g) {
        var options = (g.options || []).map(function (o) {
          var outs = (o.outcomes || []).map(function (x) {
            return { id: x.id, label: x.label || x.id, multiplier: +x.multiplier || 0, share: x.share == null ? 1 : +x.share };
          });
          var p = chances(outs, RTP);
          if (!p) throw fail('paytable', 'Option "' + o.id + '": needs a 0x outcome and wins big enough to pay back 95%');
          return {
            id: o.id,
            label: o.label || o.id,
            outcomes: outs.map(function (x, i) { return { id: x.id, label: x.label, multiplier: x.multiplier, chance: p[i] }; })
          };
        });
        if (!options.length) throw fail('paytable', 'game.json has no options');
        demo = { balances: { GC: 100000, DC: 100 }, round: 0, last: 0 };
        mode = 'demo';
        return {
          demo: true,
          currency: 'GC',
          balances: { GC: demo.balances.GC, DC: demo.balances.DC },
          bets: { GC: [100, 200, 500, 1000, 2000, 5000, 10000], DC: [0.2, 0.5, 1, 2, 5, 10] },
          bet: { GC: 100, DC: 0.2 },
          options: options,
          rtp: RTP,
          sound: { effects: true, music: true },
          player: { name: 'Demo player' },
          reducedMotion: !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches)
        };
      });
  }

  function demoPlay(req) {
    var option = session.options.filter(function (o) { return o.id === req.option; })[0];
    if (!option) return Promise.reject(fail('option', 'No bet option "' + req.option + '"'));
    if (session.bets[req.currency] == null) return Promise.reject(fail('currency', 'Currency is GC or DC'));
    if (session.bets[req.currency].indexOf(req.bet) < 0) return Promise.reject(fail('bet', 'Bet is one of session.bets'));
    if (demo.balances[req.currency] < req.bet) return Promise.reject(fail('balance', 'Not enough coins'));
    var r = Math.random();
    var pick = option.outcomes[option.outcomes.length - 1];
    for (var i = 0; i < option.outcomes.length; i++) {
      r -= option.outcomes[i].chance;
      if (r < 0) { pick = option.outcomes[i]; break; }
    }
    var win = money(req.currency, req.bet * pick.multiplier);
    demo.balances[req.currency] = money(req.currency, demo.balances[req.currency] - req.bet + win);
    return Promise.resolve({
      round: 'demo-' + (++demo.round),
      option: option.id,
      outcome: pick.id,
      label: pick.label,
      multiplier: pick.multiplier,
      currency: req.currency,
      bet: req.bet,
      win: win,
      balances: { GC: demo.balances.GC, DC: demo.balances.DC }
    });
  }

  window.Zoya7 = {
    version: VERSION,

    /** The session: balances, bet steps, pay tables (with each outcome's chance), sound settings. */
    init: function () {
      if (initPromise) return initPromise;
      var framed = window.parent !== window;
      var start = framed
        ? ask('init', { bridge: VERSION }, 2500).then(function (s) { mode = 'host'; return s; }, startDemo)
        : startDemo();
      initPromise = start.then(function (s) { session = s; return s; });
      return initPromise;
    },

    /**
     * Plays one round: the bet is taken, the result drawn and any win paid, all at once.
     * Resolves with {round, option, outcome, label, multiplier, currency, bet, win, balances};
     * rejects with an Error whose .code is 'balance', 'bet', 'option', 'currency', 'closed',
     * 'signedout', 'busy' or 'timeout'. Show exactly this outcome; never another.
     */
    play: function (req) {
      if (!session) return Promise.reject(fail('init', 'Call Zoya7.init() first'));
      req = req || {};
      var r = { option: req.option || session.options[0].id, currency: req.currency || session.currency, bet: +req.bet };
      var p = mode === 'host' ? ask('play', r, 15000) : demoPlay(r);
      return p.then(function (round) { session.balances = round.balances; return round; });
    },

    ready: function () { tell('ready'); },

    exit: function () {
      if (mode === 'host') tell('exit');
      else if (window.history.length > 1) window.history.back();
    },

    buyCoins: function () { tell('buy'); },

    on: function (type, fn) { (listeners[type] = listeners[type] || []).push(fn); },

    off: function (type, fn) { listeners[type] = (listeners[type] || []).filter(function (f) { return f !== fn; }); },

    get session() { return session; },
    get demo() { return mode === 'demo'; }
  };
})();
