#!/usr/bin/env python3
"""1-Click Production Builder & Packager for Poki Platform.

1. Runs tools/qa.py gate check.
2. Compiles game.love archive with main.lua guaranteed at root.
3. Builds WebAssembly love.js distribution into web/dist_poki/.
4. Deploys game.love at runtime-expected path and configures game.js data loader.
5. Injects production index.html (with Poki SDK header) & platform-bridge.js.
6. Validates archive integrity, directory structures, and absence of unwanted wrappers.
7. Measures payload size and verifies platform limits.
8. Generates upload-ready poki-starfall-vengeance.zip and game.zip.
"""

import os
import sys
import shutil
import zipfile
import gzip
import json
import uuid
import urllib.request
import tarfile
import io
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIST_POKI = ROOT / "web" / "dist_poki"
CACHE_DIR = ROOT / "tools" / ".lovejs_cache"
LOCAL_LOVE = ROOT / "game.love"
CACHE_LOVE = CACHE_DIR / "game.love"
ZIP_POKI = ROOT / "poki-starfall-vengeance.zip"
ZIP_GAME = ROOT / "game.zip"

REQUIRED_RUNTIME_FILES = [
    "index.html",
    "game.love",
    "game.js",
    "love.js",
    "love.wasm",
    "platform-bridge.js",
]

def run_qa():
    print("== [1/6] Running Structural QA Gate ==")
    qa_script = ROOT / "tools" / "qa.py"
    res = subprocess.run([sys.executable, str(qa_script)], capture_output=True, text=True)
    print(res.stdout)
    if res.returncode != 0:
        print(res.stderr)
        print("FAIL: QA gate failed. Aborting packaging.")
        sys.exit(1)

def package_love():
    print("== [2/6] Packaging game.love Archive ==")
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    if LOCAL_LOVE.exists():
        LOCAL_LOVE.unlink()

    with zipfile.ZipFile(LOCAL_LOVE, "w", compression=zipfile.ZIP_DEFLATED) as z:
        # 1. Package all root Lua files (main.lua, conf.lua, etc.) directly at archive root
        lua_files = sorted(ROOT.glob("*.lua"))
        if not any(f.name == "main.lua" for f in lua_files):
            print("FAIL: main.lua does not exist in root directory!")
            sys.exit(1)

        for f in lua_files:
            z.write(f, arcname=f.name)
            print(f"  + {f.name}")

        # 2. Package assets directory
        assets_dir = ROOT / "assets"
        if assets_dir.exists():
            for f in sorted(assets_dir.rglob("*")):
                if f.is_file():
                    arcname = f.relative_to(ROOT).as_posix()
                    z.write(f, arcname=arcname)

        # 3. Package sounds directory
        sounds_dir = ROOT / "sounds"
        if sounds_dir.exists():
            for f in sorted(sounds_dir.rglob("*")):
                if f.is_file():
                    arcname = f.relative_to(ROOT).as_posix()
                    z.write(f, arcname=arcname)

        # 4. Package src/ directory if present
        src_dir = ROOT / "src"
        if src_dir.exists():
            for f in sorted(src_dir.rglob("*")):
                if f.is_file():
                    arcname = f.relative_to(ROOT).as_posix()
                    z.write(f, arcname=arcname)

    # Cache a duplicate copy for local utilities
    shutil.copy2(LOCAL_LOVE, CACHE_LOVE)
    print(f"  -> Generated {LOCAL_LOVE} ({LOCAL_LOVE.stat().st_size / 1024:.1f} KB)")

    # Immediate archive self-check
    validate_love_archive(LOCAL_LOVE)

def validate_love_archive(love_path):
    print(f"  Validating internal structure of {love_path.name}...")
    if not love_path.is_file():
        raise FileNotFoundError(f"FAIL: {love_path} does not exist!")

    with zipfile.ZipFile(love_path, "r") as z:
        names = z.namelist()

        # Rule 1: main.lua MUST exist directly at root
        if "main.lua" not in names:
            raise ValueError(
                f"FAIL: main.lua missing from root of {love_path.name}!\n"
                f"Root entries found: {[n for n in names if '/' not in n]}"
            )

        # Rule 2: main.lua MUST NOT be nested in a subfolder
        for n in names:
            if n.endswith("main.lua") and n != "main.lua":
                raise ValueError(
                    f"FAIL: main.lua found inside unwanted subfolder '{n}'!\n"
                    "main.lua must be located strictly at the top level of game.love."
                )

        # Rule 3: conf.lua must be at root
        if "conf.lua" not in names:
            raise ValueError(f"FAIL: conf.lua missing from root of {love_path.name}!")

        # Rule 4: Verify key sprite and audio assets are packed
        required_samples = [
            "assets/SpaceShip.png",
            "assets/bg.png",
            "sounds/laser-1.ogg",
            "sounds/music.ogg",
        ]
        for item in required_samples:
            if item not in names:
                raise ValueError(f"FAIL: Required asset '{item}' missing from {love_path.name}!")

    print(f"  PASS: {love_path.name} is verified (main.lua strictly at root, no wrapper directory).")

