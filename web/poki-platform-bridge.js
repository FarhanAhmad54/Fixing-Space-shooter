(function () {
  "use strict";
  var S = (window.StarfallPlatform = window.StarfallPlatform || {});
  var loadingStarted = false, loadingFinished = false, gameplayActive = false, lastCommercial = 0;
  var MIN_COMMERCIAL_INTERVAL_MS = 90000;

  function init() {
    if (window.PokiSDK && typeof window.PokiSDK.init === "function") {
      try { return Promise.resolve(window.PokiSDK.init()).catch(function () {}); } catch (e) {}
    }
    return Promise.resolve();
  }
  var readyPromise = init();
  function whenReady(fn) { return readyPromise.then(function () { try { return fn(); } catch (e) { console.warn("[StarfallPlatform]", e); } }); }

  function muteAudio() {
    try {
      var ctx = window.Module && window.Module.SDL2 && window.Module.SDL2.audioContext;
      if (ctx && ctx.state === "running") ctx.suspend();
    } catch (e) {}
  }
  function unmuteAudio() {
    try {
      var ctx = window.Module && window.Module.SDL2 && window.Module.SDL2.audioContext;
      if (ctx && ctx.state === "suspended") ctx.resume();
    } catch (e) {}
  }

  S.loadingStart = function () { return whenReady(function () { if (!loadingStarted) loadingStarted = true; }); };
  S.loadingProgress = function () {};
  S.loadingFinished = function () {
    return whenReady(function () {
      if (loadingFinished) return;
      loadingStarted = true; loadingFinished = true;
      if (window.PokiSDK && typeof window.PokiSDK.gameLoadingFinished === "function") window.PokiSDK.gameLoadingFinished();
      S.ready();
    });
  };
  S.gameplayStart = function () {
    return whenReady(function () {
      if (gameplayActive) return;
      gameplayActive = true;
      if (window.PokiSDK && typeof window.PokiSDK.gameplayStart === "function") window.PokiSDK.gameplayStart();
    });
  };
  S.gameplayStop = function () {
    return whenReady(function () {
      if (!gameplayActive) return;
      gameplayActive = false;
      if (window.PokiSDK && typeof window.PokiSDK.gameplayStop === "function") window.PokiSDK.gameplayStop();
    });
  };
  S.happytime = function () {
    return whenReady(function () {
      if (window.PokiSDK && typeof window.PokiSDK.happyTime === "function") window.PokiSDK.happyTime(0.5);
    });
  };

  S.commercialBreak = function () {
    return new Promise(function (resolve) {
      if (Date.now() - lastCommercial < MIN_COMMERCIAL_INTERVAL_MS) { resolve(); return; }
      S.gameplayStop(); muteAudio();
      whenReady(function () {
        if (window.PokiSDK && typeof window.PokiSDK.commercialBreak === "function") {
          Promise.resolve(window.PokiSDK.commercialBreak(function () { muteAudio(); })).then(function () {
            lastCommercial = Date.now(); unmuteAudio(); resolve();
          }).catch(function () { unmuteAudio(); resolve(); });
        } else { unmuteAudio(); resolve(); }
      });
    });
  };

  S.rewardedBreak = function (rewardType) {
    return new Promise(function (resolve) {
      S.gameplayStop(); muteAudio();
      whenReady(function () {
        if (window.PokiSDK && typeof window.PokiSDK.rewardedBreak === "function") {
          Promise.resolve(window.PokiSDK.rewardedBreak(function () { muteAudio(); })).then(function (rewarded) {
            unmuteAudio(); S.lastRewardSuccess = rewarded === true; S.lastRewardType = rewardType || "default"; resolve(rewarded === true);
          }).catch(function () { unmuteAudio(); S.lastRewardSuccess = false; S.lastRewardType = rewardType || "default"; resolve(false); });
        } else { unmuteAudio(); resolve(false); }
      });
    });
  };

  S.getUser = function () {
    return whenReady(function () {
      if (window.PokiSDK && typeof window.PokiSDK.getUser === "function") return window.PokiSDK.getUser().catch(function () { return null; });
      return null;
    });
  };
  S.ready = function () { try { window.dispatchEvent(new Event("starfall-ready")); } catch (e) {} };
  S._production = true;
  S._hasPoki = function () { return !!window.PokiSDK; };
})();
