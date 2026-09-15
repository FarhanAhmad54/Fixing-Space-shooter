# Starfall Vengeance

A LÖVE 11.5 arcade space shooter built for Poki and Crazy Games. Three
player-facing modes, four weapons, permanent run upgrades, attack drones,
combo scoring, and a real portal SDK bridge.

## Run

Requires **LÖVE 11.5**.

```

love .

```

## Modes

**CAMPAIGN** — 30 escalating waves with boss gates and a full completion goal.

**ENDLESS** — infinite adaptive pressure that scales against your survival time.

**GAUNTLET** — 8 timed trials with rotating combat mutators and a final boss.

## Controls

**Desktop:** WASD / arrow keys to move, mouse to aim and fire, Space to dash,
1–4 to switch weapon, Esc to pause.

**Mobile:** dual virtual joysticks. Left stick moves, right stick aims and
fires automatically when pushed outward.

## Verify before shipping

```

python3 tools/qa.py       # must print STARFALL QA: PASS
tools/build_web.sh        # must print PASS: web build ready

```

`build_web.sh` measures the gzipped initial payload and **fails the build**
if it exceeds the CrazyGames 50 MB ceiling. This is the single most common
cause of portal rejection.

## Portal requirements enforced

CrazyGames limits: initial load ≤ 50 MB, total ≤ 250 MB, ≤ 1,500 files,
16:9 iframe, legible at DPR 1, frame-rate-independent physics at 144/165 Hz,
PEGI 12.

The SDK bridge (`web/platform-bridge.js`) implements the mandatory hooks:

| Hook | When |
|---|---|
| `loadingStart` | Before the love.js bundle mounts |
| `loadingFinished` | Once the canvas exists and assets are ready |
| `gameplayStart` | On run start and resume |
| `gameplayStop` | On pause, death, upgrade screen, tab blur |
| `commercialBreak` | Midgame ad at the death screen |
| `rewardedBreak` | Player-initiated rewarded ad |

## Frame-rate independence

Every velocity, cooldown, spawn timer, shake duration, particle lifetime and
hitstop is multiplied by `dt`. Behaviour is identical at 60 Hz, 144 Hz and
165 Hz.

## File layout

```

conf.lua              LÖVE configuration
main.lua              Entry point and state machine
portal.lua            Runtime SDK bridge (FFI + Emscripten)
assets.lua            Image and font registry
sound.lua             SFX manager with variant rotation
modes.lua             Three mode definitions and wave rules
player.lua            Player ship
enemy.lua             Enemy types, AI, bosses
bullet.lua            Pooled projectiles with homing
weapons.lua           Four weapon definitions
powerup.lua           Temporary and instant pickups
xp.lua                XP curve and permanent upgrade pool
drone.lua             Orbiting attack drones
particles.lua         Pooled particle system with free-list
effects.lua           Screen shake, hit flash, hitstop, damage numbers
profile.lua           Persistent save data
touchcontrols.lua     Mobile dual joysticks
tools/                Packaging, web build, QA
web/                  Host shell and portal SDK bridge

```

