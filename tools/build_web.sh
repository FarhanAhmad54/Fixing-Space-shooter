#!/usr/bin/env bash
# build_web.sh — build a love.js web bundle and enforce the CrazyGames
# 50 MB initial-load ceiling.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-$ROOT/web/dist}"
LIMIT_MB=50

echo "== Starfall Vengeance — web build =="
echo "Root:    $ROOT"
echo "Output:  $OUT_DIR"

mkdir -p "$OUT_DIR"

# 1. Package the .love archive.
LOVE_FILE="$OUT_DIR/Starfall-Vengeance.love"
"$ROOT/tools/package_love.sh" "$LOVE_FILE"

# 2. Run love.js. Install with:  npm install -g love.js
if ! command -v love.js >/dev/null 2>&1; then
  echo "ERROR: love.js not found on PATH."
  echo "Install it with:  npm install -g love.js"
  exit 1
fi

love.js "$LOVE_FILE" "$OUT_DIR" --title "Starfall Vengeance"

# 3. Copy the host shell files.
cp "$ROOT/web/index.html" "$OUT_DIR/index.html"
cp "$ROOT/web/platform-bridge.js" "$OUT_DIR/platform-bridge.js"

# 4. Measure the initial payload (gzipped).
echo
echo "-- Measuring initial payload --"
TOTAL_BYTES=0
while IFS= read -r -d '' f; do
  SIZE=$(gzip -c "$f" | wc -c)
  TOTAL_BYTES=$((TOTAL_BYTES + SIZE))
done < <(find "$OUT_DIR" -type f -print0)

TOTAL_MB=$((TOTAL_BYTES / 1024 / 1024))
TOTAL_KB=$((TOTAL_BYTES / 1024))
echo "Gzipped initial payload: ${TOTAL_KB} KB (${TOTAL_MB} MB)"
echo "CrazyGames limit:        ${LIMIT_MB} MB"

if [ "$TOTAL_MB" -gt "$LIMIT_MB" ]; then
  echo "FAIL: build exceeds the ${LIMIT_MB} MB CrazyGames initial-load limit."
  echo "Reduce asset sizes (PNG optimisation, OGG audio) and re-run."
  exit 1
fi

echo
echo "PASS: web build ready at $OUT_DIR"
echo "Test with:  python3 -m http.server 8080 --directory $OUT_DIR"
