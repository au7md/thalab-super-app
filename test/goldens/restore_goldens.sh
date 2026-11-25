#!/usr/bin/env bash
# Restores the REVIEWED golden baseline PNGs from their base64 text copies
# in test/goldens_b64/. The .b64 files are the repository's source of truth
# for baselines (binary files cannot be committed through the current
# tooling); this script materializes them for `flutter test` comparison.
#
# Clean-checkout golden workflow:
#   bash test/fonts/download_fonts.sh      # pinned, checksum-verified fonts
#   bash test/goldens/restore_goldens.sh   # reviewed baseline PNGs
#   flutter test                           # compare against baselines
#
# Regenerating a baseline after an INTENTIONAL visual change:
#   flutter test --update-goldens          # capture (NOT regression proof)
#   visually inspect test/goldens/*.png
#   for f in test/goldens/*.png; do base64 -w0 "$f" > "test/goldens_b64/$(basename "$f").b64"; echo >> "test/goldens_b64/$(basename "$f").b64"; done
#   commit the changed .b64 files
set -euo pipefail
cd "$(dirname "$0")"

fail=0
for b64 in ../goldens_b64/*.png.b64; do
  out="$(basename "$b64" .b64)"
  base64 -d "$b64" > "$out"
  # PNG magic check so a corrupted text file fails loudly instead of
  # producing a confusing golden mismatch.
  if ! head -c8 "$out" | grep -q $'\x89PNG\r\n\x1a\n'; then
    echo "CORRUPT baseline decoded: $b64" >&2
    fail=1
  else
    echo "restored $out ($(stat -c%s "$out") bytes)"
  fi
done
[ "$fail" -eq 0 ]
