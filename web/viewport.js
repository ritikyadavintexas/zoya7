// Sizes the app's box (#app) to what can really be seen, and measures the
// on-screen keyboard for the app.
//  • iPhone home-screen app under a see-through status bar (the game): iOS
//    reports a window shorter than the screen, so the box covers the whole
//    screen for the current orientation. (The admin's status bar is solid,
//    and its window is right as reported.)
//  • With the on-screen keyboard up, the box keeps its size (Flutter keeps
//    its size while typing on a phone anyway) and follows Safari's scrolling;
//    how much of it the keyboard covers goes to the app
//    (window.zoyaKeyboardInset, and window.zoyaOnKeyboard when it changes),
//    which then lays everything out above the keyboard. Flutter can't see the
//    keyboard itself when it draws into a box of its own like this one.
(function () {
  var app = document.getElementById('app');
  if (!app) return;
  var vv = window.visualViewport;
  var bar = document.querySelector('meta[name="apple-mobile-web-app-status-bar-style"]');
  var seeThrough = !!bar && bar.getAttribute('content') === 'black-translucent';
  var touch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
  // The box without a keyboard (for the current width).
  var base = null;
  window.zoyaKeyboardInset = 0;
  function typing() {
    var el = document.activeElement;
    return !!el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
  }
  function fit() {
    var w = window.innerWidth, h = window.innerHeight, top = 0, kb = 0;
    if (navigator.standalone && seeThrough) {
      var a = Math.min(screen.width, screen.height), b = Math.max(screen.width, screen.height);
      var landscape = window.matchMedia('(orientation: landscape)').matches;
      w = Math.max(w, landscape ? b : a);
      h = Math.max(h, landscape ? a : b);
    }
    var seen = vv ? vv.height : h;
    if (touch && typing() && base && base.w === w && seen < base.h - 80) {
      // The keyboard is up: same box, the bottom part covered.
      h = base.h;
      top = vv ? vv.offsetTop : 0;
      kb = Math.round(h - seen);
    } else {
      base = { w: w, h: h };
    }
    app.style.width = w + 'px';
    app.style.height = h + 'px';
    app.style.top = top + 'px';
    if (kb !== window.zoyaKeyboardInset) {
      window.zoyaKeyboardInset = kb;
      if (window.zoyaOnKeyboard) window.zoyaOnKeyboard(kb);
    }
  }
  fit();
  window.addEventListener('resize', fit);
  window.addEventListener('orientationchange', function () { setTimeout(fit, 300); });
  // Typing starts or stops (the keyboard can open before or after this).
  document.addEventListener('focusin', function () { setTimeout(fit, 50); });
  document.addEventListener('focusout', function () { setTimeout(fit, 50); });
  if (vv) {
    vv.addEventListener('resize', fit);
    vv.addEventListener('scroll', fit);
  }
})();