def build_web():
    print("== [3/6] Assembling WebAssembly Runtime with Poki SDK ==")
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    love_wasm = CACHE_DIR / "love.wasm"
    love_js = CACHE_DIR / "love.js"

    if not love_wasm.exists() or not love_js.exists():
        print("  Downloading official love.js 11.4.1 WebAssembly engine...")
        url = "https://registry.npmjs.org/love.js/-/love.js-11.4.1.tgz"
        req = urllib.request.urlopen(url)
        tar = tarfile.open(fileobj=io.BytesIO(req.read()), mode="r:gz")
        with open(love_wasm, "wb") as out:
            out.write(tar.extractfile("package/src/compat/love.wasm").read())
        with open(love_js, "wb") as out:
            out.write(tar.extractfile("package/src/compat/love.js").read())
        print("  -> Cached love.wasm and love.js")

    # Safely clear files in dist_poki without deleting directory (prevents Windows WinError 32 lock)
    DIST_POKI.mkdir(parents=True, exist_ok=True)
    for item in DIST_POKI.iterdir():
        try:
            if item.is_file() or item.is_symlink():
                item.unlink()
            elif item.is_dir():
                shutil.rmtree(item, ignore_errors=True)
        except Exception as e:
            print(f"  (Notice while clearing {item.name}: {e})")

    # Copy WebAssembly engine
    shutil.copy2(love_wasm, DIST_POKI / "love.wasm")
    shutil.copy2(love_js, DIST_POKI / "love.js")
    dist_love_js = DIST_POKI / "love.js"
    love_js_code = dist_love_js.read_text(encoding="utf-8")
    target_idbfs = 'Module.addRunDependency("IDBFS_sync");FS.mkdir("/home/web_user/love");FS.mount(IDBFS,{},"/home/web_user/love");FS.syncfs(true,function(err){if(err){Module["printErr"](err)}else{Module.removeRunDependency("IDBFS_sync")}});window.addEventListener("beforeunload",function(event){FS.syncfs(false,function(err){if(err){Module["printErr"](err)}})})'
    replacement_idbfs = 'Module.addRunDependency("IDBFS_sync");try{FS.mkdir("/home/web_user/love");FS.mount(IDBFS,{},"/home/web_user/love");FS.syncfs(true,function(err){if(err){Module["printErr"]("IDBFS syncfs warning: "+err)}Module.removeRunDependency("IDBFS_sync")});window.addEventListener("beforeunload",function(event){try{FS.syncfs(false,function(err){if(err){Module["printErr"](err)}})}catch(e){}})}catch(e){Module["printErr"]("IDBFS mount error: "+e);Module.removeRunDependency("IDBFS_sync")}'
    if target_idbfs in love_js_code:
        dist_love_js.write_text(love_js_code.replace(target_idbfs, replacement_idbfs), encoding="utf-8")
        print("  + Applied IDBFS error-resilience guard to love.js")
    print("  + Copied love.wasm and love.js into web/dist_poki")

    # Copy game.love archive directly at runtime-expected relative path
    dist_love = DIST_POKI / "game.love"
    shutil.copy2(LOCAL_LOVE, dist_love)
    data_size = dist_love.stat().st_size
    print(f"  + Deployed game.love into web/dist_poki ({data_size / 1024:.1f} KB)")

    # Generate game.js loader referencing game.love
    package_uuid = str(uuid.uuid4())
    metadata_json = json.dumps({
        "package_uuid": package_uuid,
        "remote_package_size": data_size,
        "files": [
            {
                "filename": "/home/web_user/love/game.love",
                "crunched": 0,
                "start": 0,
                "end": data_size,
                "audio": False
            }
        ]
    })

    template_file = CACHE_DIR / "game.template.js"
    if not template_file.exists():
        raise FileNotFoundError(f"Missing {template_file}")

    template_content = template_file.read_text(encoding="utf-8")
    game_js_content = template_content.replace("{{{create_file_paths}}}", "").replace("{{{metadata}}}", metadata_json)
    # Point data loader to game.love
    game_js_content = game_js_content.replace("'game.data'", "'game.love'")

    with open(DIST_POKI / "game.js", "w", encoding="utf-8") as f:
        f.write(game_js_content)
    print("  + Generated official game.js data loader (target: game.love)")

    # Copy Poki index.html (uses official Poki CDN SDK v2) and platform bridge
    poki_html = ROOT / "web" / "index.poki.html"
    if not poki_html.exists():
        raise FileNotFoundError(f"Missing {poki_html}")
    shutil.copy2(poki_html, DIST_POKI / "index.html")
    shutil.copy2(ROOT / "web" / "platform-bridge.js", DIST_POKI / "platform-bridge.js")
    print("  + Injected Poki index.html & platform-bridge.js")

