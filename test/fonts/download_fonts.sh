#!/usr/bin/env bash
# Downloads the font files required by test/home_screen_golden_test.dart.
# The files are the exact bytes google_fonts 6.3.3 pins for Readex Pro
# (sha256 + length verified below) plus MaterialIcons from the Flutter SDK.
# Run from the repo root:  bash test/fonts/download_fonts.sh
set -euo pipefail
cd "$(dirname "$0")"

# weight sha256 expected_length
ENTRIES="w200 870a3330a3749a6f77ae6869705a73e7cac177a535bebe60323fc706f632267c 93952
w300 38b0632b8ef49efc7781f129be6231d9e8f2191fe9522a7af3c63f514a1db7c8 94064
w400 7782ff7d5dea5d731043a6a9485f9c129227a140122a8d5b066a4139b6db2dcb 93604
w500 dd123b1e15265f38bb1e7ea3130a5b50529e1dd2701fd815a7a2c5ebd773cbf7 94112
w600 d6416f2670653f40b5d522b959fa9cef26de93f1eb07383cd74add81cd540223 94252
w700 ea6ca5c476dff3996be03d6f357b8fc79d536b3324a74a2b8cd8d95b0c2d7cec 94224"

mkdir -p gstatic
echo "$ENTRIES" | while read -r weight hash len; do
  out="gstatic/${weight}.ttf"
  curl -fsSL -o "$out" "https://fonts.gstatic.com/s/a/${hash}.ttf"
  actual_hash=$(sha256sum "$out" | cut -d' ' -f1)
  actual_len=$(stat -c%s "$out")
  if [ "$actual_hash" != "$hash" ] || [ "$actual_len" != "$len" ]; then
    echo "CHECKSUM MISMATCH for $out" >&2
    exit 1
  fi
  echo "ok $weight ($len bytes, sha256 verified)"
done

# Amiri / Amiri Quran, pinned by google_fonts 6.3.3 (used by the rafiq
# screens). Same sha256 + length verification, written to the fonts root.
AMIRI_ENTRIES="Amiri-Regular.ttf 82b49c37cfb90dd8fff8aab7508c2078bb32a200648acb2237dc02c30f4492ad 403728
Amiri-Bold.ttf 53c460187d4f6d8fa2bde7a1a6587ca6487f807c31b094037164bb58e3b2bd4c 379988
AmiriQuran-Regular.ttf 6fb463ac2d53b77b67d274bec99e39a4288a2d0a962437c7b1c1f6e9a9ee799f 318964"

echo "$AMIRI_ENTRIES" | while read -r out hash len; do
  curl -fsSL -o "$out" "https://fonts.gstatic.com/s/a/${hash}.ttf"
  actual_hash=$(sha256sum "$out" | cut -d' ' -f1)
  actual_len=$(stat -c%s "$out")
  if [ "$actual_hash" != "$hash" ] || [ "$actual_len" != "$len" ]; then
    echo "CHECKSUM MISMATCH for $out" >&2
    exit 1
  fi
  echo "ok $out ($len bytes, sha256 verified)"
done

# The golden harness also uses these legacy copies for the synchronous
# 'ReadexPro' family registration (same typeface, gstatic v27 static cuts).
curl -fsSL -o ReadexPro-400.ttf 'https://fonts.gstatic.com/s/readexpro/v27/SLXnc1bJ7HE5YDoGPuzj_dh8uc7wUy8ZQQyX2KY8TL0kGZN6blTC4USmgg.ttf'
curl -fsSL -o ReadexPro-600.ttf 'https://fonts.gstatic.com/s/readexpro/v27/SLXnc1bJ7HE5YDoGPuzj_dh8uc7wUy8ZQQyX2KY8TL0kGZN6blTCP0Omgg.ttf'
curl -fsSL -o ReadexPro-700.ttf 'https://fonts.gstatic.com/s/readexpro/v27/SLXnc1bJ7HE5YDoGPuzj_dh8uc7wUy8ZQQyX2KY8TL0kGZN6blTCBkOmgg.ttf'

# MaterialIcons ships with the Flutter SDK; locate it.
for candidate in \
  "${FLUTTER_ROOT:-/nonexistent}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf" \
  "$(dirname "$(command -v flutter)")/cache/artifacts/material_fonts/MaterialIcons-Regular.otf"; do
  if [ -f "$candidate" ]; then
    cp "$candidate" MaterialIcons-Regular.otf
    echo "ok MaterialIcons-Regular.otf (from Flutter SDK)"
    exit 0
  fi
done
echo "Could not locate MaterialIcons-Regular.otf; set FLUTTER_ROOT." >&2
exit 1
