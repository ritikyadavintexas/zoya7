// Sizes the app's box (#app) to what can really be seen.
//  • iPhone home-screen app under a see-through status bar (the game): iOS
//    reports a window shorter than the screen, so the box covers the whole
//    screen for the current orientation. (The admin's status bar is solid,
//    and its window is right as reported.)
//  • With the on-screen keyboard up, the box shrinks to the part above the
//    keyboard (and follows Safari's scrolling), so the field being typed in
//    stays in view instead of under the keyboard.
(function () {
  var app = document.getElementById('app');
  if (!app) return;
  var vv = window.visualViewport;
  var bar = document.querySelector('meta[name="apple-mobile-web-app-status-bar-style"]');
  var seeThrough = !!bar && bar.getAttribute('content') === 'black-translucent';
  function fit() {
    var w = window.innerWidth, h = window.innerHeight, top = 0;
    if (navigator.standalone && seeThrough) {
      var a = Math.min(screen.width, screen.height), b = Math.max(screen.width, screen.height);
      var landscape = window.matchMedia('(orientation: landscape)').matches;
      w = Math.max(w, landscape ? b : a);
      h = Math.max(h, landscape ? a : b);
    }
    if (vv && vv.height < window.innerHeight - 80) {
      // The keyboard is up.
      h = vv.height;
      top = vv.offsetTop;
    }
    app.style.width = w + 'px';
    app.style.height = h + 'px';
    app.style.top = top + 'px';
  }
  fit();
  window.addEventListener('resize', fit);
  window.addEventListener('orientationchange', function () { setTimeout(fit, 300); });
  if (vv) {
    vv.addEventListener('resize', fit);
    vv.addEventListener('scroll', fit);
  }
})();
