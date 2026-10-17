// Zoya7 sound: effects and music through one Web Audio context (lib/app/sound_out_web.dart
// drives it). Browsers keep sound off until the page is touched, so every tap, click or key
// (re)starts the context; iOS also needs a sound started inside that first tap.
(function () {
  var AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) return;
  var ctx = null, sfxBus, musicBus, buffers = {}, current = null, paused = false, unlocked = false;

  function context() {
    if (!ctx) {
      ctx = new AC();
      sfxBus = ctx.createGain();
      musicBus = ctx.createGain();
      sfxBus.connect(ctx.destination);
      musicBus.connect(ctx.destination);
    }
    return ctx;
  }

  function unlock() {
    var c = context();
    if (paused || document.hidden) return;
    if (c.state !== 'running') c.resume();
    if (!unlocked) {
      var s = c.createBufferSource();
      s.buffer = c.createBuffer(1, 1, 22050);
      s.connect(c.destination);
      s.start(0);
      unlocked = true;
    }
  }
  ['pointerdown', 'touchend', 'mousedown', 'keydown'].forEach(function (e) {
    window.addEventListener(e, unlock, { capture: true, passive: true });
  });

  // Quiet in a background tab or with the phone locked.
  document.addEventListener('visibilitychange', function () {
    if (!ctx) return;
    if (document.hidden) ctx.suspend();
    else if (!paused && unlocked) ctx.resume();
  });

  function duck(seconds) {
    var g = musicBus.gain, now = ctx.currentTime;
    g.cancelScheduledValues(now);
    g.setValueAtTime(g.value, now);
    g.setTargetAtTime(0.3, now, 0.05);
    g.setTargetAtTime(1, now + Math.max(0.3, seconds - 0.4), 0.4);
  }

  window.zoyaSound = {
    load: function (name, data) {
      if (buffers[name]) return Promise.resolve();
      return new Promise(function (ok, fail) {
        context().decodeAudioData(data, function (b) { buffers[name] = b; ok(); }, fail);
      });
    },

    play: function (name, volume, rate, duckMusic) {
      var b = buffers[name];
      // Before the first tap nothing plays (and nothing piles up to play all at once later).
      if (!b || !ctx || ctx.state !== 'running') return;
      var s = ctx.createBufferSource(), g = ctx.createGain();
      s.buffer = b;
      s.playbackRate.value = rate;
      g.gain.value = volume;
      s.connect(g);
      g.connect(sfxBus);
      s.start();
      if (duckMusic) duck(b.duration / rate);
    },

    // Fades the playing loop out and [name] in, looping [loopLength] s from [loopStart].
    music: function (name, volume, loopStart, loopLength) {
      var c = context(), now = c.currentTime;
      if (current) {
        current.gain.gain.setTargetAtTime(0, now, 0.25);
        current.src.stop(now + 1.5);
        current = null;
      }
      var b = name && buffers[name];
      if (!b) return;
      var s = c.createBufferSource(), g = c.createGain();
      s.buffer = b;
      s.loop = true;
      s.loopStart = loopStart;
      s.loopEnd = Math.min(b.duration, loopStart + loopLength);
      g.gain.setValueAtTime(0, now);
      g.gain.setTargetAtTime(volume, now, 0.3);
      s.connect(g);
      g.connect(musicBus);
      s.start(now, loopStart);
      current = { src: s, gain: g, name: name };
    },

    // For checking from the browser console.
    status: function () {
      return { state: ctx && ctx.state, loaded: Object.keys(buffers), music: current && current.name };
    },

    pause: function (p) {
      paused = p;
      if (!ctx) return;
      if (p) ctx.suspend();
      else if (unlocked && !document.hidden) ctx.resume();
    },
  };
})();
