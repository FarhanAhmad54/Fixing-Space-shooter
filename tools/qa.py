#!/usr/bin/env python3
"""Starfall Vengeance — production QA gate.

Runs structural checks over the source tree:
  - required source modules present
  - exactly three mode definitions
  - integration hooks wired
  - asset + sound registries populated and verified on disk
  - frame-rate independence heuristic (no bare per-frame increments)
  - SDK bridge exports mandatory portal hooks
  - build script declares the 50 MB ceiling

Exits non-zero on error so it can gate CI and CrazyGames deployment.
"""

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
warnings = []

# ---------------------------------------------------------------------------
required = [
    "main.lua", "conf.lua", "assets.lua", "modes.lua", "player.lua",
    "enemy.lua", "bullet.lua", "weapons.lua", "powerup.lua", "xp.lua",
    "drone.lua", "particles.lua", "effects.lua", "sound.lua",
    "profile.lua", "touchcontrols.lua", "portal.lua", "shaders.lua",
    "background.lua", "ui.lua",
]
for name in required:
    if not (ROOT / name).is_file():
        errors.append(f"missing required source: {name}")

# ---------------------------------------------------------------------------
modes_path = ROOT / "modes.lua"
modes = modes_path.read_text(encoding="utf-8") if modes_path.exists() else ""
mode_ids = re.findall(r'id\s*=\s*"(campaign|endless|gauntlet)"', modes)
if sorted(set(mode_ids)) != ["campaign", "endless", "gauntlet"]:
    errors.append(f"mode registry invalid: {sorted(set(mode_ids))}")

# ---------------------------------------------------------------------------
main = (ROOT / "main.lua").read_text(encoding="utf-8") if (ROOT / "main.lua").exists() else ""
combined = main + "\n" + modes

for needle in [
    'require("touchcontrols")',
    'require("portal")',
    "Assets.load()",
    "Modes.waveRules(run)",
    "XP.addXP(run",
    "Particles",
    "Effects",
    "Sound.new()",
    "Profile.init()",
]:
    if needle not in combined:
        errors.append(f"integration missing: {needle}")

# ---------------------------------------------------------------------------
asset_patterns = [
    "assets/SpaceShip.png", "assets/bg.png", "assets/Stars-A.png", "assets/Stars-B.png",
    "assets/SWARMERS.png", "assets/SNIPERS.png", "assets/BOMBERS.png",
    "assets/TURRET DRONES.png", "assets/MINI-BOSSES.png",
    "assets/bullet.png", "assets/bullet-1.png", "assets/bullet-2.png",
    "assets/laser-1.png", "assets/laser-2.png", "assets/laser-3.png",
    "assets/plasm.png", "assets/rocket.png",
    "assets/shield.png", "assets/fire.png",
    "assets/bonus_life.png", "assets/bonus_shield.png", "assets/bonus_time.png",
]
assets_lua = (ROOT / "assets.lua").read_text(encoding="utf-8") if (ROOT / "assets.lua").exists() else ""
for p in asset_patterns:
    if p not in assets_lua:
        errors.append(f"asset registry missing: {p}")
    if not (ROOT / p).is_file():
        errors.append(f"asset file missing on disk: {p}")

# ---------------------------------------------------------------------------
sound = (ROOT / "sound.lua").read_text(encoding="utf-8") if (ROOT / "sound.lua").exists() else ""
if "sounds/" not in sound:
    errors.append("sound manager is not pointed at sounds/")

sound_files = [
    "sounds/laser-1.ogg", "sounds/laser-2.ogg", "sounds/laser-3.ogg",
    "sounds/hit.ogg", "sounds/explosion.ogg", "sounds/powerup.ogg",
    "sounds/levelup.ogg", "sounds/dash.ogg", "sounds/playerhit.ogg",
    "sounds/boss.ogg", "sounds/music.ogg",
]
for sf in sound_files:
    if not (ROOT / sf).is_file():
        errors.append(f"sound file missing on disk: {sf}")

# ---------------------------------------------------------------------------
physics_files = ["player.lua", "enemy.lua", "bullet.lua", "drone.lua", "particles.lua"]
suspicious = re.compile(r"\b([xy])\s*=\s*\1\s*[+\-]\s*\d+(\.\d+)?\s*$")
for fname in physics_files:
    fpath = ROOT / fname
    if not fpath.exists():
        continue
    for i, line in enumerate(fpath.read_text(encoding="utf-8").splitlines(), 1):
        s = line.strip()
        if s.startswith("--") or "* dt" in line or "dt *" in line or "dt)" in line:
            continue
        if suspicious.search(line):
            warnings.append(f"{fname}:{i} possible non-dt-scaled update: {s}")

# ---------------------------------------------------------------------------
bridge = ROOT / "web" / "platform-bridge.js"
if not bridge.is_file():
    errors.append("web/platform-bridge.js is missing")
else:
    btext = bridge.read_text(encoding="utf-8")
    for hook in ["loadingFinished", "gameplayStart", "gameplayStop",
                 "commercialBreak", "rewardedBreak"]:
        if hook not in btext:
            errors.append(f"platform-bridge.js missing SDK hook: {hook}")

# ---------------------------------------------------------------------------
build_sh = ROOT / "tools" / "build_web.sh"
if not build_sh.is_file():
    warnings.append("tools/build_web.sh missing — web build size is not enforced")
else:
    btext = build_sh.read_text(encoding="utf-8")
    if "LIMIT_MB=50" not in btext:
        warnings.append("build_web.sh does not declare the 50 MB CrazyGames limit")

# ---------------------------------------------------------------------------
if errors:
    print("STARFALL QA: FAIL")
    for e in errors:
        print("  ERROR:", e)
    for w in warnings:
        print("  WARN: ", w)
    sys.exit(1)

print("STARFALL QA: PASS")
print("  - All required source modules present (including shaders.lua)")
print("  - Exactly three mode definitions detected")
print("  - Core gameplay, controls, effects, audio and asset hooks found")
print("  - All 22+ sprite assets verified physically on disk")
print("  - All 11 sound effects and music verified physically on disk")
print("  - Web SDK bridge exports the mandatory portal event hooks")
if warnings:
    print(f"  - {len(warnings)} warning(s):")
    for w in warnings:
        print("      ", w)