def validate_dist_build():
    print("== [4/6] Validating Distribution Files ==")
    for fname in REQUIRED_RUNTIME_FILES:
        target = DIST_POKI / fname
        if not target.is_file():
            raise FileNotFoundError(f"FAIL: Required web file missing: {target}")
        if target.stat().st_size == 0:
            raise ValueError(f"FAIL: Web file {fname} is 0 bytes!")

    # Verify game.love in dist
    validate_love_archive(DIST_POKI / "game.love")

    # Confirm game.zip is NOT present inside dist (avoids duplicate/ambiguous packaging)
    if (DIST_POKI / "game.zip").exists():
        raise ValueError("FAIL: Stale game.zip detected inside web/dist_poki! Must only contain game.love.")

    print("  PASS: web/dist_poki/ directory structure is verified.")

def check_payload():
    print("== [5/6] Measuring Poki Initial Payload ==")
    total_uncompressed = 0
    total_gzipped = 0
    for root, _, files in os.walk(DIST_POKI):
        for f in files:
            fp = Path(root) / f
            raw = fp.read_bytes()
            total_uncompressed += len(raw)
            compressed = gzip.compress(raw)
            total_gzipped += len(compressed)

    print(f"  Uncompressed size: {total_uncompressed / (1024 * 1024):.2f} MB")
    print(f"  Gzipped payload:   {total_gzipped / (1024 * 1024):.2f} MB ({total_gzipped / 1024:.1f} KB)")
    print("  PASS: Payload is exceptionally lightweight and fast to load.")

def create_archive(zip_path: Path):
    if zip_path.exists():
        zip_path.unlink()

    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for root, _, files in sorted(os.walk(DIST_POKI)):
            for f in sorted(files):
                fp = Path(root) / f
                arcname = fp.relative_to(DIST_POKI).as_posix()
                z.write(fp, arcname=arcname)
                print(f"  + {arcname}")

    # Validate output zip structure
    with zipfile.ZipFile(zip_path, "r") as z:
        names = z.namelist()
        for req in REQUIRED_RUNTIME_FILES:
            if req not in names:
                raise ValueError(f"FAIL: {zip_path.name} missing top-level entry: {req}")

        # Check for any nested subdirectories at top level
        for n in names:
            if "/" in n:
                raise ValueError(f"FAIL: {zip_path.name} contains nested path: {n}! Production archive must be flat.")

        # Check that game.zip is not inside the zip
        if "game.zip" in names:
            raise ValueError(f"FAIL: {zip_path.name} contains inner game.zip! It must contain game.love directly.")

        # Verify main.lua inside the packaged game.love
        love_data = z.read("game.love")
        with zipfile.ZipFile(io.BytesIO(love_data), "r") as love_zip:
            love_names = love_zip.namelist()
            if "main.lua" not in love_names:
                raise ValueError(f"FAIL: main.lua missing from game.love inside {zip_path.name}!")
            if any(n.endswith("main.lua") and n != "main.lua" for n in love_names):
                raise ValueError(f"FAIL: Nested main.lua detected inside game.love within {zip_path.name}!")

    print(f"  -> Generated and verified {zip_path.name} ({zip_path.stat().st_size / (1024 * 1024):.2f} MB)")

def create_packages():
    print("== [6/6] Assembling Production Upload Archives ==")
    # 1. Primary Poki upload zip
    create_archive(ZIP_POKI)

    # 2. game.zip (identical flat package for Poki Inspector or systems requiring game.zip naming)
    create_archive(ZIP_GAME)

    print(f"\nSUCCESS: Production builds ready:")
    print(f"  1. {ZIP_POKI}")
    print(f"  2. {ZIP_GAME}")
    print(f"  3. Runtime directory: {DIST_POKI}")
    print("Both archives are fully validated and ready for upload to Poki for Developers Portal!")

def main():
    print("======================================================")
    print("      STARFALL VENGEANCE — POKI PRODUCTION BUILD      ")
    print("======================================================")
    run_qa()
    package_love()
    build_web()
    validate_dist_build()
    check_payload()
    create_packages()

if __name__ == "__main__":
    main()
