/**
 * platform-bridge.js — Production CrazyGames SDK v3 Bridge for Starfall Vengeance.
 *
 * Implements:
 *  - Official CrazyGames SDK v3 asynchronous initialization queue
 *  - Lifecycle tracking: loadingStart, loadingStop, gameplayStart, gameplayStop, happytime
 *  - Interstitial / midgame ads with 90s cooldown enforcement & audio muting
 *  - Rewarded ads with instant WebAssembly filesystem feedback (portal_reward.txt)
 *  - Seamless WebAudio suspension/resumption via Emscripten Module.SDL2
 *  - Desktop & offline fallback simulation
 */

(function () {
  "use strict";

  const S = (window.StarfallPlatform = window.StarfallPlatform || {});

  let initPromise = null;
  let isSdkReady = false;
  let isPokiReady = false;
  let isCgReady = false;
  let loadingStarted = false;
  let loadingStopped = false;
  let lastCommercialTime = 0;
  const MIN_COMMERCIAL_INTERVAL_MS = 90000; // 90s cooldown

  S.lastRewardSuccess = false;
  S.lastRewardType = null;
  S.lastRewardNonce = 0;

  // ---------------------------------------------------------------
  // SDK Initialization & Verification
  // ---------------------------------------------------------------

  function initSdk() {
    if (initPromise) return initPromise;

    var promises = [];

    // 1. Poki SDK initialization
    var pokiP = new Promise(function (resolve) {
      function tryInitPoki() {
        if (window.PokiSDK && typeof window.PokiSDK.init === "function") {
          window.PokiSDK.init()
            .then(function () {
              isPokiReady = true;
              console.log("[StarfallPlatform] Poki SDK v2 initialized successfully.");
              resolve();
            })
            .catch(function (err) {
              console.warn("[StarfallPlatform] Poki SDK init completed (adblocker/restricted):", err);
              isPokiReady = true;
              resolve();
            });
          return true;
        }
        return false;
      }

      if (!tryInitPoki()) {
        var attempts = 0;
        var maxAttempts = 150; // Wait up to 15 seconds for CDN script
        var poll = setInterval(function () {
          attempts++;
          if (tryInitPoki() || attempts >= maxAttempts) {
            clearInterval(poll);
            resolve();
          }
        }, 100);
      }
    });
    promises.push(pokiP);

    // 2. CrazyGames SDK v3 initialization
    if (window.CrazyGames && window.CrazyGames.SDK && typeof window.CrazyGames.SDK.init === "function") {
      var cgP = window.CrazyGames.SDK.init()
        .then(function () {
          isCgReady = true;
          var env = window.CrazyGames.SDK.environment || "unknown";
          console.log("[StarfallPlatform] CrazyGames SDK v3 initialized successfully. Environment:", env);
        })
        .catch(function (err) {
          console.warn("[StarfallPlatform] CrazyGames SDK init warning (continuing in fallback):", err);
          isCgReady = false;
        });
      promises.push(cgP);
    }

    initPromise = Promise.all(promises).then(function () {
      isSdkReady = true;
      if (!isPokiReady && !isCgReady) {
        console.log("[StarfallPlatform] Standalone / offline mode active.");
      }
    });

    return initPromise;
  }

  // Start initialization immediately
  initSdk();

  function whenReady(fn) {
    return initSdk().then(function () {
      try {
        return fn();
      } catch (e) {
        console.warn("[StarfallPlatform] Execution error:", e);
      }
    });
  }

  function hasCrazyGames() {
    return !!(
      isCgReady &&
      window.CrazyGames &&
      window.CrazyGames.SDK &&
      window.CrazyGames.SDK.game
    );
  }

  function hasPoki() {
    return !!(
      window.PokiSDK &&
      typeof window.PokiSDK.gameLoadingFinished === "function"
    );
  }

  // ---------------------------------------------------------------
  // Audio Muting for Ads
  // ---------------------------------------------------------------

  function muteAudio() {
    try {
      if (window.Module && window.Module.SDL2 && window.Module.SDL2.audioContext) {
        if (window.Module.SDL2.audioContext.state === "running") {
          window.Module.SDL2.audioContext.suspend();
        }
      }
    } catch (e) {}
  }

  function unmuteAudio() {
    try {
      if (window.Module && window.Module.SDL2 && window.Module.SDL2.audioContext) {
        if (window.Module.SDL2.audioContext.state === "suspended") {
          window.Module.SDL2.audioContext.resume();
        }
      }
    } catch (e) {}
  }

  // ---------------------------------------------------------------
  // WebAssembly <-> JS Communication
  // ---------------------------------------------------------------

  function notifyLuaReward(success, rewardType) {
    S.lastRewardSuccess = !!success;
    S.lastRewardType = rewardType || "default";
    S.lastRewardNonce++;

    try {
      if (window.Module && window.Module.FS && window.StarfallSaveDir) {
        var filePath = window.StarfallSaveDir + "/portal_reward.txt";
        var payload = S.lastRewardNonce + ":" + (success ? "1" : "0") + ":" + S.lastRewardType;
        window.Module.FS.writeFile(filePath, payload);
      }
    } catch (e) {
      console.warn("[StarfallPlatform] Failed to write reward file to Emscripten FS:", e);
    }
  }

  // ---------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------

  S.loadingStart = function () {
    whenReady(function () {
      if (loadingStarted) return;
      loadingStarted = true;
      if (hasPoki() && typeof window.PokiSDK.gameLoadingStart === "function") {
        window.PokiSDK.gameLoadingStart();
        console.log("[StarfallPlatform] PokiSDK gameLoadingStart fired");
      }
      if (hasCrazyGames() && typeof window.CrazyGames.SDK.game.loadingStart === "function") {
        window.CrazyGames.SDK.game.loadingStart();
        console.log("[StarfallPlatform] CrazyGames SDK loadingStart fired");
      }
    });
  };

  S.loadingProgress = function (progress) {
    whenReady(function () {
      if (hasPoki() && typeof window.PokiSDK.gameLoadingProgress === "function") {
        var pct = typeof progress === "number" ? progress : (progress && progress.percentage);
        if (typeof pct === "number") {
          window.PokiSDK.gameLoadingProgress({ percentage: Math.max(0, Math.min(1, pct)) });
        }
      }
    });
  };

  S.loadingFinished = function () {
    whenReady(function () {
      if (loadingStopped) return;
      // Guarantee loadingStart occurred first
      if (!loadingStarted) {
        S.loadingStart();
      }
      loadingStopped = true;

      if (hasPoki() && typeof window.PokiSDK.gameLoadingFinished === "function") {
        window.PokiSDK.gameLoadingFinished();
        console.log("[StarfallPlatform] PokiSDK gameLoadingFinished fired");
      }
      if (hasCrazyGames() && typeof window.CrazyGames.SDK.game.loadingStop === "function") {
        window.CrazyGames.SDK.game.loadingStop();
        console.log("[StarfallPlatform] CrazyGames SDK loadingStop fired");
      }
      S.ready();
    });
  };

  S.gameplayStart = function () {
    whenReady(function () {
      if (hasPoki() && typeof window.PokiSDK.gameplayStart === "function") {
        window.PokiSDK.gameplayStart();
        console.log("[StarfallPlatform] PokiSDK gameplayStart fired");
      }
      if (hasCrazyGames() && typeof window.CrazyGames.SDK.game.gameplayStart === "function") {
        window.CrazyGames.SDK.game.gameplayStart();
        console.log("[StarfallPlatform] CrazyGames SDK gameplayStart fired");
      }
    });
  };

  S.gameplayStop = function () {
    whenReady(function () {
      if (hasPoki() && typeof window.PokiSDK.gameplayStop === "function") {
        window.PokiSDK.gameplayStop();
        console.log("[StarfallPlatform] PokiSDK gameplayStop fired");
      }
      if (hasCrazyGames() && typeof window.CrazyGames.SDK.game.gameplayStop === "function") {
        window.CrazyGames.SDK.game.gameplayStop();
        console.log("[StarfallPlatform] CrazyGames SDK gameplayStop fired");
      }
    });
  };

  S.happytime = function () {
    whenReady(function () {
      if (hasPoki() && typeof window.PokiSDK.happyTime === "function") {
        window.PokiSDK.happyTime();
        console.log("[StarfallPlatform] PokiSDK happyTime fired");
      }
      if (hasCrazyGames() && typeof window.CrazyGames.SDK.game.happytime === "function") {
        window.CrazyGames.SDK.game.happytime();
        console.log("[StarfallPlatform] CrazyGames SDK happytime fired");
      }
    });
  };

  // ---------------------------------------------------------------
  // Advertisements
  // ---------------------------------------------------------------

  S.commercialBreak = function () {
    return new Promise(function (resolve) {
      const now = Date.now();
      if (now - lastCommercialTime < MIN_COMMERCIAL_INTERVAL_MS) {
        resolve();
        return;
      }

      whenReady(function () {
        muteAudio();

        if (hasPoki() && typeof window.PokiSDK.commercialBreak === "function") {
          window.PokiSDK.commercialBreak(function () {
            muteAudio();
          })
            .then(function () {
              lastCommercialTime = Date.now();
              unmuteAudio();
              resolve();
            })
            .catch(function (err) {
              console.warn("[StarfallPlatform] Poki commercial break ended/blocked:", err);
              unmuteAudio();
              resolve();
            });
          return;
        }

        if (
          hasCrazyGames() &&
          window.CrazyGames.SDK.ad &&
          typeof window.CrazyGames.SDK.ad.requestAd === "function"
        ) {
          let finished = false;
          function done() {
            if (finished) return;
            finished = true;
            lastCommercialTime = Date.now();
            unmuteAudio();
            resolve();
          }

          window.CrazyGames.SDK.ad.requestAd("midgame", {
            adStarted: function () {
              muteAudio();
            },
            adFinished: function () {
              done();
            },
            adError: function (err) {
              console.warn("[StarfallPlatform] Midgame ad error:", err);
              done();
            },
          });

          setTimeout(done, 30000); // 30s fallback
          return;
        }

        // Standalone / local fallback
        lastCommercialTime = Date.now();
        unmuteAudio();
        resolve();
      });
    });
  };

  S.rewardedBreak = function (rewardType) {
    rewardType = rewardType || "default";

    return new Promise(function (resolve) {
      whenReady(function () {
        muteAudio();

        function grant(success) {
          notifyLuaReward(success, rewardType);
          unmuteAudio();
          resolve(!!success);
        }

        if (hasPoki() && typeof window.PokiSDK.rewardedBreak === "function") {
          window.PokiSDK.rewardedBreak(function () {
            muteAudio();
          })
            .then(function (withReward) {
              grant(withReward);
            })
            .catch(function (err) {
              console.warn("[StarfallPlatform] Poki rewarded break ended/failed:", err);
              grant(false);
            });
          return;
        }

        if (
          hasCrazyGames() &&
          window.CrazyGames.SDK.ad &&
          typeof window.CrazyGames.SDK.ad.requestAd === "function"
        ) {
          let resolved = false;
          function finish(success) {
            if (resolved) return;
            resolved = true;
            grant(success);
          }

          window.CrazyGames.SDK.ad.requestAd("rewarded", {
            adStarted: function () {
              muteAudio();
            },
            adFinished: function () {
              finish(true);
            },
            adError: function (err) {
              console.warn("[StarfallPlatform] Rewarded ad error:", err);
              finish(false);
            },
          });

          setTimeout(function () { finish(false); }, 30000);
          return;
        }

        // Local testing simulator
        grant(true);
      });
    });
  };

  // ---------------------------------------------------------------
  // User Accounts
  // ---------------------------------------------------------------

  S.getUser = function () {
    return new Promise(function (resolve) {
      whenReady(function () {
        if (hasPoki() && typeof window.PokiSDK.getUser === "function") {
          window.PokiSDK.getUser()
            .then(function (user) { resolve(user || null); })
            .catch(function () { resolve(null); });
          return;
        }

        if (
          hasCrazyGames() &&
          window.CrazyGames.SDK.user &&
          typeof window.CrazyGames.SDK.user.getUser === "function"
        ) {
          try {
            var u = window.CrazyGames.SDK.user.getUser();
            if (u && typeof u.then === "function") {
              u.then(resolve).catch(function () { resolve(null); });
            } else {
              resolve(u || null);
            }
          } catch (e) {
            resolve(null);
          }
          return;
        }
        resolve(null);
      });
    });
  };

  S.ready = function () {
    try {
      window.dispatchEvent(new Event("starfall-ready"));
    } catch (e) {}
  };

  S._production = true;
  S._hasCrazyGames = hasCrazyGames;
  S._hasPoki = hasPoki;
})();
