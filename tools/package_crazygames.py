#!/usr/bin/env python3
"""1-Click Production Builder & Packager for CrazyGames Platform.

1. Runs tools/qa.py gate check.
2. Compiles game.love archive with main.lua at root.
3. Builds WebAssembly love.js distribution into web/dist/.
4. Injects production index.html (with CrazyGames SDK header) & platform-bridge.js.
5. Verifies payload size and structural integrity against 50 MB budget.
6. Generates upload-ready crazygames-starfall-vengeance.zip.
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
LOCAL_LOVE = ROOT / "game.love"
DIST_LOVE = DIST_DIR / "game.love"
ZIP_OUTPUT = ROOT / "crazygames-starfall-vengeance.zip"
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
        for f in sorted(ROOT.glob("*.lua")):
            z.write(f, arcname=f.name)
            print(f"  + {f.name}")
        for f in sorted((ROOT / "assets").glob("*")):
            if f.is_file():
                z.write(f, arcname=f"assets/{f.name}")
        for f in sorted((ROOT / "sounds").glob("*")):
            if f.is_file():
                z.write(f, arcname=f"sounds/{f.name}")
        src_dir = ROOT / "src"
        if src_dir.exists():
            for f in sorted(src_dir.glob("*")):
                if f.is_file():
                    z.write(f, arcname=f"src/{f.name}")

    print(f"  -> Generated {LOCAL_LOVE} ({LOCAL_LOVE.stat().st_size / 1024:.1f} KB)")
    validate_love_archive(LOCAL_LOVE)

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
                raise ValueError(f"FAIL: Nested main.lua in {n}!")
        if "conf.lua" not in names:
            raise ValueError(f"FAIL: conf.lua missing from root of {love_path.name}!")

    print(f"  PASS: {love_path.name} verified (main.lua strictly at root).")

def build_web():
    print("== [3/6] Assembling WebAssembly love.js Runtime ==")
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

    # Copy runtime to dist
    shutil.copy2(love_wasm, DIST_DIR / "love.wasm")
    shutil.copy2(love_js, DIST_DIR / "love.js")
    print("  + Copied love.wasm and love.js into web/dist")

    # Deploy game.love directly
    shutil.copy2(LOCAL_LOVE, DIST_LOVE)
    data_size = DIST_LOVE.stat().st_size
    print(f"  + Deployed game.love ({data_size / 1024:.1f} KB)")

    # Generate game.js loader targeting game.love
    package_uuid = str(uuid.uuid4())
    metadata_json = json.dumps({
        "package_uuid": package_uuid,
        "remote_package_size": data_size,
        "files": [
            {
                "filename": "/game.love",
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

    # Copy host shell files
    shutil.copy2(ROOT / "web" / "index.html", DIST_DIR / "index.html")
    shutil.copy2(ROOT / "web" / "platform-bridge.js", DIST_DIR / "platform-bridge.js")
    print("  + Injected production index.html & platform-bridge.js")

def validate_dist():
    print("== [4/6] Validating Distribution Files ==")
    for fname in REQUIRED_FILES:
        fp = DIST_DIR / fname
        if not fp.is_file():
            raise FileNotFoundError(f"FAIL: Missing required file in web/dist: {fname}")
        if fp.stat().st_size == 0:
            raise ValueError(f"FAIL: File {fname} in web/dist is 0 bytes!")

    validate_love_archive(DIST_LOVE)

    if (DIST_DIR / "game.zip").exists():
        raise ValueError("FAIL: Stale game.zip found in web/dist! Must only contain game.love.")

    print("  PASS: web/dist structure verified.")

def check_payload():
    print("== [5/6] Measuring CrazyGames Initial Payload ==")
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
    print(f"  CrazyGames limit: {LIMIT_MB} MB")

    if total_mb > LIMIT_MB:
        print(f"FAIL: Exceeds CrazyGames {LIMIT_MB} MB limit!")
        sys.exit(1)
    print("  PASS: Payload is well within CrazyGames budget.")

def create_crazygames_zip():
    print("== [6/6] Assembling crazygames-starfall-vengeance.zip ==")
    if ZIP_OUTPUT.exists():
        ZIP_OUTPUT.unlink()

    with zipfile.ZipFile(ZIP_OUTPUT, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for root, _, files in sorted(os.walk(DIST_DIR)):
            for f in sorted(files):
                fp = Path(root) / f
                arcname = fp.relative_to(DIST_DIR).as_posix()
                z.write(fp, arcname=arcname)
                print(f"  + {arcname}")

    with zipfile.ZipFile(ZIP_OUTPUT, "r") as z:
        names = z.namelist()
        for req in REQUIRED_FILES:
            if req not in names:
                raise ValueError(f"FAIL: {ZIP_OUTPUT.name} missing top-level entry: {req}")
        for n in names:
            if "/" in n:
                raise ValueError(f"FAIL: {ZIP_OUTPUT.name} contains nested path: {n}!")

    print(f"\nSUCCESS: Package ready at {ZIP_OUTPUT}")
    print(f"Archive Size: {ZIP_OUTPUT.stat().st_size / (1024 * 1024):.2f} MB")
    print("Ready for upload to CrazyGames Developer Portal!")

def main():
    print("======================================================")
    print("   STARFALL VENGEANCE — CRAZYGAMES PRODUCTION BUILD   ")
    print("======================================================")
    run_qa()
    package_love()
    build_web()
    validate_dist()
    check_payload()
    create_crazygames_zip()

if __name__ == "__main__":
    main()
