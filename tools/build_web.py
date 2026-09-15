#!/usr/bin/env python3
"""build_web.py — Cross-platform Web Build Generator for Starfall Vengeance.

1. Runs QA validation (tools/qa.py).
2. Packages the LÖVE archive into game.love with main.lua at root.
3. Prepares game.love and game.js WebAssembly loader in web/dist/.
4. Copies love.wasm, love.js, index.html, and platform-bridge.js into web/dist/.
5. Validates payload against 50 MB budget and runs archive integrity gate.
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
DIST_DIR = ROOT / "web" / "dist"
CACHE_DIR = ROOT / "tools" / ".lovejs_cache"
LOVE_FILE = ROOT / "game.love"
DIST_LOVE = DIST_DIR / "game.love"
LIMIT_MB = 50

REQUIRED_FILES = [
    "index.html",
    "game.love",
    "game.js",
    "love.js",
    "love.wasm",
    "platform-bridge.js",
]

def run_qa():
    print("== [1/5] Running Structural QA Gate ==")
    qa_script = ROOT / "tools" / "qa.py"
    if qa_script.exists():
        res = subprocess.run([sys.executable, str(qa_script)], capture_output=True, text=True)
        print(res.stdout)
        if res.returncode != 0:
            print(res.stderr)
            print("FAIL: QA gate failed. Aborting web build.")
            sys.exit(1)
    else:
        print("  (QA script not found, skipping)")

def package_love():
    print("== [2/5] Packaging game.love Archive ==")
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    if LOVE_FILE.exists():
        LOVE_FILE.unlink()

    with zipfile.ZipFile(LOVE_FILE, "w", compression=zipfile.ZIP_DEFLATED) as z:
        # All root Lua files
        lua_files = sorted(ROOT.glob("*.lua"))
        if not any(f.name == "main.lua" for f in lua_files):
            print("FAIL: main.lua does not exist in root directory!")
            sys.exit(1)

        for f in lua_files:
            z.write(f, arcname=f.name)
            print(f"  + {f.name}")

        # Assets
        assets_dir = ROOT / "assets"
        if assets_dir.exists():
            for f in sorted(assets_dir.rglob("*")):
                if f.is_file():
                    arcname = f.relative_to(ROOT).as_posix()
                    z.write(f, arcname=arcname)

        # Sounds
        sounds_dir = ROOT / "sounds"
        if sounds_dir.exists():
            for f in sorted(sounds_dir.rglob("*")):
                if f.is_file():
                    arcname = f.relative_to(ROOT).as_posix()
                    z.write(f, arcname=arcname)

        # src/ if present
        src_dir = ROOT / "src"
        if src_dir.exists():
            for f in sorted(src_dir.rglob("*")):
                if f.is_file():
                    arcname = f.relative_to(ROOT).as_posix()
                    z.write(f, arcname=arcname)

    print(f"  -> Generated {LOVE_FILE} ({LOVE_FILE.stat().st_size / 1024:.1f} KB)")
    validate_love_archive(LOVE_FILE)

def validate_love_archive(love_path):
    print(f"  Validating internal structure of {love_path.name}...")
    if not love_path.is_file():
        raise FileNotFoundError(f"FAIL: {love_path} does not exist!")

    with zipfile.ZipFile(love_path, "r") as z:
        names = z.namelist()
        if "main.lua" not in names:
            raise ValueError(f"FAIL: main.lua missing from root of {love_path.name}!")

        for n in names:
            if n.endswith("main.lua") and n != "main.lua":
                raise ValueError(f"FAIL: Nested main.lua in {n}! main.lua must be at archive root.")

        if "conf.lua" not in names:
            raise ValueError(f"FAIL: conf.lua missing from root of {love_path.name}!")

    print(f"  PASS: {love_path.name} verified (main.lua strictly at root).")

def assemble_web():
    print("== [3/5] Assembling WebAssembly Runtime & Host Files ==")
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

    # Safely clear files in dist without deleting directory
    DIST_DIR.mkdir(parents=True, exist_ok=True)
    for item in DIST_DIR.iterdir():
        try:
            if item.is_file() or item.is_symlink():
                item.unlink()
            elif item.is_dir():
                shutil.rmtree(item, ignore_errors=True)
        except Exception as e:
            print(f"  (Notice while clearing {item.name}: {e})")

    # Copy WebAssembly engine
    shutil.copy2(love_wasm, DIST_DIR / "love.wasm")
    shutil.copy2(love_js, DIST_DIR / "love.js")
    dist_love_js = DIST_DIR / "love.js"
    love_js_code = dist_love_js.read_text(encoding="utf-8")
    target_idbfs = 'Module.addRunDependency("IDBFS_sync");FS.mkdir("/home/web_user/love");FS.mount(IDBFS,{},"/home/web_user/love");FS.syncfs(true,function(err){if(err){Module["printErr"](err)}else{Module.removeRunDependency("IDBFS_sync")}});window.addEventListener("beforeunload",function(event){FS.syncfs(false,function(err){if(err){Module["printErr"](err)}})})'
    replacement_idbfs = 'Module.addRunDependency("IDBFS_sync");try{FS.mkdir("/home/web_user/love");FS.mount(IDBFS,{},"/home/web_user/love");FS.syncfs(true,function(err){if(err){Module["printErr"]("IDBFS syncfs warning: "+err)}Module.removeRunDependency("IDBFS_sync")});window.addEventListener("beforeunload",function(event){try{FS.syncfs(false,function(err){if(err){Module["printErr"](err)}})}catch(e){}})}catch(e){Module["printErr"]("IDBFS mount error: "+e);Module.removeRunDependency("IDBFS_sync")}'
    if target_idbfs in love_js_code:
        dist_love_js.write_text(love_js_code.replace(target_idbfs, replacement_idbfs), encoding="utf-8")
        print("  + Applied IDBFS error-resilience guard to love.js")
    print("  + Copied love.wasm and love.js into web/dist")

    # Deploy game.love directly at runtime path
    shutil.copy2(LOVE_FILE, DIST_LOVE)
    data_size = DIST_LOVE.stat().st_size
    print(f"  + Deployed game.love into web/dist ({data_size / 1024:.1f} KB)")

    # Generate game.js loader targeting game.love
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
    game_js_content = game_js_content.replace("'game.data'", "'game.love'")

    with open(DIST_DIR / "game.js", "w", encoding="utf-8") as f:
        f.write(game_js_content)
    print("  + Generated official game.js data loader (target: game.love)")

    # Copy host shell and SDK bridge
    shutil.copy2(ROOT / "web" / "index.html", DIST_DIR / "index.html")
    shutil.copy2(ROOT / "web" / "platform-bridge.js", DIST_DIR / "platform-bridge.js")
    print("  + Injected production index.html & platform-bridge.js")

def validate_dist():
    print("== [4/5] Validating Web Distribution Integrity ==")
    for fname in REQUIRED_FILES:
        fp = DIST_DIR / fname
        if not fp.is_file():
            raise FileNotFoundError(f"FAIL: Missing required file in web/dist: {fname}")
        if fp.stat().st_size == 0:
            raise ValueError(f"FAIL: File {fname} in web/dist is 0 bytes!")

    validate_love_archive(DIST_LOVE)

    if (DIST_DIR / "game.zip").exists():
        raise ValueError("FAIL: Obsolete game.zip found in web/dist! Must only contain game.love.")

    print("  PASS: web/dist structure verified.")

def check_payload():
    print("== [5/5] Measuring Web Payload Budget ==")
    total_bytes = 0
    for root, _, files in os.walk(DIST_DIR):
        for f in files:
            fp = Path(root) / f
            with open(fp, "rb") as inf:
                compressed = gzip.compress(inf.read())
                total_bytes += len(compressed)

    total_mb = total_bytes / (1024 * 1024)
    total_kb = total_bytes / 1024
    print(f"  Gzipped payload: {total_kb:.1f} KB ({total_mb:.2f} MB)")
    print(f"  Platform limit:  {LIMIT_MB} MB")

    if total_mb > LIMIT_MB:
        print(f"FAIL: Exceeds {LIMIT_MB} MB limit!")
        sys.exit(1)
    print("  PASS: Payload is well within budget.")

def main():
    print("======================================================")
    print("   STARFALL VENGEANCE — WEB PRODUCTION BUILD         ")
    print("======================================================")
    run_qa()
    package_love()
    assemble_web()
    validate_dist()
    check_payload()
    print(f"\nSUCCESS: Web build complete in {DIST_DIR}")

if __name__ == "__main__":
    main()
