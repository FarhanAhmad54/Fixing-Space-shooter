#!/usr/bin/env bash
# package_love.sh — produce a .love archive from the source tree.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/Starfall-Vengeance.love}"
cd "$ROOT"

rm -f "$OUT"

zip -qr "$OUT" . \
  -x '.git/*' \
  -x 'Starfall-Vengeance.love' \
  -x '*.love' \
  -x 'web/dist/*' \
  -x 'node_modules/*' \
  -x '*.DS_Store' \
  -x '__MACOSX/*'

SIZE_KB=$(du -k "$OUT" | cut -f1)
echo "Created $OUT (${SIZE_KB} KB)"

if [ "$SIZE_KB" -gt 51200 ]; then
  echo "WARNING: archive exceeds 50 MB — it will fail the CrazyGames limit."
fi
