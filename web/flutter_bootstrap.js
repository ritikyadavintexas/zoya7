{{flutter_js}}
{{flutter_build_config}}

// Render into #app instead of letting Flutter size itself to the window.
// On an iPhone home-screen app with a translucent status bar, iOS reports a
// window that is too short (by about the status bar), which leaves an empty
// strip at the bottom. #app is sized to the real screen there (see index.html).
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      hostElement: document.getElementById('app'),
    });
    await appRunner.runApp();
  },
});
